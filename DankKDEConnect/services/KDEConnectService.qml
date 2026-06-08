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
    readonly property string propertiesInterface: "org.freedesktop.DBus.Properties"
    readonly property string notificationsInterface: "org.kde.kdeconnect.device.notifications"

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

    function hasPlugin(dev, pluginName) {
        if (!dev || !dev.supportedPlugins) return false;
        return dev.supportedPlugins.includes(pluginName) || 
               dev.supportedPlugins.includes("kdeconnect_" + pluginName);
    }

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
        DMSService.dbusSubscribe("session", service, "", propertiesInterface, "PropertiesChanged", function(response) {
            if (response.error) {
                console.warn("[KDEConnect] Properties subscription failed:", response.error);
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
        if (data.path && data.path.includes("mpris")) {
            console.warn("[KDEConnect] MPRIS DBus Signal:", JSON.stringify(data));
        }
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
                const isCharging = data.body?.[0] ?? false;
                const charge = data.body?.[1] ?? -1;
                updateDeviceBattery(id, isCharging, charge);
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
        case "notificationPosted":
        case "notificationRemoved":
        case "allNotificationsRemoved":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                fetchNotificationsCount(id);
                break;
            }
        case "propertiesChanged":
            {
                const id = extractDeviceIdFromPath(data.path);
                if (!id)
                    break;
                if (data.interface === mprisRemoteInterface) {
                    fetchMprisInfo(id);
                }
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
                case notificationsInterface:
                    fetchNotificationsCount(id);
                    break;
                case deviceInterface:
                    fetchDeviceInfo(id);
                    break;
                case mprisRemoteInterface:
                    fetchMprisInfo(id);
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
        _dbusFinished = false;
        refreshMinTimer.start();

        DMSService.dbusCall("session", service, daemonPath, daemonInterface, "devices", [false, false], function(response) {
            root._dbusFinished = true;
            if (!refreshMinTimer.running) {
                root.isRefreshing = false;
            }
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
            const newName = props.name || deviceId;
            const newType = props.type || "unknown";
            const newIsReachable = props.isReachable || false;
            const newIsPaired = props.isPaired || false;
            const newIsPairRequested = props.isPairRequested || false;
            const newIsPairRequestedByPeer = props.isPairRequestedByPeer || false;
            const newStatusIconName = props.statusIconName || "smartphone";
            const newSupportedPlugins = props.supportedPlugins || [];
            const newVerificationKey = props.verificationKey || "";

            const changed = !devices[deviceId] ||
                            oldDev.id !== deviceId ||
                            oldDev.name !== newName ||
                            oldDev.type !== newType ||
                            oldDev.isReachable !== newIsReachable ||
                            oldDev.isPaired !== newIsPaired ||
                            oldDev.isPairRequested !== newIsPairRequested ||
                            oldDev.isPairRequestedByPeer !== newIsPairRequestedByPeer ||
                            oldDev.statusIconName !== newStatusIconName ||
                            oldDev.verificationKey !== newVerificationKey ||
                            JSON.stringify(oldDev.supportedPlugins) !== JSON.stringify(newSupportedPlugins);

            if (changed) {
                const dev = Object.assign({}, oldDev);
                dev.id = deviceId;
                dev.name = newName;
                dev.type = newType;
                dev.isReachable = newIsReachable;
                dev.isPaired = newIsPaired;
                dev.isPairRequested = newIsPairRequested;
                dev.isPairRequestedByPeer = newIsPairRequestedByPeer;
                dev.statusIconName = newStatusIconName;
                dev.supportedPlugins = newSupportedPlugins;
                dev.verificationKey = newVerificationKey;

                console.warn("[KDEConnect] Device info changed for", deviceId, ": name =", dev.name);
                devices = Object.assign({}, devices, {
                    [deviceId]: dev
                });
                deviceUpdated(deviceId);
            }

            const currentDev = devices[deviceId];
            if (currentDev) {
                if (currentDev.isPairRequestedByPeer && currentDev.verificationKey) {
                    pairingRequestReceived(deviceId, currentDev.verificationKey);
                }

                if (currentDev.isPaired && currentDev.isReachable) {
                    fetchBatteryInfo(deviceId);
                    fetchConnectivityInfo(deviceId);
                    fetchNotificationsCount(deviceId);
                }
            }
        });
    }

    function fetchBatteryInfo(deviceId) {
        const dev = devices[deviceId];
        if (!hasPlugin(dev, "battery"))
            return;
        const path = daemonPath + "/devices/" + deviceId + "/battery";

        DMSService.dbusGetAllProperties("session", service, path, batteryInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            const newCharge = props.charge ?? -1;
            const newCharging = props.isCharging ?? props.charging ?? false;
            if (oldDev.batteryCharge === newCharge && oldDev.batteryCharging === newCharging)
                return;

            const dev = Object.assign({}, oldDev);
            dev.batteryCharge = newCharge;
            dev.batteryCharging = newCharging;

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function fetchConnectivityInfo(deviceId) {
        const dev = devices[deviceId];
        if (!hasPlugin(dev, "connectivity_report"))
            return;
        const path = daemonPath + "/devices/" + deviceId + "/connectivity_report";

        DMSService.dbusGetAllProperties("session", service, path, connectivityInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            const newNetworkType = props.cellularNetworkType || "";
            const newNetworkStrength = props.cellularNetworkStrength ?? -1;
            if (oldDev.networkType === newNetworkType && oldDev.networkStrength === newNetworkStrength)
                return;

            const dev = Object.assign({}, oldDev);
            dev.networkType = newNetworkType;
            dev.networkStrength = newNetworkStrength;

            devices = Object.assign({}, devices, {
                [deviceId]: dev
            });
            deviceUpdated(deviceId);
        });
    }

    function fetchNotificationsCount(deviceId) {
        const dev = devices[deviceId];
        if (!hasPlugin(dev, "notifications"))
            return;
        const path = daemonPath + "/devices/" + deviceId + "/notifications";

        DMSService.dbusCall("session", service, path, notificationsInterface, "activeNotifications", [], function(response) {
            if (response.error)
                return;
            const result = response.result?.values;
            let list = [];
            if (result && result.length > 0) {
                list = result[0];
                if (!list) {
                    list = [];
                } else if (!Array.isArray(list)) {
                    list = [list];
                }
            }

            const count = list.length;
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            if (oldDev.notificationCount === count)
                return;

            const updatedDev = Object.assign({}, oldDev);
            updatedDev.notificationCount = count;

            devices = Object.assign({}, devices, {
                [deviceId]: updatedDev
            });
            deviceUpdated(deviceId);
        });
    }

    function fetchMprisInfo(deviceId) {
        const dev = devices[deviceId];
        if (!hasPlugin(dev, "mprisremote"))
            return;
        const path = daemonPath + "/devices/" + deviceId + "/mprisremote";

        DMSService.dbusGetAllProperties("session", service, path, mprisRemoteInterface, function(response) {
            if (response.error)
                return;
            const props = response.result || {};
            const oldDev = devices[deviceId];
            if (!oldDev)
                return;
            let nowPlaying = props.nowPlaying || props.NowPlaying || "";
            let title = props.title || props.Title || "";
            let artist = props.artist || props.Artist || "";
            let album = props.album || props.Album || "";

            if (!title && nowPlaying) {
                let parts = [];
                if (nowPlaying.includes(" - ")) {
                    parts = nowPlaying.split(" - ");
                } else if (nowPlaying.includes(" — ")) {
                    parts = nowPlaying.split(" — ");
                } else if (nowPlaying.includes(" – ")) {
                    parts = nowPlaying.split(" – ");
                }
                
                if (parts.length >= 2) {
                    artist = parts[0].trim();
                    title = parts.slice(1).join(" - ").trim();
                } else {
                    title = nowPlaying;
                }
            }

            const newIsPlaying = props.isPlaying || props.IsPlaying || props.isplaying || (props.PlaybackStatus === "Playing") || false;
            const newPlayer = props.player || props.Player || (props.playerList && props.playerList.length > 0 ? props.playerList[0] : "") || "";

            if (oldDev.mediaTitle === title &&
                oldDev.mediaArtist === artist &&
                oldDev.mediaAlbum === album &&
                oldDev.mediaIsPlaying === newIsPlaying &&
                oldDev.mediaPlayer === newPlayer) {
                return;
            }

            const dev = Object.assign({}, oldDev);
            dev.mediaTitle = title;
            dev.mediaArtist = artist;
            dev.mediaAlbum = album;
            dev.mediaIsPlaying = newIsPlaying;
            dev.mediaPlayer = newPlayer;

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
        if (oldDev.batteryCharge === charge && oldDev.batteryCharging === isCharging)
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
            return "signal_cellular_alt_2_bar"; // 3 bars usually translates to 2 out of 3, or just signal_cellular_alt_2_bar
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
