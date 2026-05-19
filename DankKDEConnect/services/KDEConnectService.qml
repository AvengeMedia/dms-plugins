pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    readonly property string service: "org.kde.kdeconnect"
    readonly property string daemonPath: "/modules/kdeconnect"
    readonly property string daemonInterface: "org.kde.kdeconnect.daemon"
    readonly property string deviceInterface: "org.kde.kdeconnect.device"
    readonly property string batteryInterface: "org.kde.kdeconnect.device.battery"
    readonly property string connectivityInterface: "org.kde.kdeconnect.device.connectivity_report"
    readonly property string findMyPhoneInterface: "org.kde.kdeconnect.device.findmyphone"
    readonly property string shareInterface: "org.kde.kdeconnect.device.share"
    readonly property string clipboardInterface: "org.kde.kdeconnect.device.clipboard"
    readonly property string mprisRemoteInterface: "org.kde.kdeconnect.device.mprisremote"
    readonly property string smsInterface: "org.kde.kdeconnect.device.sms"
    readonly property string lockInterface: "org.kde.kdeconnect.device.lockdevice"
    readonly property string remoteCommandsInterface: "org.kde.kdeconnect.device.remotecommands"
    readonly property string pingInterface: "org.kde.kdeconnect.device.ping"
    readonly property string sftpInterface: "org.kde.kdeconnect.device.sftp"
    readonly property string photoInterface: "org.kde.kdeconnect.device.photo"

    property bool available: false
    property bool initialized: false
    readonly property bool supportsSms: true
    property var deviceIds: []
    property var devices: ({})
    property bool isRefreshing: false
    property string announcedName: ""
    property string selfId: ""

    property bool _subscribed: false

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
                console.warn("[KDEConnect] Subscription failed:", response.error);
                _subscribed = false;
            }
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
            if (available && !initialized)
                initialize();
            if (!available && wasAvailable) {
                initialized = false;
                deviceIds = [];
                devices = {};
                devicesListChanged();
            }
        });
    }

    function initialize() {
        initialized = true;
        fetchDaemonInfo();
        refreshDevices();
    }

    function fetchDaemonInfo() {
        DMSService.dbusCall("session", service, daemonPath, daemonInterface, "selfId", [], function(response) {
            if (!response.error)
                selfId = response.result?.values?.[0] || "";
        });

        DMSService.dbusCall("session", service, daemonPath, daemonInterface, "announcedName", [], function(response) {
            if (!response.error)
                announcedName = response.result?.values?.[0] || "";
        });
    }

    function handleDbusSignal(data) {
        switch (data.member) {
        case "deviceAdded":
            if (data.body?.[0]) {
                const id = data.body[0];
                if (!deviceIds.includes(id)) {
                    deviceIds = deviceIds.concat([id]);
                    fetchDeviceInfo(id);
                    deviceAdded(id);
                }
            }
            break;
        case "deviceRemoved":
            if (data.body?.[0]) {
                const id = data.body[0];
                deviceIds = deviceIds.filter(function(d) { return d !== id; });
                delete devices[id];
                devices = Object.assign({}, devices);
                deviceRemoved(id);
                devicesListChanged();
            }
            break;
        case "deviceVisibilityChanged":
        case "deviceListChanged":
        case "pairingRequestsChanged":
            refreshDevices();
            break;
        case "reachableChanged":
        case "pairStateChanged":
        case "nameChanged":
        case "pluginsChanged":
        case "linksChanged":
        case "typeChanged":
        case "statusIconNameChanged":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                fetchDeviceInfo(id);
                break;
            }
        case "refreshed":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                fetchBatteryInfo(id);
                break;
            }
        case "connectivityUpdated":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                fetchConnectivityInfo(id);
                break;
            }
        case "PropertiesChanged":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                switch (data.body?.[0]) {
                case batteryInterface:
                    fetchBatteryInfo(id);
                    break;
                case connectivityInterface:
                    fetchConnectivityInfo(id);
                    break;
                case deviceInterface:
                    fetchDeviceInfo(id);
                    break;
                }
                break;
            }
        case "shareReceived":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                const url = data.body?.[0] || "";
                shareReceived(id, url);
                break;
            }
        default:
            break;
        }
    }

    function extractDeviceIdFromPath(path) {
        if (!path?.includes("/devices/"))
            return null;
        return path.split("/devices/")[1]?.split("/")[0] || null;
    }

    function refreshDevices() {
        if (!available || isRefreshing)
            return;
        isRefreshing = true;

        DMSService.dbusCall("session", service, daemonPath, daemonInterface, "devices", [false, false], function(response) {
            isRefreshing = false;
            if (response.error)
                return;
            const ids = response.result?.values?.[0] || [];
            const oldIds = deviceIds.slice();
            deviceIds = ids;

            for (const id of ids) {
                fetchDeviceInfo(id);
            }

            for (const oldId of oldIds) {
                if (!ids.includes(oldId)) {
                    delete devices[oldId];
                }
            }

            devices = Object.assign({}, devices);
            devicesListChanged();
        });
    }

    function fetchDeviceInfo(deviceId) {
        const devicePath = daemonPath + "/devices/" + deviceId;

        DMSService.dbusGetAllProperties("session", service, devicePath, deviceInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId] || {};

            const dev = Object.assign({}, oldDev);
            dev.id = deviceId;
            dev.name = props.name || deviceId;
            dev.type = props.type || "unknown";
            dev.isReachable = props.isReachable || false;
            dev.isPaired = props.isPaired || false;
            dev.isPairRequested = props.isPairRequested || false;
            dev.isPairRequestedByPeer = props.isPairRequestedByPeer || false;
            dev.statusIconName = props.statusIconName || "smartphone";
            dev.supportedPlugins = props.supportedPlugins || [];
            dev.verificationKey = props.verificationKey || "";

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);

            if (dev.isPairRequestedByPeer && dev.verificationKey) {
                pairingRequestReceived(deviceId, dev.verificationKey);
            }

            if (dev.isPaired && dev.isReachable) {
                fetchBatteryInfo(deviceId);
                fetchConnectivityInfo(deviceId);
            }
        });
    }

    function fetchBatteryInfo(deviceId) {
        const path = daemonPath + "/devices/" + deviceId + "/battery";

        DMSService.dbusGetAllProperties("session", service, path, batteryInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            const dev = Object.assign({}, oldDev);
            dev.batteryCharge = props.charge ?? -1;
            dev.batteryCharging = props.isCharging || false;

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function fetchConnectivityInfo(deviceId) {
        const path = daemonPath + "/devices/" + deviceId + "/connectivity_report";

        DMSService.dbusGetAllProperties("session", service, path, connectivityInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            const dev = Object.assign({}, oldDev);
            dev.networkType = props.cellularNetworkType || "";
            dev.networkStrength = props.cellularNetworkStrength ?? -1;

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function updateDeviceBattery(deviceId, isCharging, charge) {
        const oldDev = devices[deviceId];
        if (!oldDev)
            return;
        const dev = Object.assign({}, oldDev);
        dev.batteryCharge = charge;
        dev.batteryCharging = isCharging;

        devices = Object.assign({}, devices, {
            [deviceId]: dev
        });
        deviceUpdated(deviceId);
    }

    function getDevice(deviceId) {
        return devices[deviceId] || null;
    }

    function ringDevice(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/findmyphone";
        DMSService.dbusCall("session", service, path, findMyPhoneInterface, "ring", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function shareUrl(deviceId, url, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/share";
        DMSService.dbusCall("session", service, path, shareInterface, "shareUrl", [url], function(response) {
            if (callback)
                callback(response);
        });
    }

    function shareText(deviceId, text, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/share";
        DMSService.dbusCall("session", service, path, shareInterface, "shareText", [text], function(response) {
            if (callback)
                callback(response);
        });
    }

    function sendClipboard(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/clipboard";
        DMSService.dbusCall("session", service, path, clipboardInterface, "sendClipboard", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function requestPairing(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId;
        DMSService.dbusCall("session", service, path, deviceInterface, "requestPairing", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function acceptPairing(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId;
        DMSService.dbusCall("session", service, path, deviceInterface, "acceptPairing", [], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function cancelPairing(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId;
        DMSService.dbusCall("session", service, path, deviceInterface, "cancelPairing", [], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function unpair(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId;
        DMSService.dbusCall("session", service, path, deviceInterface, "unpair", [], function(response) {
            if (callback)
                callback(response);
            refreshDevices();
        });
    }

    function setLocked(deviceId, locked, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/lockdevice";
        DMSService.dbusSetProperty("session", service, path, lockInterface, "isLocked", locked, function(response) {
            if (callback)
                callback(response);
        });
    }

    function getRemoteCommands(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/remotecommands";
        DMSService.dbusGetProperty("session", service, path, remoteCommandsInterface, "commands", function(response) {
            if (response.error) {
                if (callback)
                    callback([]);
                return;
            }
            try {
                const commands = JSON.parse(response.result || "[]");
                if (callback)
                    callback(commands);
            } catch (e) {
                if (callback)
                    callback([]);
            }
        });
    }

    function triggerRemoteCommand(deviceId, commandKey, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/remotecommands";
        DMSService.dbusCall("session", service, path, remoteCommandsInterface, "triggerCommand", [commandKey], function(response) {
            if (callback)
                callback(response);
        });
    }

    function getMprisPlayers(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/mprisremote";
        DMSService.dbusGetProperty("session", service, path, mprisRemoteInterface, "playerList", function(response) {
            if (callback)
                callback(response.error ? [] : (response.result || []));
        });
    }

    function mprisAction(deviceId, action, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/mprisremote";
        DMSService.dbusCall("session", service, path, mprisRemoteInterface, "sendAction", [action], function(response) {
            if (callback)
                callback(response);
        });
    }

    function sendPing(deviceId, message, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/ping";
        const args = message ? [message] : [];
        DMSService.dbusCall("session", service, path, pingInterface, "sendPing", args, function(response) {
            if (callback)
                callback(response);
        });
    }

    function mountSftp(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "mount", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function unmountSftp(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "unmount", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function mountAndWait(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "mountAndWait", [], function(response) {
            if (callback)
                callback(response.error ? false : (response.result?.values?.[0] ?? false));
        });
    }

    function startBrowsing(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "startBrowsing", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function browseDevice(deviceId, callback) {
        mountAndWait(deviceId, function(success) {
            if (!success) {
                if (callback)
                    callback(false, "");
                return;
            }
            getSftpMountPoint(deviceId, function(mountPoint) {
                if (callback)
                    callback(!!mountPoint, mountPoint);
            });
        });
    }

    function getSftpMountPoint(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "mountPoint", [], function(response) {
            if (callback)
                callback(response.error ? "" : (response.result?.values?.[0] || ""));
        });
    }

    function isSftpMounted(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sftp";
        DMSService.dbusCall("session", service, path, sftpInterface, "isMounted", [], function(response) {
            if (callback)
                callback(response.error ? false : (response.result?.values?.[0] || false));
        });
    }

    function requestPhoto(deviceId, savePath, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/photo";
        DMSService.dbusCall("session", service, path, photoInterface, "requestPhoto", [savePath], function(response) {
            if (callback)
                callback(response);
        });
    }

    function sendSms(deviceId, addresses, message, attachmentUrls, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sms";
        const addressList = Array.isArray(addresses) ? addresses : [addresses];
        const attachments = attachmentUrls || [];
        DMSService.dbusCall("session", service, path, smsInterface, "sendSms", [addressList, message, attachments], function(response) {
            if (callback)
                callback(response);
        });
    }

    function launchSmsApp(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sms";
        DMSService.dbusCall("session", service, path, smsInterface, "launchApp", [], function(response) {
            if (callback)
                callback(response);
        });
    }

    function getConversations(deviceId, callback) {
        const path = daemonPath + "/devices/" + deviceId + "/sms";
        DMSService.dbusCall("session", service, path, smsInterface, "conversations", [], function(response) {
            if (callback)
                callback(response.error ? [] : (response.result?.values?.[0] || []));
        });
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
            return "computer";
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
            return "signal_cellular_4_bar";
        if (strength >= 3)
            return "signal_cellular_3_bar";
        if (strength >= 2)
            return "signal_cellular_2_bar";
        if (strength >= 1)
            return "signal_cellular_1_bar";
        return "signal_cellular_0_bar";
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
