pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Services

Singleton {
    id: root

    enum Backend {
        None,
        KDEConnect,
        Valent
    }

    property int preferredBackend: PhoneConnectService.Backend.KDEConnect
    property int activeBackend: PhoneConnectService.Backend.None

    readonly property bool available: activeBackend !== PhoneConnectService.Backend.None
    readonly property bool initialized: available && (_backend?.initialized ?? false)
    readonly property bool isRefreshing: _backend?.isRefreshing ?? false
    readonly property bool supportsSms: _backend?.supportsSms ?? false

    readonly property string announcedName: _backend?.announcedName ?? ""
    readonly property string selfId: _backend?.selfId ?? ""

    readonly property var deviceIds: _backend?.deviceIds ?? []
    readonly property var devices: _backend?.devices ?? ({})

    readonly property var connectedDevices: _backend?.connectedDevices ?? []
    readonly property var pairedDevices: _backend?.pairedDevices ?? []
    readonly property int connectedCount: _backend?.connectedCount ?? 0
    readonly property int pairedCount: _backend?.pairedCount ?? 0

    readonly property string backendName: {
        switch (activeBackend) {
        case PhoneConnectService.Backend.KDEConnect:
            return "KDE Connect";
        case PhoneConnectService.Backend.Valent:
            return "Valent";
        default:
            return "None";
        }
    }

    property var _backend: null

    signal devicesListChanged
    signal deviceUpdated(string deviceId)
    signal deviceAdded(string deviceId)
    signal deviceRemoved(string deviceId)
    signal pairingRequestReceived(string deviceId, string verificationKey)
    signal shareReceived(string deviceId, string url)
    signal backendChanged

    Component.onCompleted: detectBackend()

    Connections {
        target: DMSService
        function onConnectionStateChanged() {
            if (DMSService.isConnected)
                detectBackend();
        }
    }

    Connections {
        target: KDEConnectService
        enabled: activeBackend === PhoneConnectService.Backend.KDEConnect

        function onDevicesListChanged() {
            root.devicesListChanged();
        }
        function onDeviceUpdated(deviceId) {
            root.deviceUpdated(deviceId);
        }
        function onDeviceAdded(deviceId) {
            root.deviceAdded(deviceId);
        }
        function onDeviceRemoved(deviceId) {
            root.deviceRemoved(deviceId);
        }
        function onPairingRequestReceived(deviceId, verificationKey) {
            root.pairingRequestReceived(deviceId, verificationKey);
        }
        function onShareReceived(deviceId, url) {
            root.shareReceived(deviceId, url);
        }
        function onAvailableChanged() {
            if (!KDEConnectService.available && activeBackend === PhoneConnectService.Backend.KDEConnect)
                detectBackend();
        }
    }

    Connections {
        target: ValentService
        enabled: activeBackend === PhoneConnectService.Backend.Valent

        function onDevicesListChanged() {
            root.devicesListChanged();
        }
        function onDeviceUpdated(deviceId) {
            root.deviceUpdated(deviceId);
        }
        function onDeviceAdded(deviceId) {
            root.deviceAdded(deviceId);
        }
        function onDeviceRemoved(deviceId) {
            root.deviceRemoved(deviceId);
        }
        function onPairingRequestReceived(deviceId, verificationKey) {
            root.pairingRequestReceived(deviceId, verificationKey);
        }
        function onShareReceived(deviceId, url) {
            root.shareReceived(deviceId, url);
        }
        function onAvailableChanged() {
            if (!ValentService.available && activeBackend === PhoneConnectService.Backend.Valent)
                detectBackend();
        }
    }

    function detectBackend() {
        if (!DMSService.isConnected)
            return;

        DMSService.dbusListNames("session", function(response) {
            if (response.error)
                return;

            const names = response.result?.names || [];
            const hasKDE = names.includes("org.kde.kdeconnect");
            const hasValent = names.includes("ca.andyholmes.Valent");

            let newBackend = PhoneConnectService.Backend.None;

            if (preferredBackend === PhoneConnectService.Backend.KDEConnect && hasKDE) {
                newBackend = PhoneConnectService.Backend.KDEConnect;
            } else if (preferredBackend === PhoneConnectService.Backend.Valent && hasValent) {
                newBackend = PhoneConnectService.Backend.Valent;
            } else if (hasKDE) {
                newBackend = PhoneConnectService.Backend.KDEConnect;
            } else if (hasValent) {
                newBackend = PhoneConnectService.Backend.Valent;
            }

            if (newBackend !== activeBackend) {
                activeBackend = newBackend;
                switch (activeBackend) {
                case PhoneConnectService.Backend.KDEConnect:
                    _backend = KDEConnectService;
                    break;
                case PhoneConnectService.Backend.Valent:
                    _backend = ValentService;
                    break;
                default:
                    _backend = null;
                }
                backendChanged();
                devicesListChanged();
            }
        });
    }

    function refreshDevices() {
        _backend?.refreshDevices();
    }

    function getDevice(deviceId) {
        return _backend?.getDevice(deviceId) ?? null;
    }

    function ringDevice(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.ringDevice(deviceId, callback);
    }

    function shareUrl(deviceId, url, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.shareUrl(deviceId, url, callback);
    }

    function shareText(deviceId, text, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.shareText(deviceId, text, callback);
    }

    function sendClipboard(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendClipboard(deviceId, callback);
    }

    function requestPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.requestPairing(deviceId, callback);
    }

    function acceptPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.acceptPairing(deviceId, callback);
    }

    function cancelPairing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.cancelPairing(deviceId, callback);
    }

    function unpair(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.unpair(deviceId, callback);
    }

    function setLocked(deviceId, locked, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.setLocked(deviceId, locked, callback);
    }

    function getRemoteCommands(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getRemoteCommands(deviceId, callback);
    }

    function triggerRemoteCommand(deviceId, commandKey, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.triggerRemoteCommand(deviceId, commandKey, callback);
    }

    function getMprisPlayers(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getMprisPlayers(deviceId, callback);
    }

    function mprisAction(deviceId, action, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.mprisAction(deviceId, action, callback);
    }

    function sendPing(deviceId, message, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendPing(deviceId, message, callback);
    }

    function mountSftp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.mountSftp(deviceId, callback);
    }

    function unmountSftp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.unmountSftp(deviceId, callback);
    }

    function mountAndWait(deviceId, callback) {
        if (!_backend) {
            callback?.(false);
            return;
        }
        _backend.mountAndWait(deviceId, callback);
    }

    function startBrowsing(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.startBrowsing(deviceId, callback);
    }

    function browseDevice(deviceId, callback) {
        if (!_backend) {
            callback?.(false, "");
            return;
        }
        _backend.browseDevice(deviceId, callback);
    }

    function getSftpMountPoint(deviceId, callback) {
        if (!_backend) {
            callback?.("");
            return;
        }
        _backend.getSftpMountPoint(deviceId, callback);
    }

    function isSftpMounted(deviceId, callback) {
        if (!_backend) {
            callback?.(false);
            return;
        }
        _backend.isSftpMounted(deviceId, callback);
    }

    function requestPhoto(deviceId, savePath, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.requestPhoto(deviceId, savePath, callback);
    }

    function sendSms(deviceId, addresses, message, attachmentUrls, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.sendSms(deviceId, addresses, message, attachmentUrls, callback);
    }

    function launchSmsApp(deviceId, callback) {
        if (!_backend) {
            callback?.({
                error: "No backend"
            });
            return;
        }
        _backend.launchSmsApp(deviceId, callback);
    }

    function getConversations(deviceId, callback) {
        if (!_backend) {
            callback?.([]);
            return;
        }
        _backend.getConversations(deviceId, callback);
    }

    function getDeviceIcon(device) {
        return _backend?.getDeviceIcon(device) ?? "smartphone";
    }

    function getNetworkIcon(device) {
        return _backend?.getNetworkIcon(device) ?? "";
    }

    function getBatteryIcon(device) {
        return _backend?.getBatteryIcon(device) ?? "";
    }
}
