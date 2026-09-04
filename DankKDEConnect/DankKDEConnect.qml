import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"
import "./services"
import QtQuick.Effects
import QtQuick.Shapes

PluginComponent {
    id: root

    PluginGlobalVar {
        id: deviceImageMapVar
        varName: "deviceImageMap"
    }

    PluginGlobalVar {
        id: deviceRecentImagesPathMapVar
        varName: "deviceRecentImagesPathMap"
    }

    PluginGlobalVar {
        id: deviceTypeMapVar
        varName: "deviceTypeMap"
    }

    PluginGlobalVar {
        id: recentImagesPathVar
        varName: "recentImagesPath"
    }

    PluginGlobalVar {
        id: maxRecentImagesVar
        varName: "maxRecentImages"
    }

    PluginGlobalVar {
        id: enableClipboardActionVar
        varName: "enableClipboardAction"
    }

    PluginGlobalVar {
        id: showOngoingMediaVar
        varName: "showOngoingMedia"
    }

    PluginGlobalVar {
        id: stateUpdateIntervalVar
        varName: "stateUpdateInterval"
    }

    PluginGlobalVar {
        id: enableChargingAnimationVar
        varName: "enableChargingAnimation"
    }

    PluginGlobalVar {
        id: recentImagesCacheMapVar
        varName: "recentImagesCacheMap"
    }

    PluginGlobalVar {
        id: scanSubdirectoriesVar
        varName: "scanSubdirectories"
    }

    PluginGlobalVar {
        id: showDevicePlaceholderVar
        varName: "showDevicePlaceholder"
    }

    property bool enableChargingAnimation: (enableChargingAnimationVar.value !== undefined && enableChargingAnimationVar.value !== null) ? (enableChargingAnimationVar.value === true || enableChargingAnimationVar.value === "true") : ((SettingsData.pluginSettings["dankKDEConnect"]?.enableChargingAnimation !== undefined) ? (SettingsData.pluginSettings["dankKDEConnect"]?.enableChargingAnimation === true || SettingsData.pluginSettings["dankKDEConnect"]?.enableChargingAnimation === "true") : true)
    property bool showDevicePlaceholder: (showDevicePlaceholderVar.value !== undefined && showDevicePlaceholderVar.value !== null) ? (showDevicePlaceholderVar.value === true || showDevicePlaceholderVar.value === "true") : ((SettingsData.pluginSettings["dankKDEConnect"]?.showDevicePlaceholder !== undefined) ? (SettingsData.pluginSettings["dankKDEConnect"]?.showDevicePlaceholder === true || SettingsData.pluginSettings["dankKDEConnect"]?.showDevicePlaceholder === "true") : true)

    property string selectedDeviceId: SettingsData.pluginSettings["dankKDEConnect"]?.selectedDeviceId || ""
    // Per-device custom image map: { deviceId: imagePath }
    property var deviceImageMap: ({})

    // Image for the currently selected device
    readonly property string customPhoneImage: deviceImageMap[selectedDeviceId] || ""

    property bool isSeeking: false
    property bool popoutOpen: false
    onPopoutOpenChanged: {
        if (popoutOpen) {
            PhoneConnectService.refreshDevices();
        }
    }

    // Animated/active state for smooth device switching transitions (non-reactive initial to prevent instant snapping)
    property string activeDeviceId: ""
    readonly property var activeDevice: activeDeviceId ? (PhoneConnectService.devices[activeDeviceId] ?? null) : null
    readonly property string activeCustomPhoneImage: deviceImageMap[activeDeviceId] || ""

    readonly property MprisPlayer phoneMprisPlayer: {
        if (!root.activeDevice || !root.activeDevice.name || typeof MprisController === "undefined") {
            return null;
        }
        const players = MprisController.availablePlayers || [];
        const devicePlayers = [];
        const normDevice = root.activeDevice.name.toLowerCase().replace(/[^a-z0-9]/g, "");
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (p) {
                if (p.dbusName && p.dbusName.indexOf("org.mpris.MediaPlayer2.kdeconnect") === 0 && p.identity) {
                    const normIdentity = p.identity.toLowerCase().replace(/[^a-z0-9]/g, "");
                    if (normIdentity.indexOf(normDevice) !== -1) {
                        devicePlayers.push(p);
                    }
                }
            }
        }
        if (devicePlayers.length === 0) {
            return null;
        }
        for (let i = 0; i < devicePlayers.length; i++) {
            if (devicePlayers[i].playbackState === MprisPlaybackState.Playing) {
                return devicePlayers[i];
            }
        }
        return devicePlayers[0];
    }

    readonly property bool hasOngoingMediaActive: {
        if (!root.hasDevice || !root.showOngoingMedia || root.deviceSwitching)
            return false;
        if (root.phoneMprisPlayer && (root.phoneMprisPlayer.trackTitle || "") !== "")
            return true;
        if ((root.activeDevice?.mediaTitle || "") !== "")
            return true;
        return false;
    }

    readonly property real container1Width: (root.activeDevice?.type === "desktop" || root.activeDevice?.type === "computer" || root.activeDevice?.type === "laptop") ? 240 : (root.activeDevice?.type === "tv") ? 260 : (root.activeDevice?.type === "tablet") ? 185 : 135

    onActiveDeviceIdChanged: {
        // Clear images immediately and stop any ongoing scan.
        // Do NOT call refreshImages here — recentImagesPath is a reactive binding
        // on activeDeviceId and hasn't re-evaluated yet in this tick.
        // onRecentImagesPathChanged will fire after the binding settles and kick off the scan.
        recentImages = [];
        if (imagesScanner)
            imagesScanner.running = false;
    }

    onSelectedDeviceIdChanged: {
        if (activeDeviceId === "") {
            activeDeviceId = selectedDeviceId;
        } else if (selectedDeviceId !== activeDeviceId) {
            if (!popoutOpen) {
                activeDeviceId = selectedDeviceId;
            }
        }
    }

    function loadDeviceTypeMap() {
        const savedVal = deviceTypeMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try {
                return JSON.parse(savedVal);
            } catch (e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceTypeMap) {
            try {
                return JSON.parse(data.deviceTypeMap);
            } catch (e) {}
        }
        return {};
    }

    function loadDeviceImageMap() {
        const savedVal = deviceImageMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try {
                return JSON.parse(savedVal);
            } catch (e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceImageMap) {
            try {
                return JSON.parse(data.deviceImageMap);
            } catch (e) {}
        }
        const legacy = data?.customPhoneImage || "";
        if (legacy) {
            const ids = PhoneConnectService.deviceIds;
            if (ids && ids.length > 0) {
                const m = {};
                m[ids[0]] = legacy;
                return m;
            }
        }
        return {};
    }

    function loadDeviceRecentImagesPathMap() {
        const savedVal = deviceRecentImagesPathMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try {
                return JSON.parse(savedVal);
            } catch (e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceRecentImagesPathMap) {
            try {
                return JSON.parse(data.deviceRecentImagesPathMap);
            } catch (e) {}
        }
        return {};
    }

    function loadRecentImagesPath() {
        if (activeDeviceId) {
            if (deviceRecentImagesPathMap[activeDeviceId]) {
                return deviceRecentImagesPathMap[activeDeviceId];
            }
            const ids = PhoneConnectService.deviceIds;
            if (ids && ids.length > 0 && activeDeviceId === ids[0]) {
                const savedVal = recentImagesPathVar.value;
                if (savedVal !== undefined && savedVal !== null)
                    return savedVal;
                const data = SettingsData.pluginSettings["dankKDEConnect"];
                return data?.recentImagesPath || "";
            }
        }
        return "";
    }

    function loadRecentImagesCache(path) {
        if (!path)
            return [];
        const savedVal = recentImagesCacheMapVar.value;
        if (savedVal) {
            try {
                const map = JSON.parse(savedVal);
                if (map[path])
                    return map[path];
            } catch (e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.recentImagesCacheMap) {
            try {
                const map = JSON.parse(data.recentImagesCacheMap);
                if (map[path])
                    return map[path];
            } catch (e) {}
        }
        return [];
    }

    function saveRecentImagesCache() {
        if (!root.recentImagesPath || root.recentImages.length === 0)
            return;
        const savedVal = recentImagesCacheMapVar.value;
        let map = {};
        if (savedVal) {
            try {
                map = JSON.parse(savedVal);
            } catch (e) {}
        }
        map[root.recentImagesPath] = root.recentImages;
        let str = JSON.stringify(map);
        recentImagesCacheMapVar.set(str);
        PluginService.savePluginData("dankKDEConnect", "recentImagesCacheMap", str);
    }

    function loadMaxRecentImages() {
        const savedVal = maxRecentImagesVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            const parsed = parseInt(savedVal);
            if (!isNaN(parsed))
                return parsed;
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        return data?.maxRecentImages || 4;
    }

    function loadEnableClipboardAction() {
        const globalVal = enableClipboardActionVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.enableClipboardAction;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }

    function loadShowOngoingMedia() {
        const globalVal = showOngoingMediaVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.showOngoingMedia;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }

    function loadStateUpdateInterval() {
        const globalVal = stateUpdateIntervalVar.value;
        if (globalVal !== undefined && globalVal !== null && globalVal !== "") {
            const parsed = parseInt(globalVal);
            if (!isNaN(parsed))
                return parsed;
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        return parseInt(data?.stateUpdateInterval) || 30;
    }

    function loadEnableChargingAnimation() {
        const globalVal = enableChargingAnimationVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.enableChargingAnimation;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }

    function loadShowDevicePlaceholder() {
        const globalVal = showDevicePlaceholderVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.showDevicePlaceholder;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }

    Connections {
        target: deviceTypeMapVar
        ignoreUnknownSignals: true
        function onValueChanged() {
            deviceTypeMap = loadDeviceTypeMap();
        }
    }
    Connections {
        target: deviceImageMapVar
        ignoreUnknownSignals: true
        function onValueChanged() {
            deviceImageMap = loadDeviceImageMap();
        }
    }
    Connections {
        target: deviceRecentImagesPathMapVar
        ignoreUnknownSignals: true
        function onValueChanged() {
            deviceRecentImagesPathMap = loadDeviceRecentImagesPathMap();
        }
    }
    Component.onCompleted: {
        if (activeDeviceId === "" && selectedDeviceId !== "") {
            activeDeviceId = selectedDeviceId;
        }
        deviceTypeMap = loadDeviceTypeMap();
        deviceImageMap = loadDeviceImageMap();
        deviceRecentImagesPathMap = loadDeviceRecentImagesPathMap();

        PhoneConnectService.deviceTypeMap = root.deviceTypeMap;
        PhoneConnectService.refreshDevices();
    }

    function getDeviceImage(deviceId) {
        return deviceImageMap[deviceId] || "";
    }

    function setDeviceImage(deviceId, path) {
        const updated = Object.assign({}, deviceImageMap);
        if (path === "" || path === null)
            delete updated[deviceId];
        else
            updated[deviceId] = path;
        deviceImageMapVar.set(JSON.stringify(updated));
        PluginService.savePluginData("dankKDEConnect", "deviceImageMap", JSON.stringify(updated));
    }

    property var deviceRecentImagesPathMap: ({})

    function getDeviceRecentImagesPath(deviceId) {
        return deviceRecentImagesPathMap[deviceId] || "";
    }

    function setDeviceRecentImagesPath(deviceId, path) {
        const updated = Object.assign({}, deviceRecentImagesPathMap);
        if (path === "" || path === null)
            delete updated[deviceId];
        else
            updated[deviceId] = path;
        deviceRecentImagesPathMapVar.set(JSON.stringify(updated));
        PluginService.savePluginData("dankKDEConnect", "deviceRecentImagesPathMap", JSON.stringify(updated));
    }

    // Per-device custom type map: { deviceId: type }
    property var deviceTypeMap: ({})

    onDeviceTypeMapChanged: {
        PhoneConnectService.deviceTypeMap = deviceTypeMap;
    }

    function getDeviceType(deviceId) {
        return deviceTypeMap[deviceId] || "";
    }

    function setDeviceType(deviceId, type) {
        const updated = Object.assign({}, deviceTypeMap);
        if (type === "" || type === null)
            delete updated[deviceId];
        else
            updated[deviceId] = type;
        deviceTypeMap = updated;
        PhoneConnectService.deviceTypeMap = updated;
        deviceTypeMapVar.set(JSON.stringify(updated));
        PluginService.savePluginData("dankKDEConnect", "deviceTypeMap", JSON.stringify(updated));
    }

    property string recentImagesPath: activeDeviceId ? (deviceRecentImagesPathMap[activeDeviceId] || ((PhoneConnectService.deviceIds.length > 0 && activeDeviceId === PhoneConnectService.deviceIds[0]) ? (recentImagesPathVar.value !== undefined && recentImagesPathVar.value !== null ? recentImagesPathVar.value : (SettingsData.pluginSettings["dankKDEConnect"]?.recentImagesPath || "")) : "")) : ""
    property int maxRecentImages: (maxRecentImagesVar.value !== undefined && maxRecentImagesVar.value !== null && maxRecentImagesVar.value !== "") ? parseInt(maxRecentImagesVar.value) : (SettingsData.pluginSettings["dankKDEConnect"]?.maxRecentImages || 4)
    property var recentImages: []
    readonly property bool loadingImages: imagesScanner && imagesScanner.running
    property bool showShareDialog: false
    property bool showSmsDialog: false
    property string shareDeviceId: ""
    property bool deviceSwitching: false

    onCustomPhoneImageChanged: {
        console.log("[DMS DEBUG DankKDEConnect] customPhoneImage changed to:", customPhoneImage);
    }

    // Reactive binding: always reflects the latest device data from the service
    readonly property bool hasDevice: selectedDeviceId !== "" && PhoneConnectService.deviceIds.includes(selectedDeviceId)
    readonly property var selectedDevice: hasDevice ? (PhoneConnectService.devices[selectedDeviceId] ?? null) : null
    readonly property bool isSelectedDeviceMobile: root.selectedDevice && (root.selectedDevice.type === "phone" || root.selectedDevice.type === "smartphone" || root.selectedDevice.type === "tablet")
    readonly property string serviceName: PhoneConnectService.backendName

    property bool enableClipboardAction: (enableClipboardActionVar.value !== undefined && enableClipboardActionVar.value !== null) ? (enableClipboardActionVar.value === true || enableClipboardActionVar.value === "true") : ((SettingsData.pluginSettings["dankKDEConnect"]?.enableClipboardAction !== undefined) ? (SettingsData.pluginSettings["dankKDEConnect"]?.enableClipboardAction === true || SettingsData.pluginSettings["dankKDEConnect"]?.enableClipboardAction === "true") : true)
    property bool showOngoingMedia: (showOngoingMediaVar.value !== undefined && showOngoingMediaVar.value !== null) ? (showOngoingMediaVar.value === true || showOngoingMediaVar.value === "true") : ((SettingsData.pluginSettings["dankKDEConnect"]?.showOngoingMedia !== undefined) ? (SettingsData.pluginSettings["dankKDEConnect"]?.showOngoingMedia === true || SettingsData.pluginSettings["dankKDEConnect"]?.showOngoingMedia === "true") : true)
    property bool scanSubdirectories: (scanSubdirectoriesVar.value !== undefined && scanSubdirectoriesVar.value !== null) ? (scanSubdirectoriesVar.value === true || scanSubdirectoriesVar.value === "true") : ((SettingsData.pluginSettings["dankKDEConnect"]?.scanSubdirectories !== undefined) ? (SettingsData.pluginSettings["dankKDEConnect"]?.scanSubdirectories === true || SettingsData.pluginSettings["dankKDEConnect"]?.scanSubdirectories === "true") : false)
    property int stateUpdateInterval: (stateUpdateIntervalVar.value !== undefined && stateUpdateIntervalVar.value !== null && stateUpdateIntervalVar.value !== "") ? (parseInt(stateUpdateIntervalVar.value) || 30) : (parseInt(SettingsData.pluginSettings["dankKDEConnect"]?.stateUpdateInterval) || 30)

    readonly property bool isDarkTheme: (Theme.surface.r * 0.299 + Theme.surface.g * 0.587 + Theme.surface.b * 0.114) < 0.5
    readonly property color cardColor: isDarkTheme ? Theme.withAlpha("#ffffff", 0.08) : Theme.withAlpha(Theme.surfaceContainerHigh, 0.6)
    readonly property color cardBorderColor: isDarkTheme ? Theme.withAlpha("#ffffff", 0.12) : Theme.withAlpha(Theme.primary, 0.15)

    ccWidgetIcon: {
        if (!PhoneConnectService.available)
            return "phonelink_off";
        if (hasDevice && selectedDevice.isReachable)
            return "phonelink";
        if (hasDevice && selectedDevice.isReachable)
            return "phonelink";
        return "phonelink_off";
    }
    ccWidgetPrimaryText: serviceName
    ccWidgetSecondaryText: {
        if (!PhoneConnectService.available)
            return I18n.tr("Unavailable", "Phone Connect unavailable status");
        if (!hasDevice)
            return I18n.tr("No devices", "Phone Connect no devices status");
        if (selectedDevice.isReachable) {
            let text = selectedDevice.name;
            if (selectedDevice.batteryCharge >= 0)
                text += " • " + selectedDevice.batteryCharge + "%";
            return text;
        }
        return selectedDevice.name + " (" + I18n.tr("Offline", "Phone Connect offline status") + ")";
    }
    ccWidgetIsActive: hasDevice && selectedDevice?.isReachable
    ccDetailHeight: 460
    popoutWidth: root.showDevicePlaceholder ? (400 + (container1Width - 135)) : 400

    ccDetailContent: Component {
        ScrollView {
            anchors.fill: parent
            clip: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            KDEConnectDetailContent {
                width: parent.width
                selectedDeviceId: root.selectedDeviceId
                customPhoneImage: root.customPhoneImage
                recentImages: root.recentImages
                recentImagesPath: root.recentImagesPath
                pluginRoot: root
                onDeviceSelected: function (deviceId) {
                    root.selectDevice(deviceId);
                }
            }
        }
    }

    onPluginServiceChanged: {
        if (!pluginService)
            return;
        const savedId = pluginService.loadPluginData("dankKDEConnect", "selectedDeviceId", "");
        if (savedId)
            selectedDeviceId = savedId;
    }

    Timer {
        id: autoUpdateTimer
        interval: root.stateUpdateInterval * 1000
        running: root.stateUpdateInterval > 0
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            PhoneConnectService.refreshDevices();
        }
    }

    readonly property bool isTyping: {
        const win = root.Window?.window;
        if (!win || !win.activeFocusItem)
            return false;
        const str = win.activeFocusItem.toString();
        return str.includes("TextInput") || str.includes("TextEdit") || str.includes("TextField") || str.includes("TextArea");
    }

    function switchDeviceNext() {
        const ids = PhoneConnectService.deviceIds;
        if (ids.length <= 1)
            return;
        let idx = ids.indexOf(root.selectedDeviceId);
        idx = (idx + 1) % ids.length;
        root.selectDevice(ids[idx]);
    }

    function switchDevicePrev() {
        const ids = PhoneConnectService.deviceIds;
        if (ids.length <= 1)
            return;
        let idx = ids.indexOf(root.selectedDeviceId);
        idx = (idx - 1 + ids.length) % ids.length;
        root.selectDevice(ids[idx]);
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        onActivated: root.switchDeviceNext()
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        onActivated: root.switchDevicePrev()
    }

    Repeater {
        model: Math.min(PhoneConnectService.deviceIds.length, 9)
        delegate: Item {
            Shortcut {
                sequence: "Alt+" + (index + 1)
                onActivated: {
                    if (index < PhoneConnectService.deviceIds.length) {
                        root.selectDevice(PhoneConnectService.deviceIds[index]);
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "S"
        enabled: !root.isTyping && !root.showShareDialog && !root.showSmsDialog
        onActivated: {
            if (root.selectedDeviceId && root.selectedDevice && root.selectedDevice.isReachable) {
                root.handleAction(root.selectedDeviceId, "share");
            }
        }
    }

    Connections {
        target: PhoneConnectService
        function onDevicesListChanged() {
            const ids = PhoneConnectService.deviceIds;
            if (ids.length === 0) {
                selectDevice("");
            } else if (!selectedDeviceId || !ids.includes(selectedDeviceId)) {
                selectDevice(ids[0]);
            }
        }

        function onPairingRequestReceived(deviceId, verificationKey) {
            const device = PhoneConnectService.getDevice(deviceId);
            const msg = verificationKey ? (I18n.tr("Verification", "Phone Connect pairing verification key label") + ": " + verificationKey) : "";
            ToastService.showInfo(I18n.tr("Pairing request from %1", "Phone Connect pairing request notification").arg(device?.name || deviceId), msg);
        }

        function onShareReceived(deviceId, url) {
            const device = PhoneConnectService.getDevice(deviceId);
            const filename = url.split("/").pop() || url;
            const filePath = url.startsWith("file://") ? url.substring(7) : url;

            Quickshell.execDetached(["dms", "notify", "--app", serviceName, "--icon", "smartphone", "--file", filePath, I18n.tr("File received from %1", "Phone Connect file share notification").arg(device?.name || deviceId), filename]);
        }
    }

    function selectDevice(deviceId) {
        selectedDeviceId = deviceId;
        if (pluginService)
            pluginService.savePluginData("dankKDEConnect", "selectedDeviceId", deviceId);
    }

    function sendClipboardToDevice(deviceId) {
        PhoneConnectService.sendClipboard(deviceId, function (response) {
            if (response.error) {
                ToastService.showError(I18n.tr("Failed to send clipboard", "Phone Connect error"), response.error);
                return;
            }
            ToastService.showInfo(I18n.tr("Clipboard sent", "Phone Connect clipboard action"));
        });
    }

    function handleAction(deviceId, action) {
        const device = PhoneConnectService.getDevice(deviceId);
        const deviceName = device?.name || I18n.tr("device", "Generic device name fallback");
        switch (action) {
        case "ring":
            PhoneConnectService.ringDevice(deviceId, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to ring device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ringing %1...", "Phone Connect ring action").arg(deviceName));
            });
            break;
        case "ping":
            PhoneConnectService.sendPing(deviceId, "", function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to send ping", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ping sent to %1", "Phone Connect ping action").arg(deviceName));
            });
            break;
        case "clipboard":
            root.sendClipboardToDevice(deviceId);
            break;
        case "share":
            showSmsDialog = false;
            if (showShareDialog && shareDeviceId === deviceId) {
                showShareDialog = false;
                shareDeviceId = "";
            } else {
                shareDeviceId = deviceId;
                showShareDialog = true;
            }
            break;
        case "sms":
            showShareDialog = false;
            if (showSmsDialog && shareDeviceId === deviceId) {
                showSmsDialog = false;
                shareDeviceId = "";
            } else {
                shareDeviceId = deviceId;
                showSmsDialog = true;
            }
            break;
        case "browse":
            closePopout();
            PhoneConnectService.startBrowsing(deviceId, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to browse device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Opening file browser", "Phone Connect browse action") + "...");
            });
            break;
        case "pair":
            PhoneConnectService.requestPairing(deviceId, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Pairing failed", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Pairing request sent", "Phone Connect pairing action"));
            });
            break;
        case "acceptPair":
            PhoneConnectService.acceptPairing(deviceId, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to accept pairing", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Device paired", "Phone Connect pairing action"));
            });
            break;
        case "rejectPair":
            PhoneConnectService.cancelPairing(deviceId, function (response) {
                if (response.error)
                    ToastService.showError(I18n.tr("Failed to reject pairing", "Phone Connect error"), response.error);
            });
            break;
        case "unpair":
            PhoneConnectService.unpair(deviceId, function (response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Unpair failed", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Device unpaired", "Phone Connect unpair action"));
            });
            break;
        }
    }

    horizontalBarPill: Component {
        Item {
            id: horizWrapper
            implicitWidth: horizRow.implicitWidth
            implicitHeight: horizRow.implicitHeight
            DropArea {
                id: horizDropArea
                anchors.fill: parent
                anchors.margins: -15

                property bool isDragActive: false

                onEntered: drag => {
                    if (drag.hasUrls && root.hasDevice && root.selectedDevice?.isReachable) {
                        isDragActive = true;
                        drag.accept();
                    } else {
                        isDragActive = false;
                        drag.ignore();
                    }
                }
                onExited: {
                    isDragActive = false;
                }
                onDropped: drop => {
                    isDragActive = false;
                    if (drop.hasUrls && root.hasDevice && root.selectedDevice?.isReachable) {
                        for (let i = 0; i < drop.urls.length; ++i) {
                            PhoneConnectService.shareFile(root.selectedDeviceId, drop.urls[i], function(response) {
                                if (response && response.error) {
                                    ToastService.showError(I18n.tr("Failed to send file", "Phone Connect error"), response.error);
                                } else {
                                    ToastService.showInfo(I18n.tr("Sending file to %1...", "Phone Connect share action").arg(root.selectedDevice?.name || "device"));
                                }
                            });
                        }
                        drop.accept();
                    }
                }
            }

            Item {
                id: hWaveContainer
                readonly property var basePill: {
                    let p = parent;
                    while (p && p.visualWidth === undefined) {
                        p = p.parent;
                    }
                    return p;
                }
                width: basePill ? basePill.visualWidth : 0
                height: basePill ? basePill.visualHeight : 0
                anchors.centerIn: parent
                visible: root.enableChargingAnimation && root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)

                Rectangle {
                    id: hWaveMask
                    anchors.fill: parent
                    radius: (root.barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: hChargeFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * ((root.selectedDevice?.batteryCharge ?? 0) / 100.0)
                    color: {
                        const charge = root.selectedDevice?.batteryCharge ?? 0;
                        if (charge <= 20)
                            return Theme.withAlpha(Theme.error, 0.15);
                        if (charge <= 50)
                            return Theme.withAlpha(Theme.warning, 0.15);
                        return Theme.withAlpha(Theme.success, 0.15);
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: hWaveMask
                }
            }

            Row {
                id: horizRow
                anchors.centerIn: parent
                spacing: (root.barConfig?.noBackground ?? false) ? 1 : 2

                Item {
                    width: phoneIcon.width
                    height: phoneIcon.height
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        id: phoneIcon
                        name: horizDropArea.isDragActive ? "share" : (root.hasDevice && root.selectedDevice.isReachable ? "smartphone" : "phonelink_off")
                        size: Theme.barIconSize(root.barThickness, -4)
                        color: {
                            if (!PhoneConnectService.available)
                                return Theme.widgetIconColor;
                            if (horizDropArea.isDragActive || (root.hasDevice && root.selectedDevice?.isReachable && root.selectedDevice?.batteryCharging))
                                return Theme.primary;
                            return Theme.widgetIconColor;
                        }
                    }

                    DankIcon {
                        visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false) && !horizDropArea.isDragActive
                        name: "bolt"
                        size: phoneIcon.size * 0.45
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -1
                    }
                }

                StyledText {
                    visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharge ?? -1) >= 0
                    text: (root.selectedDevice?.batteryCharge ?? 0) + "%"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: !PhoneConnectService.available
                    text: "N/A"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vertWrapper
            implicitWidth: vertCol.implicitWidth
            implicitHeight: vertCol.implicitHeight
            DropArea {
                id: vertDropArea
                anchors.fill: parent
                anchors.margins: -15

                property bool isDragActive: false

                onEntered: drag => {
                    if (drag.hasUrls && root.hasDevice && root.selectedDevice?.isReachable) {
                        isDragActive = true;
                        drag.accept();
                    } else {
                        isDragActive = false;
                        drag.ignore();
                    }
                }
                onExited: {
                    isDragActive = false;
                }
                onDropped: drop => {
                    isDragActive = false;
                    if (drop.hasUrls && root.hasDevice && root.selectedDevice?.isReachable) {
                        for (let i = 0; i < drop.urls.length; ++i) {
                            PhoneConnectService.shareFile(root.selectedDeviceId, drop.urls[i], function(response) {
                                if (response && response.error) {
                                    ToastService.showError(I18n.tr("Failed to send file", "Phone Connect error"), response.error);
                                } else {
                                    ToastService.showInfo(I18n.tr("Sending file to %1...", "Phone Connect share action").arg(root.selectedDevice?.name || "device"));
                                }
                            });
                        }
                        drop.accept();
                    }
                }
            }

            Item {
                id: vWaveContainer
                readonly property var basePill: {
                    let p = parent;
                    while (p && p.visualWidth === undefined) {
                        p = p.parent;
                    }
                    return p;
                }
                width: basePill ? basePill.visualWidth : 0
                height: basePill ? basePill.visualHeight : 0
                anchors.centerIn: parent
                visible: root.enableChargingAnimation && root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)

                Rectangle {
                    id: vWaveMask
                    anchors.fill: parent
                    radius: (root.barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: vChargeFill
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.height * ((root.selectedDevice?.batteryCharge ?? 0) / 100.0)
                    color: {
                        const charge = root.selectedDevice?.batteryCharge ?? 0;
                        if (charge <= 20)
                            return Theme.withAlpha(Theme.error, 0.15);
                        if (charge <= 50)
                            return Theme.withAlpha(Theme.warning, 0.15);
                        return Theme.withAlpha(Theme.success, 0.15);
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.mediumDuration
                            easing.type: Theme.standardEasing
                        }
                    }
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: vWaveMask
                }
            }

            Column {
                id: vertCol
                anchors.centerIn: parent
                spacing: 1

                Item {
                    width: phoneIconV.width
                    height: phoneIconV.height
                    anchors.horizontalCenter: parent.horizontalCenter

                    DankIcon {
                        id: phoneIconV
                        name: vertDropArea.isDragActive ? "share" : (root.hasDevice && root.selectedDevice.isReachable ? "smartphone" : "phonelink_off")
                        size: Theme.barIconSize(root.barThickness)
                        color: {
                            if (!PhoneConnectService.available)
                                return Theme.widgetIconColor;
                            if (vertDropArea.isDragActive || (root.hasDevice && root.selectedDevice?.isReachable && root.selectedDevice?.batteryCharging))
                                return Theme.primary;
                            return Theme.widgetIconColor;
                        }
                    }

                    DankIcon {
                        visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false) && !vertDropArea.isDragActive
                        name: "bolt"
                        size: phoneIconV.size * 0.45
                        color: Theme.primary
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: -2
                        anchors.bottomMargin: -1
                    }
                }

                StyledText {
                    visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharge ?? -1) >= 0
                    text: (root.selectedDevice?.batteryCharge ?? 0).toString()
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            property bool switcherVisible: false

            Component.onCompleted: root.popoutOpen = true
            Component.onDestruction: root.popoutOpen = false

            // Collapse all device content up into the header on switch, then expand from header for new device
            SequentialAnimation {
                id: deviceChangeAnim

                ScriptAction {
                    script: {
                        root.deviceSwitching = true;
                    }
                }

                // Phase 1: Slide up into header + fade out
                ParallelAnimation {
                    NumberAnimation {
                        target: deviceContentGroup
                        property: "opacity"
                        to: 0
                        duration: Theme.shorterDuration * 0.8
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: deviceContentTranslate
                        property: "y"
                        to: -28
                        duration: Theme.shorterDuration * 0.8
                        easing.type: Easing.InCubic
                    }
                }

                // Swap device while invisible
                ScriptAction {
                    script: {
                        root.activeDeviceId = root.selectedDeviceId;
                    }
                }

                // Reset to below header, ready to slide in
                PropertyAction {
                    target: deviceContentTranslate
                    property: "y"
                    value: 28
                }

                // Phase 2: Slide down into place + fade in
                ParallelAnimation {
                    NumberAnimation {
                        target: deviceContentGroup
                        property: "opacity"
                        to: 1
                        duration: Theme.shorterDuration * 0.9
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: deviceContentTranslate
                        property: "y"
                        to: 0
                        duration: Theme.shorterDuration * 0.9
                        easing.type: Easing.OutCubic
                    }
                }

                ScriptAction {
                    script: {
                        root.deviceSwitching = false;
                    }
                }
            }

            Connections {
                target: root
                function onSelectedDeviceIdChanged() {
                    if (root.activeDeviceId === "") {
                        root.activeDeviceId = root.selectedDeviceId;
                    } else if (root.selectedDeviceId !== root.activeDeviceId) {
                        deviceChangeAnim.restart();
                    }
                }
            }

            showCloseButton: false
            headerText: ""

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                // Header card
                StyledRect {
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 60
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: Theme.spacingM

                        Rectangle {
                            width: 42
                            height: 42
                            radius: 21
                            color: Theme.withAlpha(Theme.primary, 0.2)

                            DankIcon {
                                name: PhoneConnectService.getDeviceIcon(root.activeDevice) || "smartphone"
                                size: 22
                                color: Theme.primary
                                anchors.centerIn: parent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: root.serviceName
                                font.bold: true
                                font.pixelSize: Theme.fontSizeLarge
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: PhoneConnectService.connectedCount + " connected • " + PhoneConnectService.pairedCount + " paired"
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                                opacity: 0.8
                            }
                        }

                        // Grouped Actions Container (for Switch & Refresh buttons)
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS // Gap between switch & refresh buttons
                            visible: true

                            // Switch Device button (only when multiple devices available)
                            Item {
                                id: switcherButton
                                width: 38
                                height: 38
                                visible: PhoneConnectService.deviceIds.length > 1
                                scale: switcherArea.pressed ? 0.92 : (switcherArea.containsMouse ? 1.05 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                MouseArea {
                                    id: switcherArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function (m) {
                                        switcherRipple.trigger(m.x, m.y);
                                    }
                                    onClicked: {
                                        switcherContainer.animateHeight = true;
                                        popout.switcherVisible = !popout.switcherVisible;
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: popout.switcherVisible ? height / 2 : Theme.cornerRadius
                                    bottomLeftRadius: popout.switcherVisible ? height / 2 : Theme.cornerRadius
                                    topRightRadius: popout.switcherVisible ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    bottomRightRadius: popout.switcherVisible ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)

                                    color: popout.switcherVisible ? Theme.withAlpha(Theme.secondary, 0.2) : (switcherArea.containsMouse ? Theme.withAlpha(Theme.secondary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4))
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.secondary, popout.switcherVisible || switcherArea.containsMouse ? 0.4 : 0.15)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.popoutAnimationDuration
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.popoutAnimationDuration
                                        }
                                    }
                                    Behavior on topLeftRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on bottomLeftRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on topRightRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on bottomRightRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                DankRipple {
                                    id: switcherRipple
                                    anchors.fill: parent
                                    cornerRadius: popout.switcherVisible ? width / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    rippleColor: Theme.secondary
                                }

                                DankIcon {
                                    name: "swap_horiz"
                                    size: 20
                                    color: Theme.secondary
                                    anchors.centerIn: parent
                                    rotation: popout.switcherVisible ? 180 : 0

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                            }

                            Item {
                                id: refreshButton
                                width: 38
                                height: 38
                                scale: refreshArea.pressed ? 0.92 : (refreshArea.containsMouse ? 1.05 : 1.0)

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                MouseArea {
                                    id: refreshArea
                                    anchors.fill: parent
                                    hoverEnabled: !PhoneConnectService.isRefreshing
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function (m) {
                                        refreshRipple.trigger(m.x, m.y);
                                    }
                                    onClicked: PhoneConnectService.refreshDevices()
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: PhoneConnectService.isRefreshing ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    bottomLeftRadius: PhoneConnectService.isRefreshing ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    topRightRadius: PhoneConnectService.isRefreshing ? height / 2 : Theme.cornerRadius
                                    bottomRightRadius: PhoneConnectService.isRefreshing ? height / 2 : Theme.cornerRadius

                                    color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.primary, refreshArea.containsMouse ? 0.3 : 0.15)

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Theme.popoutAnimationDuration
                                        }
                                    }
                                    Behavior on border.color {
                                        ColorAnimation {
                                            duration: Theme.popoutAnimationDuration
                                        }
                                    }
                                    Behavior on topLeftRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on bottomLeftRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on topRightRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on bottomRightRadius {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                DankRipple {
                                    id: refreshRipple
                                    anchors.fill: parent
                                    cornerRadius: PhoneConnectService.isRefreshing ? width / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    rippleColor: Theme.primary
                                }

                                DankIcon {
                                    name: "refresh"
                                    size: 20
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                    smoothTransform: true
                                    visible: !PhoneConnectService.isRefreshing
                                    rotation: refreshArea.containsMouse ? 180 : 0

                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: Theme.popoutAnimationDuration
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }

                                DankSpinner {
                                    anchors.centerIn: parent
                                    size: 18
                                    color: Theme.primary
                                    visible: PhoneConnectService.isRefreshing
                                }
                            }
                        }
                    }
                }

                // Device Switcher Container
                StyledRect {
                    id: switcherContainer
                    width: parent.width
                    clip: true

                    property bool animateHeight: false
                    readonly property bool shouldBeVisible: (!root.hasDevice || popout.switcherVisible) && PhoneConnectService.deviceIds.length > 0

                    height: shouldBeVisible ? (switcherLayout.implicitHeight + Theme.spacingM * 2) : 0
                    opacity: shouldBeVisible ? 1.0 : 0.0
                    visible: height > 0

                    Behavior on height {
                        enabled: switcherContainer.animateHeight
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        enabled: switcherContainer.animateHeight
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    Column {
                        id: switcherLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Repeater {
                            model: PhoneConnectService.deviceIds
                            delegate: DeviceCard {
                                required property string modelData
                                required property int index
                                width: parent.width
                                deviceId: modelData
                                device: PhoneConnectService.getDevice(modelData)
                                selectable: true
                                isSelected: root.selectedDeviceId === modelData
                                isFirst: index === 0
                                isLast: index === PhoneConnectService.deviceIds.length - 1
                                onClicked: {
                                    switcherContainer.animateHeight = true;
                                    root.selectDevice(modelData);
                                    popout.switcherVisible = false;
                                }
                                onAction: function (action) {
                                    root.handleAction(modelData, action);
                                }
                            }
                        }
                    }
                }

                UnavailableMessage {
                    visible: !PhoneConnectService.available
                    width: parent.width
                }

                EmptyState {
                    visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length === 0
                    width: parent.width
                }

                // ── Animatable device content group ──────────────────────────
                // All per-device cards (image, info, share, sms, recent images)
                // slide as one unit: up into header on exit, down from header on enter.
                Item {
                    id: deviceContentGroup
                    width: parent.width
                    // height wraps children; the Column parent handles spacing
                    implicitHeight: deviceContentCol.implicitHeight
                    height: implicitHeight
                    clip: true

                    transform: Translate {
                        id: deviceContentTranslate
                        y: 0
                    }

                    Column {
                        id: deviceContentCol
                        width: parent.width
                        spacing: Theme.spacingM

                        // Main Container
                        RowLayout {
                            id: mainDeviceContainerRow
                            width: parent.width
                            height: {
                                if (!root.showDevicePlaceholder) {
                                    return mainInfoColumn.implicitHeight + Theme.spacingM * 2;
                                }
                                const type = root.activeDevice?.type;
                                if (type === "desktop" || type === "computer" || type === "laptop" || type === "tablet" || type === "tv") {
                                    return Math.max(mainInfoColumn.implicitHeight + Theme.spacingM * 2, 160);
                                }
                                return 245;
                            }
                            spacing: Theme.spacingM
                            visible: root.hasDevice

                            // Container 1: Device Image
                            StyledRect {
                                visible: root.showDevicePlaceholder
                                Layout.preferredWidth: root.container1Width
                                Layout.fillHeight: true
                                radius: Theme.cornerRadius
                                color: root.cardColor
                                border.width: 1
                                border.color: root.cardBorderColor

                                PhoneDisplay {
                                    id: mainPhoneDisplay
                                    anchors.centerIn: parent
                                    height: parent.height - 10
                                    backgroundImage: root.activeCustomPhoneImage
                                    isReachable: root.activeDevice?.isReachable ?? false
                                    deviceType: root.activeDevice?.type ?? "phone"
                                    deviceName: root.activeDevice?.name ?? ""
                                    onClicked: root.handleAction(root.activeDeviceId, "ping")
                                }
                            }

                            // Container 2: Phone Name & Status
                            StyledRect {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 160
                                Layout.fillHeight: root.showDevicePlaceholder
                                Layout.preferredHeight: root.showDevicePlaceholder ? -1 : (mainInfoColumn.implicitHeight + Theme.spacingM * 2)
                                radius: Theme.cornerRadius
                                color: root.cardColor
                                border.width: 1
                                border.color: root.cardBorderColor

                                ColumnLayout {
                                    id: mainInfoColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: root.showDevicePlaceholder ? parent.bottom : undefined
                                    anchors.margins: Theme.spacingM
                                    spacing: Theme.spacingM

                                    // Top Group: Device Name & Actions (Centered)
                                    ColumnLayout {
                                        spacing: Theme.spacingXXS
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter

                                        StyledText {
                                            text: root.activeDevice?.name || ""
                                            font.pixelSize: Theme.fontSizeLarge
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        RowLayout {
                                            spacing: Theme.spacingS
                                            Layout.alignment: Qt.AlignHCenter

                                            Item {
                                                width: 32
                                                height: 32
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "findmyphone")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "phone_in_talk"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "ring");
                                                    }
                                                }
                                            }

                                            Item {
                                                width: 32
                                                height: 32
                                                visible: !root.showDevicePlaceholder
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "ping")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "notifications_active"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("Ping", "KDE Connect ping tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "ping");
                                                    }
                                                }
                                            }

                                            Item {
                                                width: 32
                                                height: 32
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "folder"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "browse");
                                                    }
                                                }
                                            }

                                            Item {
                                                width: 32
                                                height: 32
                                                visible: root.enableClipboardAction
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "clipboard")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "content_paste"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("Send Clipboard", "KDE Connect send clipboard tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "clipboard");
                                                    }
                                                }
                                            }

                                            Item {
                                                width: 32
                                                height: 32
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "share")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "share"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "share");
                                                    }
                                                }
                                            }

                                            Item {
                                                width: 32
                                                height: 32
                                                enabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "sms")
                                                DankKDEActionButton {
                                                    anchors.fill: parent
                                                    enabled: parent.enabled
                                                    iconName: "sms"
                                                    iconColor: Theme.primary
                                                    buttonSize: 32
                                                    tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                                                    onClicked: {
                                                        if (!enabled)
                                                            return;
                                                        root.handleAction(root.activeDeviceId, "sms");
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Bottom Group: Info Rows (Dynamic 1 or 2 Columns)
                                    GridLayout {
                                        Layout.fillWidth: true
                                        columnSpacing: Theme.spacingL
                                        rowSpacing: Theme.spacingS
                                        columns: root.showDevicePlaceholder ? 1 : 2

                                        InfoRow {
                                            visible: root.activeDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "battery") && (root.activeDevice?.batteryCharge ?? -1) >= 0
                                            icon: PhoneConnectService.getBatteryIcon(root.activeDevice)
                                            label: I18n.tr("Battery", "KDE Connect battery label")
                                            value: (root.activeDevice?.batteryCharge ?? -1) >= 0 ? (root.activeDevice.batteryCharge + "%") : I18n.tr("Unknown", "Status")
                                            valueColor: root.activeDevice?.batteryCharging ? Theme.primary : Theme.surfaceText
                                        }

                                        InfoRow {
                                            visible: root.activeDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "connectivity_report") && (root.activeDevice?.networkStrength ?? -1) >= 0
                                            icon: PhoneConnectService.getNetworkIcon(root.activeDevice) || "signal_cellular_null"
                                            label: I18n.tr("Signal Strength", "KDE Connect signal strength label")
                                            value: I18n.tr(PhoneConnectService.getNetworkStrengthLabel(root.activeDevice), "Network signal strength status")
                                        }

                                        InfoRow {
                                            visible: root.activeDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "connectivity_report") && root.activeDevice?.networkType
                                            icon: PhoneConnectService.getNetworkTypeIcon(root.activeDevice)
                                            label: I18n.tr("Network Type", "KDE Connect network type label")
                                            value: PhoneConnectService.getNetworkTypeLabel(root.activeDevice)
                                        }

                                        InfoRow {
                                            icon: "sms"
                                            label: I18n.tr("Notifications", "KDE Connect notifications label")
                                            value: root.activeDevice?.notificationCount ?? 0
                                        }
                                    }
                                }
                            }
                        }

                        ShareDialog {
                            id: popoutShareDialog
                            isOpen: root.showShareDialog
                            width: parent.width
                            deviceId: root.shareDeviceId
                            parentPopout: popout.parentPopout
                            onClose: root.showShareDialog = false
                            onShare: function (content, isUri) {
                                if (isUri) {
                                    PhoneConnectService.shareUrl(root.shareDeviceId, content, function (response) {
                                        if (response.error) {
                                            ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                            return;
                                        }
                                        ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                                    });
                                } else {
                                    PhoneConnectService.shareText(root.shareDeviceId, content, function (response) {
                                        if (response.error) {
                                            ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                            return;
                                        }
                                        ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                                    });
                                }
                                root.showShareDialog = false;
                            }
                            onShareFile: function (path) {
                                PhoneConnectService.shareFile(root.shareDeviceId, path, function (response) {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to send file", "Phone Connect error"), response.error);
                                        return;
                                    }
                                    const filename = path.split("/").pop();
                                    ToastService.showInfo(I18n.tr("Sending %1...", "Phone Connect file send").arg(filename));
                                });
                                root.showShareDialog = false;
                            }
                        }

                        SmsDialog {
                            id: popoutSmsDialog
                            isOpen: root.showSmsDialog && root.shareDeviceId === root.selectedDeviceId
                            width: parent.width
                            deviceId: root.shareDeviceId
                            onClose: root.showSmsDialog = false
                            onSendSms: function (phoneNumber, message) {
                                PhoneConnectService.sendSms(root.shareDeviceId, phoneNumber, message, [], function (response) {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to send SMS", "Phone Connect error"), response.error);
                                        return;
                                    }
                                    ToastService.showInfo(I18n.tr("SMS sent successfully", "Phone Connect SMS action"));
                                });
                                root.showSmsDialog = false;
                            }
                            onLaunchApp: {
                                PhoneConnectService.launchSmsApp(root.shareDeviceId, function (response) {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to launch SMS app", "Phone Connect error"), response.error);
                                        return;
                                    }
                                    ToastService.showInfo(I18n.tr("Opening SMS app", "Phone Connect SMS action") + "...");
                                });
                                root.showSmsDialog = false;
                            }
                        }

                        // Ongoing Media Section
                        StyledRect {
                            id: mprisContainer
                            width: parent.width
                            height: mprisMainLayout.implicitHeight + Theme.spacingM * 4
                            visible: root.hasOngoingMediaActive
                            radius: Theme.cornerRadius
                            color: root.cardColor
                            border.width: 1
                            border.color: root.cardBorderColor
                            clip: true

                            Timer {
                                interval: 1000
                                running: (root.phoneMprisPlayer ? (root.phoneMprisPlayer.playbackState === MprisPlaybackState.Playing) : (root.activeDevice?.mediaIsPlaying ?? false)) && !root.isSeeking
                                repeat: true
                                onTriggered: {
                                    if (root.phoneMprisPlayer) {
                                        root.phoneMprisPlayer.positionChanged();
                                    }
                                }
                            }

                            ColumnLayout {
                                id: mprisMainLayout
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM
                                z: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingXS

                                    Item {
                                        width: 16
                                        height: 16

                                        property string serviceIdStr: (root.phoneMprisPlayer && root.phoneMprisPlayer.identity) ? root.phoneMprisPlayer.identity.toLowerCase() : ""
                                        property string serviceIconSvg: {
                                            if (serviceIdStr.includes("spotify"))
                                                return "assets/icons/spotify.svg";
                                            if (serviceIdStr.includes("youtube"))
                                                return "assets/icons/youtube.svg";
                                            if (serviceIdStr.includes("soundcloud"))
                                                return "assets/icons/soundcloud.svg";
                                            if (serviceIdStr.includes("apple"))
                                                return "assets/icons/applemusic.svg";
                                            return "";
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "music_note"
                                            size: 16
                                            color: Theme.primary
                                            visible: parent.serviceIconSvg === ""
                                        }

                                        Image {
                                            id: svcIconImage
                                            anchors.fill: parent
                                            source: parent.serviceIconSvg !== "" ? Qt.resolvedUrl(parent.serviceIconSvg) : ""
                                            sourceSize: Qt.size(16, 16)
                                            visible: false
                                        }

                                        Rectangle {
                                            id: svcIconColorRect
                                            anchors.fill: parent
                                            color: Theme.primary
                                            visible: false
                                        }

                                        MultiEffect {
                                            anchors.fill: parent
                                            source: svcIconColorRect
                                            maskEnabled: true
                                            maskSource: svcIconImage
                                            visible: parent.serviceIconSvg !== ""
                                        }
                                    }

                                    StyledText {
                                        text: {
                                            if (root.phoneMprisPlayer && root.phoneMprisPlayer.identity) {
                                                return root.phoneMprisPlayer.identity.split(" - ")[0];
                                            }
                                            return root.activeDevice?.mediaPlayer || I18n.tr("Media Player");
                                        }
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    DankKDEActionButton {
                                        iconName: "speaker"
                                        iconColor: Theme.surfaceText
                                        buttonSize: 24
                                        tooltipText: I18n.tr("Audio Output")
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingM

                                    Rectangle {
                                        id: smallThumbnailContainer
                                        width: 72
                                        height: 72
                                        radius: 36
                                        color: Theme.withAlpha(Theme.surfaceContainerHighest || "#000000", 0.4)
                                        border.color: Theme.withAlpha(Theme.primary, 0.2)
                                        border.width: 1
                                        clip: true

                                        property string activeArtUrl: root.phoneMprisPlayer ? TrackArtService.getArtworkUrl(root.phoneMprisPlayer) : ""

                                        DankCircularImage {
                                            id: albumArt
                                            anchors.fill: parent
                                            imageSource: smallThumbnailContainer.activeArtUrl
                                            fallbackIcon: "album"
                                            visible: smallThumbnailContainer.activeArtUrl !== ""
                                        }

                                        DankIcon {
                                            anchors.centerIn: parent
                                            name: "music_note"
                                            size: 32
                                            color: Theme.surfaceText
                                            visible: !albumArt.visible
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        StyledText {
                                            text: root.phoneMprisPlayer ? (root.phoneMprisPlayer.trackTitle || "Unknown Track") : (root.activeDevice?.mediaTitle || "Unknown Track")
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            color: Theme.surfaceText
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            text: {
                                                if (root.phoneMprisPlayer) {
                                                    let artist = root.phoneMprisPlayer.trackArtist || "";
                                                    let album = root.phoneMprisPlayer.trackAlbum || "";
                                                    if (artist && album)
                                                        return artist + " — " + album;
                                                    return artist || album || I18n.tr("Unknown Artist");
                                                } else {
                                                    let artist = root.activeDevice?.mediaArtist || "";
                                                    let album = root.activeDevice?.mediaAlbum || "";
                                                    if (artist && album)
                                                        return artist + " — " + album;
                                                    return artist || album || I18n.tr("Unknown Artist");
                                                }
                                            }
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    DankKDEActionButton {
                                        iconName: (root.phoneMprisPlayer ? (root.phoneMprisPlayer.playbackState === MprisPlaybackState.Playing) : (root.activeDevice?.mediaIsPlaying ?? false)) ? "pause" : "play_arrow"
                                        iconColor: Theme.primary
                                        backgroundColor: Theme.withAlpha(Theme.primary, 0.1)
                                        buttonSize: 48
                                        iconSize: 28
                                        tooltipText: iconName === "pause" ? I18n.tr("Pause", "Media pause tooltip") : I18n.tr("Play", "Media play tooltip")
                                        onClicked: {
                                            if (root.phoneMprisPlayer) {
                                                if (root.phoneMprisPlayer.playbackState === MprisPlaybackState.Playing) {
                                                    root.phoneMprisPlayer.pause();
                                                } else {
                                                    root.phoneMprisPlayer.play();
                                                }
                                            } else {
                                                PhoneConnectService.mprisAction(root.activeDeviceId, "PlayPause", function () {});
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.spacingS

                                    DankKDEActionButton {
                                        iconName: "skip_previous"
                                        iconColor: Theme.surfaceText
                                        buttonSize: 28
                                        tooltipText: I18n.tr("Previous", "Media previous tooltip")
                                        onClicked: root.phoneMprisPlayer ? root.phoneMprisPlayer.previous() : PhoneConnectService.mprisAction(root.activeDeviceId, "previous", function () {})
                                    }

                                    DankKDEActionButton {
                                        iconName: "replay_10"
                                        iconColor: Theme.surfaceText
                                        buttonSize: 28
                                        tooltipText: I18n.tr("Rewind 10s", "Media rewind tooltip")
                                        onClicked: {
                                            if (root.phoneMprisPlayer && root.phoneMprisPlayer.canSeek) {
                                                root.phoneMprisPlayer.position = Math.max(0, (root.phoneMprisPlayer.position || 0) - 10);
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.spacingXXS
                                        visible: root.phoneMprisPlayer !== null && root.phoneMprisPlayer.length > 0

                                        Item {
                                            id: customSeekbar
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16

                                            readonly property real stableLength: root.phoneMprisPlayer ? Math.max(1, root.phoneMprisPlayer.length) : 1
                                            readonly property real playerValue: {
                                                if (!root.phoneMprisPlayer || stableLength <= 0)
                                                    return 0;
                                                return Math.max(0, Math.min(1, (root.phoneMprisPlayer.position || 0) / stableLength));
                                            }

                                            property real seekPreviewRatio: -1
                                            property real value: seekPreviewRatio >= 0 ? seekPreviewRatio : playerValue

                                            Loader {
                                                anchors.fill: parent
                                                asynchronous: true
                                                visible: root.phoneMprisPlayer && stableLength > 0
                                                sourceComponent: SettingsData.waveProgressEnabled ? waveComponent : flatComponent

                                                Component {
                                                    id: waveComponent
                                                    M3WaveProgress {
                                                        value: customSeekbar.value
                                                        actualValue: customSeekbar.playerValue
                                                        showActualPlaybackState: root.isSeeking
                                                        actualProgressColor: Theme.withAlpha(Theme.surfaceText, 0.45)
                                                        isPlaying: root.phoneMprisPlayer && root.phoneMprisPlayer.playbackState === MprisPlaybackState.Playing

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            enabled: root.phoneMprisPlayer && root.phoneMprisPlayer.canSeek && customSeekbar.stableLength > 0

                                                            onPressed: mouse => {
                                                                root.isSeeking = true;
                                                                customSeekbar.seekPreviewRatio = Math.max(0, Math.min(1, mouse.x / width));
                                                            }
                                                            onPositionChanged: mouse => {
                                                                if (pressed && root.isSeeking) {
                                                                    customSeekbar.seekPreviewRatio = Math.max(0, Math.min(1, mouse.x / width));
                                                                }
                                                            }
                                                            onReleased: {
                                                                root.isSeeking = false;
                                                                if (customSeekbar.seekPreviewRatio >= 0 && root.phoneMprisPlayer) {
                                                                    root.phoneMprisPlayer.position = Math.max(0.1, customSeekbar.seekPreviewRatio * customSeekbar.stableLength);
                                                                }
                                                                customSeekbar.seekPreviewRatio = -1;
                                                            }
                                                            onCanceled: {
                                                                root.isSeeking = false;
                                                                customSeekbar.seekPreviewRatio = -1;
                                                            }
                                                        }
                                                    }
                                                }

                                                Component {
                                                    id: flatComponent
                                                    Item {
                                                        Rectangle {
                                                            width: parent.width
                                                            height: 4
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: Theme.withAlpha(Theme.surfaceText, 0.15)
                                                            radius: 2
                                                        }
                                                        Rectangle {
                                                            width: Math.max(0, Math.min(parent.width, parent.width * customSeekbar.value))
                                                            height: 4
                                                            anchors.left: parent.left
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            color: Theme.primary
                                                            radius: 2
                                                        }
                                                        Rectangle {
                                                            x: Math.max(0, Math.min(parent.width - width, parent.width * customSeekbar.value - width / 2))
                                                            width: 10
                                                            height: 10
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            radius: 5
                                                            color: Theme.primary
                                                            visible: flatMouseArea.containsMouse || flatMouseArea.pressed
                                                        }
                                                        MouseArea {
                                                            id: flatMouseArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            enabled: root.phoneMprisPlayer && root.phoneMprisPlayer.canSeek && customSeekbar.stableLength > 0

                                                            onPressed: mouse => {
                                                                root.isSeeking = true;
                                                                customSeekbar.seekPreviewRatio = Math.max(0, Math.min(1, mouse.x / width));
                                                            }
                                                            onPositionChanged: mouse => {
                                                                if (pressed && root.isSeeking) {
                                                                    customSeekbar.seekPreviewRatio = Math.max(0, Math.min(1, mouse.x / width));
                                                                }
                                                            }
                                                            onReleased: {
                                                                root.isSeeking = false;
                                                                if (customSeekbar.seekPreviewRatio >= 0 && root.phoneMprisPlayer) {
                                                                    root.phoneMprisPlayer.position = Math.max(0.1, customSeekbar.seekPreviewRatio * customSeekbar.stableLength);
                                                                }
                                                                customSeekbar.seekPreviewRatio = -1;
                                                            }
                                                            onCanceled: {
                                                                root.isSeeking = false;
                                                                customSeekbar.seekPreviewRatio = -1;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            StyledText {
                                                text: {
                                                    if (!root.phoneMprisPlayer)
                                                        return "0:00";
                                                    const seconds = root.phoneMprisPlayer.position || 0;
                                                    const minutes = Math.floor(seconds / 60);
                                                    const secs = Math.floor(seconds % 60);
                                                    return minutes + ":" + (secs < 10 ? "0" : "") + secs;
                                                }
                                                font.pixelSize: Theme.fontSizeSmall * 0.8
                                                color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            StyledText {
                                                text: {
                                                    if (!root.phoneMprisPlayer || !root.phoneMprisPlayer.length)
                                                        return "0:00";
                                                    const seconds = root.phoneMprisPlayer.length;
                                                    const minutes = Math.floor(seconds / 60);
                                                    const secs = Math.floor(seconds % 60);
                                                    return minutes + ":" + (secs < 10 ? "0" : "") + secs;
                                                }
                                                font.pixelSize: Theme.fontSizeSmall * 0.8
                                                color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                            }
                                        }
                                    }

                                    DankKDEActionButton {
                                        iconName: "forward_10"
                                        iconColor: Theme.surfaceText
                                        buttonSize: 28
                                        tooltipText: I18n.tr("Forward 10s", "Media forward tooltip")
                                        onClicked: {
                                            if (root.phoneMprisPlayer && root.phoneMprisPlayer.canSeek) {
                                                root.phoneMprisPlayer.position = Math.min(root.phoneMprisPlayer.length, (root.phoneMprisPlayer.position || 0) + 10);
                                            }
                                        }
                                    }

                                    DankKDEActionButton {
                                        iconName: "skip_next"
                                        iconColor: Theme.surfaceText
                                        buttonSize: 28
                                        tooltipText: I18n.tr("Next", "Media next tooltip")
                                        onClicked: root.phoneMprisPlayer ? root.phoneMprisPlayer.next() : PhoneConnectService.mprisAction(root.activeDeviceId, "next", function () {})
                                    }
                                }
                            }
                        }

                        // Recent Images Section
                        StyledRect {
                            id: recentImagesContainer
                            width: parent.width
                            height: recentImagesCol.implicitHeight + Theme.spacingM * 2
                            visible: root.hasDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp") && root.recentImagesPath !== "" && !root.deviceSwitching
                            radius: Theme.cornerRadius
                            color: root.cardColor
                            border.width: 1
                            border.color: root.cardBorderColor

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.shorterDuration
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Column {
                                id: recentImagesCol
                                width: Math.max(0, parent.width - Theme.spacingM * 2)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    spacing: Theme.spacingXS
                                    width: parent.width

                                    DankIcon {
                                        name: "image"
                                        size: 16
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: I18n.tr("Recent Images", "Recent Images title")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                        Layout.fillWidth: true
                                    }
                                }

                                // Skeleton Loading State (global — only while scanner hasn't returned any results yet)
                                Flow {
                                    id: skeletonGrid
                                    visible: root.loadingImages && root.recentImages.length === 0
                                    width: parent.width
                                    spacing: Theme.spacingXS

                                    property int columns: (() => {
                                            let count = root.maxRecentImages;
                                            if (count <= 0)
                                                return 0;
                                            if (count <= 2)
                                                return count;
                                            return Math.ceil(count / 2);
                                        })()

                                    property int itemWidth: (width - (columns > 1 ? (columns - 1) * spacing : 0)) / Math.max(1, columns)
                                    property int itemHeight: root.maxRecentImages <= 2 ? Math.min(160, itemWidth * 0.625) : 72

                                    Repeater {
                                        model: root.maxRecentImages
                                        Rectangle {
                                            property bool isOddLayout: root.maxRecentImages % 2 === 1 && root.maxRecentImages > 1
                                            property bool isSpan2: isOddLayout && index === 0

                                            width: isSpan2 ? (skeletonGrid.itemWidth * 2 + skeletonGrid.spacing) : skeletonGrid.itemWidth
                                            height: skeletonGrid.itemHeight
                                            radius: 6
                                            color: Theme.withAlpha(Theme.surfaceVariantText, 0.15)
                                            border.width: 1
                                            border.color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

                                            DankIcon {
                                                name: "image"
                                                size: 20
                                                color: Theme.withAlpha(Theme.surfaceVariantText, 0.25)
                                                anchors.centerIn: parent
                                            }
                                        }
                                    }

                                    SequentialAnimation on opacity {
                                        running: skeletonGrid.visible
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            to: 0.3
                                            duration: 800
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            to: 1.0
                                            duration: 800
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                // Empty / No Images Found State
                                Column {
                                    visible: !root.loadingImages && root.recentImages.length === 0
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    bottomPadding: Theme.spacingM
                                    topPadding: Theme.spacingM

                                    DankIcon {
                                        name: "image_not_supported"
                                        size: 32
                                        color: Theme.withAlpha(Theme.surfaceText, 0.4)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }

                                    StyledText {
                                        text: I18n.tr("No images found", "No recent images found message")
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                Flow {
                                    id: imagesGrid
                                    visible: root.recentImages.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingXS
                                    property int columns: (() => {
                                            let count = root.recentImages.length;
                                            if (count <= 0)
                                                return 0;
                                            if (count <= 2)
                                                return count;
                                            return Math.ceil(count / 2);
                                        })()

                                    property int itemWidth: (width - (columns > 1 ? (columns - 1) * spacing : 0)) / Math.max(1, columns)
                                    property int itemHeight: root.recentImages.length <= 2 ? Math.min(160, itemWidth * 0.625) : 72

                                    Repeater {
                                        model: root.recentImages

                                        Item {
                                            id: imageItem
                                            property bool isOddLayout: root.recentImages.length % 2 === 1 && root.recentImages.length > 1
                                            property bool isSpan2: isOddLayout && index === 0

                                            width: isSpan2 ? (imagesGrid.itemWidth * 2 + imagesGrid.spacing) : imagesGrid.itemWidth
                                            height: imagesGrid.itemHeight
                                            property bool isDragging: false
                                            property bool hovered: imageMouseArea.containsMouse || sendBtnMa.containsMouse

                                            // Dynamic Corner Logic
                                            property real innerRadius: 6
                                            property real outerRadius: 12

                                            property int virtualIndex: isOddLayout ? (index === 0 ? 0 : index + 1) : index

                                            property bool isFirstRow: virtualIndex < Math.max(1, imagesGrid.columns)
                                            property bool isLastRow: (() => {
                                                    let totalVirtual = isOddLayout ? root.recentImages.length + 1 : root.recentImages.length;
                                                    let cols = Math.max(1, imagesGrid.columns);
                                                    return virtualIndex >= (Math.floor((totalVirtual - 1) / cols) * cols);
                                                })()
                                            property bool isLeftCol: virtualIndex % Math.max(1, imagesGrid.columns) === 0
                                            property bool isRightCol: (() => {
                                                    let cols = Math.max(1, imagesGrid.columns);
                                                    let endVirtual = isSpan2 ? 1 : virtualIndex;
                                                    let totalVirtual = isOddLayout ? root.recentImages.length + 1 : root.recentImages.length;
                                                    return (endVirtual % cols) === (cols - 1) || virtualIndex === (totalVirtual - 1);
                                                })()

                                            property real tlr: (isFirstRow && isLeftCol) ? outerRadius : innerRadius
                                            property real trr: (isFirstRow && isRightCol) ? outerRadius : innerRadius
                                            property real blr: (isLastRow && isLeftCol) ? outerRadius : innerRadius
                                            property real brr: (isLastRow && isRightCol) ? outerRadius : innerRadius

                                            opacity: isDragging ? 0.45 : 1.0
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }

                                            MouseArea {
                                                id: imageMouseArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                property real pressX: 0
                                                property real pressY: 0
                                                property bool dragLaunched: false

                                                onPressed: function (m) {
                                                    pressX = m.x;
                                                    pressY = m.y;
                                                    dragLaunched = false;
                                                    imageRipple.trigger(m.x, m.y);
                                                }

                                                onPositionChanged: function (m) {
                                                    if (!dragLaunched && pressed) {
                                                        let dx = m.x - pressX;
                                                        let dy = m.y - pressY;
                                                        if (Math.sqrt(dx * dx + dy * dy) > 12) {
                                                            dragLaunched = true;
                                                            imageItem.isDragging = true;
                                                            root.startSystemDrag(modelData.path);
                                                            root.closePopout();
                                                        }
                                                    }
                                                }

                                                onReleased: {
                                                    imageItem.isDragging = false;
                                                    dragLaunched = false;
                                                }

                                                onClicked: {
                                                    if (!dragLaunched) {
                                                        Quickshell.execDetached(["xdg-open", modelData.path]);
                                                        root.closePopout();
                                                    }
                                                }
                                            }

                                            // Mask for the Image
                                            Shape {
                                                id: imageMask
                                                anchors.fill: parent
                                                visible: false
                                                layer.enabled: true

                                                ShapePath {
                                                    fillColor: "black"
                                                    strokeColor: "transparent"

                                                    startX: imageItem.tlr
                                                    startY: 0

                                                    PathLine {
                                                        x: imageMask.width - imageItem.trr
                                                        y: 0
                                                    }
                                                    PathArc {
                                                        x: imageMask.width
                                                        y: imageItem.trr
                                                        radiusX: imageItem.trr
                                                        radiusY: imageItem.trr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: imageMask.width
                                                        y: imageMask.height - imageItem.brr
                                                    }
                                                    PathArc {
                                                        x: imageMask.width - imageItem.brr
                                                        y: imageMask.height
                                                        radiusX: imageItem.brr
                                                        radiusY: imageItem.brr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: imageItem.blr
                                                        y: imageMask.height
                                                    }
                                                    PathArc {
                                                        x: 0
                                                        y: imageMask.height - imageItem.blr
                                                        radiusX: imageItem.blr
                                                        radiusY: imageItem.blr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: 0
                                                        y: imageItem.tlr
                                                    }
                                                    PathArc {
                                                        x: imageItem.tlr
                                                        y: 0
                                                        radiusX: imageItem.tlr
                                                        radiusY: imageItem.tlr
                                                        direction: PathArc.Clockwise
                                                    }
                                                }
                                            }

                                            Item {
                                                id: imageThumbCont
                                                anchors.fill: parent
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskSource: imageMask
                                                }

                                                // Per-cell skeleton shimmer — visible until this specific image decodes
                                                Rectangle {
                                                    id: cellSkeleton
                                                    anchors.fill: parent
                                                    color: Theme.withAlpha(Theme.surfaceVariantText, 0.15)
                                                    radius: imageItem.innerRadius
                                                    border.width: 1
                                                    border.color: Theme.withAlpha(Theme.surfaceVariantText, 0.08)

                                                    property real pulseValue: 1.0
                                                    opacity: (thumbImage.status === Image.Ready) ? 0.0 : pulseValue
                                                    visible: opacity > 0.0
                                                    z: 2

                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 250
                                                            easing.type: Easing.OutQuad
                                                        }
                                                    }

                                                    SequentialAnimation on pulseValue {
                                                        loops: Animation.Infinite
                                                        running: thumbImage.status !== Image.Ready
                                                        NumberAnimation {
                                                            to: 0.35
                                                            duration: 850
                                                            easing.type: Easing.InOutQuad
                                                        }
                                                        NumberAnimation {
                                                            to: 1.0
                                                            duration: 850
                                                            easing.type: Easing.InOutQuad
                                                        }
                                                    }

                                                    DankIcon {
                                                        name: "image"
                                                        size: 20
                                                        color: Theme.withAlpha(Theme.surfaceVariantText, 0.25)
                                                        anchors.centerIn: parent
                                                    }
                                                }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: Theme.surfaceContainer
                                                }
                                                Image {
                                                    id: thumbImage
                                                    anchors.fill: parent
                                                    source: "file://" + modelData.path
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    mipmap: true
                                                    cache: true
                                                }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: Theme.primary
                                                    opacity: imageMouseArea.containsMouse ? 0.10 : 0
                                                    Behavior on opacity {
                                                        NumberAnimation {
                                                            duration: 150
                                                        }
                                                    }
                                                }
                                            }

                                            // Border and Shadow Canvas
                                            Shape {
                                                id: imageBorder
                                                anchors.fill: parent
                                                property color borderColor: imageMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.40) : Theme.withAlpha(Theme.secondary, 0.15)

                                                ShapePath {
                                                    fillColor: "transparent"
                                                    strokeColor: imageBorder.borderColor
                                                    strokeWidth: 1.5

                                                    startX: imageItem.tlr
                                                    startY: 0

                                                    PathLine {
                                                        x: imageBorder.width - imageItem.trr
                                                        y: 0
                                                    }
                                                    PathArc {
                                                        x: imageBorder.width
                                                        y: imageItem.trr
                                                        radiusX: imageItem.trr
                                                        radiusY: imageItem.trr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: imageBorder.width
                                                        y: imageBorder.height - imageItem.brr
                                                    }
                                                    PathArc {
                                                        x: imageBorder.width - imageItem.brr
                                                        y: imageBorder.height
                                                        radiusX: imageItem.brr
                                                        radiusY: imageItem.brr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: imageItem.blr
                                                        y: imageBorder.height
                                                    }
                                                    PathArc {
                                                        x: 0
                                                        y: imageBorder.height - imageItem.blr
                                                        radiusX: imageItem.blr
                                                        radiusY: imageItem.blr
                                                        direction: PathArc.Clockwise
                                                    }
                                                    PathLine {
                                                        x: 0
                                                        y: imageItem.tlr
                                                    }
                                                    PathArc {
                                                        x: imageItem.tlr
                                                        y: 0
                                                        radiusX: imageItem.tlr
                                                        radiusY: imageItem.tlr
                                                        direction: PathArc.Clockwise
                                                    }
                                                }
                                            }

                                            DankRipple {
                                                id: imageRipple
                                                anchors.fill: parent
                                                cornerRadius: imageItem.tlr
                                                rippleColor: Theme.primary
                                            }

                                            // Share/Send Button in the Corner (similar to the Pin button in QuickTote)
                                            Item {
                                                id: recentImageSendButton
                                                width: 32
                                                height: 32
                                                anchors.top: parent.top
                                                anchors.right: parent.right
                                                anchors.topMargin: -6
                                                anchors.rightMargin: -6
                                                readonly property bool isEnabled: root.activeDevice && root.activeDevice.isReachable && PhoneConnectService.hasPlugin(root.activeDeviceId, "share")
                                                opacity: isEnabled ? 1.0 : 0.4
                                                scale: (imageItem.hovered) ? 1.0 : 0.0
                                                Behavior on scale {
                                                    SequentialAnimation {
                                                        PauseAnimation {
                                                            duration: 150
                                                        }
                                                        NumberAnimation {
                                                            duration: 500
                                                            easing.type: Easing.OutBack
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: sendBtnBg
                                                    anchors.centerIn: parent
                                                    width: 24
                                                    height: 24
                                                    radius: 6
                                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)
                                                    border.width: 1
                                                    border.color: Theme.withAlpha(Theme.outline, 0.2)
                                                }

                                                DankIcon {
                                                    name: "send"
                                                    size: 14
                                                    anchors.centerIn: parent
                                                    color: recentImageSendButton.isEnabled && sendBtnMa.containsMouse ? Theme.primary : Theme.surfaceText
                                                }

                                                MouseArea {
                                                    id: sendBtnMa
                                                    anchors.fill: parent
                                                    hoverEnabled: recentImageSendButton.isEnabled
                                                    cursorShape: recentImageSendButton.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: {
                                                        if (!recentImageSendButton.isEnabled)
                                                            return;
                                                        Quickshell.execDetached(["sh", "-c", "gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Share.Share \"\" \"Share Image\" {} \"file://$1\" >/dev/null 2>&1 || dms open \"$1\"", "--", modelData.path]);
                                                        root.closePopout();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } // end deviceContentCol Column
                } // end deviceContentGroup Item

            } // end outer Column
        } // end PopoutComponent
    } // end popoutContent Component

    function refreshImages(clearFirst) {
        if (clearFirst === true) {
            root.recentImages = [];
        }
        if (!root.recentImagesPath) {
            root.recentImages = [];
            return;
        }

        const doScan = function () {
            if (imagesScanner) {
                if (!clearFirst && imagesScanner.running) {
                    return; // Avoid aborting an ongoing scan, which causes flickering
                }
                imagesScanner.running = false;
                Qt.callLater(function () {
                    if (root.recentImagesPath)
                        imagesScanner.running = true;
                });
            }
        };

        doScan();
    }

    onRecentImagesPathChanged: {
        const cached = loadRecentImagesCache(root.recentImagesPath);
        if (cached && cached.length > 0) {
            root.recentImages = cached;
            refreshImages(false);
        } else {
            refreshImages(true);
        }
    }
    onMaxRecentImagesChanged: refreshImages(true)
    onScanSubdirectoriesChanged: refreshImages(true)

    Timer {
        id: imageRefreshTimer
        interval: root.stateUpdateInterval > 0 ? (root.stateUpdateInterval * 1000) : 30000
        running: root.activeDeviceId !== "" && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshImages(false)
    }

    function getFileInfo(line) {
        let path = line.trim();
        if (!path || path.length < 3)
            return null;
        if (path.indexOf('|') !== -1) {
            path = path.split('|')[1];
        }
        try {
            path = path.replace(/^[a-z]+:\/\/\/?/i, "/");
            path = decodeURIComponent(path);
        } catch (e) {}
        path = path.split('"')[0].split("'")[0].split("<")[0];
        if (!path || path.length < 2)
            return null;
        return {
            path: path,
            name: path.split('/').pop(),
            time: Date.now()
        };
    }

    // Persistent offscreen cache for recent images to ensure they load instantly in the popout
    Item {
        visible: false
        width: 0
        height: 0
        Repeater {
            model: root.recentImages
            Image {
                source: "file://" + modelData.path
                asynchronous: true
                cache: true
            }
        }
    }

    Process {
        id: imagesScanner
        running: false
        command: ["bash", "-c", `d="${root.recentImagesPath}"; d=\${d#file://}; d=\${d#localhost}; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" ${root.scanSubdirectories ? "-maxdepth 4" : "-maxdepth 1"} -type f -not -name ".*" -not -name "*trashed*" \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -printf '%T@|%p\\n' 2>/dev/null | sort -rn | head -n ${root.maxRecentImages}`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(function (l) {
                    return l !== "";
                });
                let newImages = lines.map(root.getFileInfo).filter(function (f) {
                    return f !== null;
                });
                if (newImages.length !== root.recentImages.length) {
                    root.recentImages = newImages;
                    saveRecentImagesCache();
                } else {
                    let changed = false;
                    for (let i = 0; i < newImages.length; i++) {
                        if (newImages[i].path !== root.recentImages[i].path) {
                            changed = true;
                            break;
                        }
                    }
                    if (changed) {
                        root.recentImages = newImages;
                        saveRecentImagesCache();
                    }
                }
            }
        }
    }

    // --- System Drag (works from layer shell via ripdrag/xdragon) ---
    function startSystemDrag(path) {
        fileDragger.running = false; // Reset the process object
        fileDragger.command = ["bash", "-c", "pkill -x ripdrag; pkill -x xdragon; pkill -x dragon; " + "f=" + JSON.stringify(path) + "; " + "if command -v ripdrag >/dev/null 2>&1; then ripdrag --and-exit --icons-only --icon-size 64 --content-width 90 --content-height 64 \"$f\"; " + "elif command -v xdragon >/dev/null 2>&1; then xdragon --and-exit --small \"$f\"; " + "elif command -v dragon >/dev/null 2>&1; then dragon --and-exit --small \"$f\"; fi"];
        fileDragger.running = true;
    }

    Process {
        id: fileDragger
        running: false
    }
}
