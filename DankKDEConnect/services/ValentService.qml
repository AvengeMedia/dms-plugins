pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services

Singleton {
    id: root

    readonly property string service: "ca.andyholmes.Valent"
    readonly property string managerPath: "/ca/andyholmes/Valent"
    readonly property string deviceInterface: "ca.andyholmes.Valent.Device"
    readonly property string actionsInterface: "org.gtk.Actions"
    readonly property string objectManagerInterface: "org.freedesktop.DBus.ObjectManager"
    readonly property string propertiesInterface: "org.freedesktop.DBus.Properties"

    readonly property int stateConnected: 1
    readonly property int statePaired: 2
    readonly property int statePairIncoming: 4
    readonly property int statePairOutgoing: 8

    property bool available: false
    property bool initialized: false
    readonly property bool supportsSms: true
    property var deviceIds: []
    property var devices: ({})
    property bool isRefreshing: false
    property string announcedName: ""
    property string selfId: ""

    property bool _subscribed: false
    property bool _dbusFinished: false

    Timer {
        id: refreshMinTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root._dbusFinished) {
                root.isRefreshing = false;
            }
        }
    }

    signal devicesListChanged
    signal deviceUpdated(string deviceId)
    signal deviceAdded(string deviceId)
    signal deviceRemoved(string deviceId)
    signal pairingRequestReceived(string deviceId, string verificationKey)
    signal shareReceived(string deviceId, string url)

    readonly property var connectedDevices: {
        let result = [];
        for (const id of deviceIds) {
            const dev = devices[id];
            if (dev?.isReachable)
                result.push(dev);
        }
        return result;
    }

    readonly property var pairedDevices: {
        let result = [];
        for (const id of deviceIds) {
            const dev = devices[id];
            if (dev?.isPaired)
                result.push(dev);
        }
        return result;
    }

    readonly property int connectedCount: connectedDevices.length
    readonly property int pairedCount: pairedDevices.length

    Component.onCompleted: {
        if (DMSService.isConnected) {
            checkAvailability();
            subscribeToSignals();
        }
    }

    Connections {
        target: DMSService
        function onConnectionStateChanged() {
            if (!DMSService.isConnected) {
                available = false;
                initialized = false;
                _subscribed = false;
                return;
            }
            checkAvailability();
            subscribeToSignals();
        }

        function onDbusSignalReceived(subId, data) {
            handleDbusSignal(data);
        }
    }

    function subscribeToSignals() {
        if (_subscribed)
            return;
        _subscribed = true;
        DMSService.dbusSubscribe("session", service, "", "", "", function(response) {
            if (response.error) {
                console.warn("[Valent] Subscription failed:", response.error);
                _subscribed = false;
            }
        });
        DMSService.dbusSubscribe("session", service, "", propertiesInterface, "PropertiesChanged", function(response) {
            if (response.error)
                console.warn("[Valent] Properties subscription failed:", response.error);
        });
    }

    function checkAvailability() {
        DMSService.dbusListNames("session", function(response) {
            if (response.error) {
                available = false;
                return;
            }
            const names = response.result?.names || [];
            const wasAvailable = available;
            available = names.includes(service);
            if (available && !initialized) {
                activateService();
                initialize();
            }
            if (!available && wasAvailable) {
                initialized = false;
                deviceIds = [];
                devices = {};
                devicesListChanged();
            }
        });
    }

    function activateService() {
        DMSService.dbusCall("session", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "StartServiceByName", [service, 0], function(response) {
            if (response.error) {
                console.warn("[Valent] Failed to start service:", response.error);
                return;
            }
        });
    }

    function openValentWindow() {
        DMSService.dbusCall("session", service, managerPath, "org.gtk.Actions", "Activate", ["window", ["main"],
            {}
        ], function(response) {
            if (response.error)
                console.warn("[Valent] Failed to open window:", response.error);
        });
    }

    function initialize() {
        initialized = true;
        refreshDevices();
    }

    function handleDbusSignal(data) {
        if (data.sender !== service && !data.path?.startsWith("/ca/andyholmes/Valent"))
            return;

        switch (data.member) {
        case "InterfacesAdded":
            {
                const path = data.body?.[0];
                const id = extractDeviceIdFromPath(path);
                if (id && !deviceIds.includes(id)) {
                    deviceIds = deviceIds.concat([id]);
                    fetchDeviceInfo(id);
                    deviceAdded(id);
                }
            }
            break;
        case "InterfacesRemoved":
            {
                const path = data.body?.[0];
                const id = extractDeviceIdFromPath(path);
                if (id) {
                    deviceIds = deviceIds.filter(function(d) { return d !== id; });
                    delete devices[id];
                    devices = Object.assign({}, devices);
                    deviceRemoved(id);
                    devicesListChanged();
                }
            }
            break;
        case "PropertiesChanged":
            {
                const iface = data.body?.[0];
                if (iface === deviceInterface) {
                    const id = extractDeviceIdFromPath(data.path);
                    if (id)
                        fetchDeviceInfo(id);
                }
            }
            break;
        case "Changed":
            {
                if (data.interface !== actionsInterface)
                    break;
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                const stateChanges = data.body?.[2];
                if (stateChanges && typeof stateChanges === "object") {
                    if ("battery.state" in stateChanges)
                        fetchBatteryState(id);
                    if ("connectivity_report.state" in stateChanges)
                        fetchConnectivityState(id);
                }
            }
            break;
        default:
            break;
        }
    }

    function extractDeviceIdFromPath(path) {
        if (!path?.includes("/Device/"))
            return null;
        const escaped = path.split("/Device/")[1]?.split("/")[0];
        return escaped ? unescapeObjectPath(escaped) : null;
    }

    function escapeObjectPath(id) {
        let result = "";
        for (let i = 0; i < id.length; i++) {
            const c = id.charCodeAt(i);
            if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39)) {
                result += id[i];
            } else {
                result += "_" + c.toString(16).padStart(2, "0");
            }
        }
        return result;
    }

    function unescapeObjectPath(escaped) {
        let result = "";
        for (let i = 0; i < escaped.length; i++) {
            if (escaped[i] === "_" && i + 2 < escaped.length) {
                const hex = escaped.substring(i + 1, i + 3);
                result += String.fromCharCode(parseInt(hex, 16));
                i += 2;
            } else {
                result += escaped[i];
            }
        }
        return result;
    }

    function getDevicePath(deviceId) {
        return managerPath + "/Device/" + escapeObjectPath(deviceId);
    }

    function refreshDevices() {
        if (!available || isRefreshing)
            return;
        isRefreshing = true;
        _dbusFinished = false;
        refreshMinTimer.start();

        DMSService.dbusCall("session", service, managerPath, objectManagerInterface, "GetManagedObjects", [], function(response) {
            root._dbusFinished = true;
            if (!refreshMinTimer.running) {
                root.isRefreshing = false;
            }
            if (response.error) {
                console.warn("[Valent] GetManagedObjects failed:", response.error);
                return;
            }

            const managedObjects = response.result?.values?.[0] || {};
            const newIds = [];

            for (const [path, interfaces] of Object.entries(managedObjects)) {
                if (!interfaces[deviceInterface])
                    continue;
                const id = extractDeviceIdFromPath(path);
                if (id) {
                    newIds.push(id);
                    parseDeviceProperties(id, interfaces[deviceInterface]);
                }
            }

            const oldIds = deviceIds.slice();
            deviceIds = newIds;

            for (const oldId of oldIds) {
                if (!newIds.includes(oldId))
                    delete devices[oldId];
            }

            devices = Object.assign({}, devices);
            devicesListChanged();
        });
    }

    function fetchDeviceInfo(deviceId) {
        const devicePath = getDevicePath(deviceId);

        DMSService.dbusGetAllProperties("session", service, devicePath, deviceInterface, function(response) {
            if (response.error)
                return;
            parseDeviceProperties(deviceId, response.result || {});
        });
    }

    function extractVariant(val) {
        if (val === null || val === undefined)
            return null;
        if (typeof val !== "object")
            return val;
        if (Array.isArray(val) && val.length === 1)
            return extractVariant(val[0]);
        if (val.value !== undefined)
            return extractVariant(val.value);
        if (val.data !== undefined)
            return extractVariant(val.data);
        return val;
    }

    function parseDeviceProperties(deviceId, props) {
        const oldDev = devices[deviceId] || {};
        const state = extractVariant(props.State) || 0;
        const iconName = extractVariant(props.IconName) || "";
        const name = extractVariant(props.Name) || "";

        const dev = Object.assign({}, oldDev);
        dev.id = deviceId;
        dev.name = name || deviceId;
        dev.type = iconNameToType(iconName);
        dev.isReachable = (state & stateConnected) !== 0;
        dev.isPaired = (state & statePaired) !== 0;
        dev.isPairRequested = (state & statePairOutgoing) !== 0;
        dev.isPairRequestedByPeer = (state & statePairIncoming) !== 0;
        dev.statusIconName = iconName || "smartphone-symbolic";
        dev.supportedPlugins = [];
        dev.verificationKey = "";
        dev._state = state;

        devices = Object.assign({}, devices, {
            [deviceId]: dev
        });
        deviceUpdated(deviceId);

        if (dev.isPairRequestedByPeer)
            pairingRequestReceived(deviceId, "");

        if (dev.isPaired && dev.isReachable) {
            fetchBatteryState(deviceId);
            fetchConnectivityState(deviceId);
        }
    }

    function iconNameToType(iconName) {
        if (typeof iconName !== "string")
            return "phone";
        if (iconName.includes("phone"))
            return "phone";
        if (iconName.includes("tablet"))
            return "tablet";
        if (iconName.includes("laptop"))
            return "laptop";
        if (iconName.includes("computer") || iconName.includes("desktop"))
            return "desktop";
        if (iconName.includes("tv"))
            return "tv";
        return "phone";
    }

    function fetchBatteryState(deviceId) {
        const devicePath = getDevicePath(deviceId);

        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Describe", ["battery.state"], function(response) {
            if (response.error)
                return;

            const result = response.result?.values;
            if (!result || !result[0])
                return;

            const inner = result[0];
            const stateArray = inner[2];
            if (!stateArray || !stateArray[0])
                return;

            const stateValue = stateArray[0];
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;

            const dev = Object.assign({}, oldDev);
            dev.batteryCharge = stateValue["percentage"] ?? -1;
            dev.batteryCharging = stateValue["charging"] ?? false;

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function fetchConnectivityState(deviceId) {
        const devicePath = getDevicePath(deviceId);

        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Describe", ["connectivity_report.state"], function(response) {
            if (response.error)
                return;

            const result = response.result?.values;
            if (!result || !result[0])
                return;

            const inner = result[0];
            const stateArray = inner[2];
            if (!stateArray || !stateArray[0])
                return;

            const stateValue = stateArray[0];
            if (!stateValue)
                return;

            const oldDev = devices[deviceId];
            if (!oldDev)
                return;

            const dev = Object.assign({}, oldDev);
            dev.networkStrength = -1;
            dev.networkType = "";

            try {
                const signalStrengths = stateValue["signal-strengths"];
                if (signalStrengths && typeof signalStrengths === "object") {
                    const keys = Object.keys(signalStrengths);
                    if (keys.length > 0) {
                        const primarySim = signalStrengths[keys[0]];
                        if (primarySim) {
                            dev.networkStrength = primarySim["signal-strength"] ?? -1;
                            dev.networkType = primarySim["network-type"] ?? "";
                        }
                    }
                }
            } catch (e) {}

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function activateAction(deviceId, actionName, parameter, callback) {
        const devicePath = getDevicePath(deviceId);
        const params = parameter !== undefined ? [parameter] : [];

        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Activate", [actionName, params,
            {}
        ], function(response) {
            if (callback)
                callback(response);
        });
    }

    function getDevice(deviceId) {
        return devices[deviceId] || null;
    }

    function ringDevice(deviceId, callback) {
        activateAction(deviceId, "findmyphone.ring", undefined, callback);
    }

    function shareUrl(deviceId, url, callback) {
        activateAction(deviceId, "share.uri", url, callback);
    }

    function shareText(deviceId, text, callback) {
        activateAction(deviceId, "share.text", text, callback);
    }

    function sendClipboard(deviceId, callback) {
        activateAction(deviceId, "clipboard.push", undefined, callback);
    }

    function requestPairing(deviceId, callback) {
        const devicePath = getDevicePath(deviceId);
        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Activate", ["pair", [],
            {}
        ], function(response) {
            if (callback)
                callback(response);
        });
    }

    function acceptPairing(deviceId, callback) {
        const devicePath = getDevicePath(deviceId);
        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Activate", ["pair", [],
            {}
        ], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function cancelPairing(deviceId, callback) {
        const devicePath = getDevicePath(deviceId);
        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Activate", ["unpair", [],
            {}
        ], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function unpair(deviceId, callback) {
        const devicePath = getDevicePath(deviceId);
        DMSService.dbusCall("session", service, devicePath, actionsInterface, "Activate", ["unpair", [],
            {}
        ], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function setLocked(deviceId, locked, callback) {
        const devicePath = getDevicePath(deviceId);
        DMSService.dbusCall("session", service, devicePath, actionsInterface, "SetState", ["lock.state", locked], function(response) {
            if (callback)
                callback(response);
        });
    }

    function getRemoteCommands(deviceId, callback) {
        if (callback)
            callback([]);
    }

    function triggerRemoteCommand(deviceId, commandKey, callback) {
        activateAction(deviceId, "runcommand.execute", commandKey, callback);
    }

    function getMprisPlayers(deviceId, callback) {
        if (callback)
            callback([]);
    }

    function mprisAction(deviceId, action, callback) {
        if (callback)
            callback({
                error: "Not supported"
            });
    }

    function sendPing(deviceId, message, callback) {
        if (message)
            activateAction(deviceId, "ping.message", message, callback);
        else
            activateAction(deviceId, "ping.ping", undefined, callback);
    }

    function mountSftp(deviceId, callback) {
        activateAction(deviceId, "sftp.browse", undefined, callback);
    }

    function unmountSftp(deviceId, callback) {
        activateAction(deviceId, "sftp.unmount", undefined, callback);
    }

    function mountAndWait(deviceId, callback) {
        activateAction(deviceId, "sftp.browse", undefined, function(response) {
            if (callback)
                callback(!response.error);
        });
    }

    function startBrowsing(deviceId, callback) {
        Proc.runCommand(null, ["sh", "-c", "ls -d /run/user/$(id -u)/gvfs/sftp:* 2>/dev/null | head -1"], function(stdout, exitCode) {
            const mountPath = stdout.trim();
            if (mountPath) {
                const storagePath = mountPath + "/storage/emulated/0";
                Qt.openUrlExternally("file://" + storagePath);
                if (callback)
                    callback({});
                return;
            }
            activateAction(deviceId, "sftp.browse", undefined, function(response) {
                if (response.error) {
                    if (callback)
                        callback(response);
                    return;
                }
                _waitForSftpMount(deviceId, callback, 0);
            });
        }, 0);
    }

    function _waitForSftpMount(deviceId, callback, attempt) {
        if (attempt >= 10) {
            if (callback)
                callback({
                    error: "Mount timeout"
                });
            return;
        }

        Proc.runCommand(null, ["sh", "-c", "ls -d /run/user/$(id -u)/gvfs/sftp:* 2>/dev/null | head -1"], function(stdout, exitCode) {
            const mountPath = stdout.trim();
            if (mountPath) {
                const storagePath = mountPath + "/storage/emulated/0";
                Qt.openUrlExternally("file://" + storagePath);
                if (callback)
                    callback({});
                return;
            }
            Qt.callLater(function() { _waitForSftpMount(deviceId, callback, attempt + 1); });
        }, attempt === 0 ? 0 : 300);
    }

    function browseDevice(deviceId, callback) {
        startBrowsing(deviceId, callback);
    }

    function getSftpMountPoint(deviceId, callback) {
        Proc.runCommand(null, ["sh", "-c", "ls -d /run/user/$(id -u)/gvfs/sftp:* 2>/dev/null | head -1"], function(stdout, exitCode) {
            if (callback)
                callback(stdout.trim() || "");
        }, 0);
    }

    function isSftpMounted(deviceId, callback) {
        Proc.runCommand(null, ["sh", "-c", "ls -d /run/user/$(id -u)/gvfs/sftp:* 2>/dev/null | head -1"], function(stdout, exitCode) {
            if (callback)
                callback(!!stdout.trim());
        }, 0);
    }

    function requestPhoto(deviceId, savePath, callback) {
        if (callback)
            callback({
                error: "Not supported"
            });
    }

    function sendSms(deviceId, addresses, message, attachmentUrls, callback) {
        if (callback)
            callback({
                error: "Not supported"
            });
    }

    function launchSmsApp(deviceId, callback) {
        Proc.runCommand(null, ["gapplication", "action", "ca.andyholmes.Valent", "messages-window"], function(stdout, exitCode) {
            if (callback)
                callback(exitCode === 0 ? {} : {
                    error: "Failed to launch"
                });
        }, 0);
    }

    function getConversations(deviceId, callback) {
        if (callback)
            callback([]);
    }

    function getDeviceIcon(device) {
        if (!device)
            return "smartphone";
        switch (device.type) {
        case "phone":
        case "smartphone":
            return "smartphone";
        case "tablet":
            return "tablet";
        case "desktop":
            return "desktop_windows";
        case "laptop":
            return "laptop";
        case "tv":
            return "tv";
        default:
            return "devices";
        }
    }

    function getNetworkIcon(device) {
        if (!device || device.networkStrength < 0)
            return "";
        const strength = device.networkStrength;
        if (strength >= 4)
            return "signal_cellular_alt";
        if (strength >= 3)
            return "signal_cellular_alt_2_bar";
        if (strength >= 2)
            return "signal_cellular_alt_2_bar";
        if (strength >= 1)
            return "signal_cellular_alt_1_bar";
        return "signal_cellular_null";
    }

    function getBatteryIcon(device) {
        if (!device || device.batteryCharge < 0)
            return "";
        const charge = device.batteryCharge;
        const charging = device.batteryCharging;

        if (charging) {
            if (charge >= 90)
                return "battery_charging_full";
            if (charge >= 60)
                return "battery_charging_80";
            if (charge >= 40)
                return "battery_charging_60";
            if (charge >= 20)
                return "battery_charging_30";
            return "battery_charging_20";
        }

        if (charge >= 95)
            return "battery_full";
        if (charge >= 80)
            return "battery_6_bar";
        if (charge >= 65)
            return "battery_5_bar";
        if (charge >= 50)
            return "battery_4_bar";
        if (charge >= 35)
            return "battery_3_bar";
        if (charge >= 20)
            return "battery_2_bar";
        if (charge >= 10)
            return "battery_1_bar";
        return "battery_alert";
    }
}
