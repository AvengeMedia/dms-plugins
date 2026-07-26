pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool available: ipc.connected && ipc.subscribed
    property bool initialized: false
    property bool isRefreshing: false
    readonly property bool supportsSms: true
    property string announcedName: ""
    property string selfId: ""
    property var deviceIds: []
    property var devices: ({})
    property var _mediaPlayers: ({})

    readonly property var connectedDevices: {
        const result = [];
        for (const id of deviceIds) {
            const device = devices[id];
            if (device?.isReachable)
                result.push(device);
        }
        return result;
    }
    readonly property var pairedDevices: {
        const result = [];
        for (const id of deviceIds) {
            const device = devices[id];
            if (device?.isPaired)
                result.push(device);
        }
        return result;
    }
    readonly property int connectedCount: connectedDevices.length
    readonly property int pairedCount: pairedDevices.length

    signal devicesListChanged
    signal deviceUpdated(string deviceId)
    signal deviceAdded(string deviceId)
    signal deviceRemoved(string deviceId)
    signal pairingRequestReceived(string deviceId, string verificationKey)
    signal shareReceived(string deviceId, string url)

    DankConnectIpc {
        id: ipc
    }

    Connections {
        target: ipc

        function onConnectedChanged() {
            if (!ipc.connected) {
                root._clearDevices();
                root.initialized = false;
                root.announcedName = "";
                root.selfId = "";
                return;
            }
            root._fetchDaemonInfo();
        }

        function onDevicesChanged() {
            root._applySnapshots(ipc.devices);
        }

        function onInitializedChanged() {
            root.initialized = ipc.initialized;
        }

        function onEventReceived(topic, data) {
            switch (topic) {
            case "pairing":
                if (data?.deviceId)
                    root.pairingRequestReceived(data.deviceId, data.verificationKey || "");
                break;
            case "share":
                if (data?.deviceId && data.direction === "received" && data.path)
                    root.shareReceived(data.deviceId, "file://" + data.path);
                break;
            case "media":
                root._handleMediaEvent(data);
                break;
            case "settings":
                if (data?.deviceName)
                    root.announcedName = data.deviceName;
                break;
            }
        }
    }

    function _fetchDaemonInfo() {
        ipc.request("daemon.info", {}, response => {
            if (response.error)
                return;
            selfId = response.result?.deviceId || "";
            announcedName = response.result?.deviceName || "";
        });
    }

    function launch() {
        ipc.launch();
    }

    function _shortPluginNames(device) {
        const supported = device?.supportedPlugins || [];
        const outgoing = device?.outgoingCapabilities || [];
        const result = [];
        const add = name => {
            if (!result.includes(name))
                result.push(name);
        };

        if (supported.includes("kdeconnect.findmyphone.request"))
            add("findmyphone");
        if (supported.includes("kdeconnect.ping"))
            add("ping");
        if (supported.includes("kdeconnect.clipboard") || supported.includes("kdeconnect.clipboard.connect"))
            add("clipboard");
        if (supported.includes("kdeconnect.share.request"))
            add("share");
        if (supported.includes("kdeconnect.sms.request") || outgoing.includes("kdeconnect.sms.messages"))
            add("sms");
        if (outgoing.includes("kdeconnect.battery"))
            add("battery");
        if (outgoing.includes("kdeconnect.notification"))
            add("notifications");
        if (outgoing.includes("kdeconnect.mpris"))
            add("mprisremote");
        if (outgoing.includes("kdeconnect.connectivity_report"))
            add("connectivity_report");
        return result;
    }

    function _mappedDevice(snapshot) {
        const device = Object.assign({}, snapshot);
        device.supportedPlugins = _shortPluginNames(snapshot);
        device.statusIconName = getDeviceIcon(device);

        const players = _mediaPlayers[device.id] || [];
        let activePlayer = null;
        for (const player of players) {
            if (player?.isPlaying) {
                activePlayer = player;
                break;
            }
        }
        if (!activePlayer && players.length > 0)
            activePlayer = players[0];
        device.mediaPlayer = activePlayer?.player || "";
        device.mediaTitle = activePlayer?.title || activePlayer?.nowPlaying || "";
        device.mediaArtist = activePlayer?.artist || "";
        device.mediaAlbum = activePlayer?.album || "";
        device.mediaIsPlaying = activePlayer?.isPlaying || false;
        return device;
    }

    function _applySnapshots(snapshots) {
        const oldIds = deviceIds.slice();
        const oldDevices = devices;
        const nextIds = [];
        const nextDevices = {};

        for (const snapshot of (snapshots || [])) {
            if (!snapshot?.id)
                continue;
            nextIds.push(snapshot.id);
            nextDevices[snapshot.id] = _mappedDevice(snapshot);
        }

        deviceIds = nextIds;
        devices = nextDevices;

        for (const oldId of oldIds) {
            if (!nextDevices[oldId])
                deviceRemoved(oldId);
        }
        for (const id of nextIds) {
            if (!oldDevices[id])
                deviceAdded(id);
            else if (JSON.stringify(oldDevices[id]) !== JSON.stringify(nextDevices[id]))
                deviceUpdated(id);
        }
        devicesListChanged();
    }

    function _clearDevices() {
        const oldIds = deviceIds.slice();
        deviceIds = [];
        devices = {};
        _mediaPlayers = {};
        for (const id of oldIds)
            deviceRemoved(id);
        devicesListChanged();
    }

    function _setMediaPlayers(deviceId, players) {
        const next = Object.assign({}, _mediaPlayers);
        next[deviceId] = players || [];
        _mediaPlayers = next;
        _applySnapshots(ipc.devices);
    }

    function _handleMediaEvent(data) {
        const deviceId = data?.deviceId || "";
        if (!deviceId)
            return;
        if (data.player?.player) {
            const players = (_mediaPlayers[deviceId] || []).slice();
            const index = players.findIndex(player => player?.player === data.player.player);
            if (index >= 0)
                players[index] = Object.assign({}, players[index], data.player);
            else
                players.push(data.player);
            _setMediaPlayers(deviceId, players);
            return;
        }
        if (Array.isArray(data.players))
            getMprisPlayers(deviceId, function() {});
    }

    function refreshDevices() {
        if (!available || isRefreshing)
            return;
        isRefreshing = true;
        ipc.refreshDevices(response => {
            root.isRefreshing = false;
        });
    }

    function getDevice(deviceId) {
        return devices[deviceId] || null;
    }

    function ringDevice(deviceId, callback) {
        ipc.request("device.ring", {
            "deviceId": deviceId
        }, callback);
    }

    function shareUrl(deviceId, url, callback) {
        const path = _localPath(url);
        const params = {
            "deviceId": deviceId
        };
        if (path)
            params.path = path;
        else
            params.url = url;
        ipc.request("share.send", params, callback);
    }

    function shareText(deviceId, text, callback) {
        ipc.request("share.send", {
            "deviceId": deviceId,
            "text": text
        }, callback);
    }

    function sendClipboard(deviceId, callback) {
        ipc.request("clipboard.send", {
            "deviceId": deviceId,
            "content": ""
        }, callback);
    }

    function requestPairing(deviceId, callback) {
        ipc.request("pairing.request", {
            "deviceId": deviceId
        }, callback);
    }

    function acceptPairing(deviceId, callback) {
        ipc.request("pairing.accept", {
            "deviceId": deviceId
        }, callback);
    }

    function cancelPairing(deviceId, callback) {
        ipc.request("pairing.reject", {
            "deviceId": deviceId
        }, callback);
    }

    function unpair(deviceId, callback) {
        ipc.request("pairing.unpair", {
            "deviceId": deviceId
        }, callback);
    }

    function getMprisPlayers(deviceId, callback) {
        ipc.request("device.media", {
            "deviceId": deviceId
        }, response => {
            const players = response.error ? [] : (response.result?.players || []);
            if (!response.error)
                root._setMediaPlayers(deviceId, players);
            callback?.(players);
        });
    }

    function mprisAction(deviceId, action, callback) {
        const player = devices[deviceId]?.mediaPlayer || "";
        if (!player) {
            callback?.({
                "error": "No media player"
            });
            return;
        }
        const actionMap = {
            "play": "Play",
            "pause": "Pause",
            "playpause": "PlayPause",
            "stop": "Stop",
            "next": "Next",
            "previous": "Previous"
        };
        const normalized = actionMap[action.toString().toLowerCase()] || action;
        ipc.request("media.control", {
            "deviceId": deviceId,
            "player": player,
            "action": normalized
        }, callback);
    }

    function sendPing(deviceId, message, callback) {
        const params = {
            "deviceId": deviceId
        };
        if (message)
            params.message = message;
        ipc.request("ping.send", params, callback);
    }

    function sendSms(deviceId, addresses, message, attachmentUrls, callback) {
        const addressList = Array.isArray(addresses) ? addresses : [addresses];
        const attachments = [];
        for (const url of (attachmentUrls || [])) {
            const path = _localPath(url);
            if (path)
                attachments.push(path);
        }
        ipc.request("sms.send", {
            "deviceId": deviceId,
            "addresses": addressList,
            "message": message,
            "attachments": attachments
        }, callback);
    }

    function getConversations(deviceId, callback) {
        ipc.request("device.conversations", {
            "deviceId": deviceId
        }, response => callback?.(response.error ? [] : (response.result || [])));
    }

    function launchSmsApp(deviceId, callback) {
        Quickshell.execDetached(["sh", "-c", "if command -v dankconnect >/dev/null 2>&1; then exec dankconnect app; elif command -v flatpak >/dev/null 2>&1 && flatpak info com.danklinux.dankconnect >/dev/null 2>&1; then exec flatpak run --command=dankconnect com.danklinux.dankconnect app; fi"]);
        callback?.({
            "success": true
        });
    }

    function _unsupported(callback) {
        callback?.({
            "error": "unsupported"
        });
    }

    function setLocked(deviceId, locked, callback) {
        _unsupported(callback);
    }
    function getRemoteCommands(deviceId, callback) {
        callback?.([]);
    }
    function triggerRemoteCommand(deviceId, commandKey, callback) {
        _unsupported(callback);
    }
    function mountSftp(deviceId, callback) {
        _unsupported(callback);
    }
    function unmountSftp(deviceId, callback) {
        _unsupported(callback);
    }
    function mountAndWait(deviceId, callback) {
        callback?.(false);
    }
    function startBrowsing(deviceId, callback) {
        _unsupported(callback);
    }
    function browseDevice(deviceId, callback) {
        callback?.(false, "");
    }
    function getSftpMountPoint(deviceId, callback) {
        callback?.("");
    }
    function isSftpMounted(deviceId, callback) {
        callback?.(false);
    }
    function requestPhoto(deviceId, savePath, callback) {
        _unsupported(callback);
    }

    function _localPath(value) {
        if (!value)
            return "";
        const text = value.toString();
        if (text.startsWith("/"))
            return text;
        if (!text.startsWith("file://"))
            return "";
        let path = text.substring(7);
        if (path.startsWith("localhost/"))
            path = path.substring(9);
        if (!path.startsWith("/"))
            path = "/" + path;
        try {
            return decodeURIComponent(path);
        } catch (error) {
            return path;
        }
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
        case "computer":
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
        if (device.batteryCharging)
            return charge >= 90 ? "battery_charging_full" : "battery_charging_90";
        if (charge >= 90)
            return "battery_full";
        if (charge >= 60)
            return "battery_6_bar";
        if (charge >= 30)
            return "battery_4_bar";
        if (charge >= 15)
            return "battery_2_bar";
        return "battery_1_bar";
    }
}
