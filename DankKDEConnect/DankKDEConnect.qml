import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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

    property bool enableChargingAnimation: {
        const globalVal = enableChargingAnimationVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.enableChargingAnimation;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }

    property string selectedDeviceId: SettingsData.pluginSettings["dankKDEConnect"]?.selectedDeviceId || ""
    // Per-device custom image map: { deviceId: imagePath }
    readonly property var deviceImageMap: {
        const savedVal = deviceImageMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try { return JSON.parse(savedVal); } catch(e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceImageMap) {
            try { return JSON.parse(data.deviceImageMap); } catch(e) {}
        }
        // Migrate legacy single customPhoneImage to the map for the first paired device
        const legacy = data?.customPhoneImage || "";
        if (legacy) {
            const ids = PhoneConnectService.deviceIds;
            if (ids && ids.length > 0) {
                const m = {}; m[ids[0]] = legacy;
                return m;
            }
        }
        return {};
    }

    // Image for the currently selected device
    readonly property string customPhoneImage: deviceImageMap[selectedDeviceId] || ""

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

    readonly property real container1Width: {
        const type = root.activeDevice?.type;
        if (type === "desktop" || type === "computer" || type === "laptop") {
            return 240;
        } else if (type === "tv") {
            return 260;
        } else if (type === "tablet") {
            return 185;
        }
        return 135;
    }

    onActiveDeviceIdChanged: {
        recentImages = [];
        if (activeDeviceId && PhoneConnectService.hasPlugin(activeDeviceId, "sftp")) {
            refreshImages(true);
        }
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

    Component.onCompleted: {
        if (activeDeviceId === "" && selectedDeviceId !== "") {
            activeDeviceId = selectedDeviceId;
        }
        PhoneConnectService.deviceTypeMap = root.deviceTypeMap;
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

    // Per-device custom recent images path map: { deviceId: recentImagesPath }
    readonly property var deviceRecentImagesPathMap: {
        const savedVal = deviceRecentImagesPathMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try { return JSON.parse(savedVal); } catch(e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceRecentImagesPathMap) {
            try { return JSON.parse(data.deviceRecentImagesPathMap); } catch(e) {}
        }
        return {};
    }

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
    readonly property var deviceTypeMap: {
        const savedVal = deviceTypeMapVar.value;
        if (savedVal !== undefined && savedVal !== null && savedVal !== "") {
            try { return JSON.parse(savedVal); } catch(e) {}
        }
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        if (data && data.deviceTypeMap) {
            try { return JSON.parse(data.deviceTypeMap); } catch(e) {}
        }
        return {};
    }

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
        deviceTypeMapVar.set(JSON.stringify(updated));
        PluginService.savePluginData("dankKDEConnect", "deviceTypeMap", JSON.stringify(updated));
    }

    property string recentImagesPath: {
        if (activeDeviceId) {
            if (deviceRecentImagesPathMap[activeDeviceId]) {
                return deviceRecentImagesPathMap[activeDeviceId];
            }
            // Fallback to legacy single path ONLY if it's the first/only device, or if the device ID matches the first device
            const ids = PhoneConnectService.deviceIds;
            if (ids && ids.length > 0 && activeDeviceId === ids[0]) {
                const savedVal = recentImagesPathVar.value;
                if (savedVal !== undefined && savedVal !== null) return savedVal;
                const data = SettingsData.pluginSettings["dankKDEConnect"];
                return data?.recentImagesPath || "";
            }
            return "";
        }
        return "";
    }
    property int maxRecentImages: {
        const savedVal = maxRecentImagesVar.value;
        if (savedVal !== undefined) return savedVal;
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        return data?.maxRecentImages || 4;
    }
    property var recentImages: []
    readonly property bool loadingImages: imagesScanner && imagesScanner.running
    property bool showShareDialog: false
    property bool showSmsDialog: false
    property string shareDeviceId: ""

    onCustomPhoneImageChanged: {
        console.log("[DMS DEBUG DankKDEConnect] customPhoneImage changed to:", customPhoneImage)
    }

    // Reactive binding: always reflects the latest device data from the service
    readonly property bool hasDevice: selectedDeviceId !== "" && PhoneConnectService.deviceIds.includes(selectedDeviceId)
    readonly property var selectedDevice: hasDevice ? (PhoneConnectService.devices[selectedDeviceId] ?? null) : null
    readonly property bool isSelectedDeviceMobile: root.selectedDevice && (root.selectedDevice.type === "phone" || root.selectedDevice.type === "smartphone" || root.selectedDevice.type === "tablet")
    readonly property string serviceName: PhoneConnectService.backendName

    readonly property string pluginId: "dankKDEConnect"
    property bool enableClipboardAction: {
        const globalVal = enableClipboardActionVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.enableClipboardAction;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }
    property bool showOngoingMedia: {
        const globalVal = showOngoingMediaVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return (globalVal === true || globalVal === "true");
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        const localVal = data?.showOngoingMedia;
        return localVal !== undefined ? (localVal === true || localVal === "true") : true;
    }
    property int stateUpdateInterval: {
        const globalVal = stateUpdateIntervalVar.value;
        if (globalVal !== undefined && globalVal !== null)
            return parseInt(globalVal) || 30;
        const data = SettingsData.pluginSettings["dankKDEConnect"];
        return parseInt(data?.stateUpdateInterval) || 30;
    }

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
    popoutWidth: 400 + (container1Width - 135)

    ccDetailContent: Component {
        ScrollView {
            anchors.fill: parent
            clip: false
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            KDEConnectDetailContent {
                width: parent.width
                selectedDeviceId: root.selectedDeviceId
                customPhoneImage: root.customPhoneImage
                recentImages: root.recentImages
                recentImagesPath: root.recentImagesPath
                pluginRoot: root
                onDeviceSelected: function(deviceId) { root.selectDevice(deviceId); }
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



    readonly property bool isTyping: activeFocusItem && (activeFocusItem.toString().includes("TextInput") || activeFocusItem.toString().includes("TextEdit") || activeFocusItem.toString().includes("TextField") || activeFocusItem.toString().includes("TextArea"))

    function switchDeviceNext() {
        const ids = PhoneConnectService.deviceIds;
        if (ids.length <= 1) return;
        let idx = ids.indexOf(root.selectedDeviceId);
        idx = (idx + 1) % ids.length;
        root.selectDevice(ids[idx]);
    }

    function switchDevicePrev() {
        const ids = PhoneConnectService.deviceIds;
        if (ids.length <= 1) return;
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
        delegate: Shortcut {
            sequence: "Alt+" + (index + 1)
            onActivated: {
                if (index < PhoneConnectService.deviceIds.length) {
                    root.selectDevice(PhoneConnectService.deviceIds[index]);
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
            ToastService.showInfo(I18n.tr("Pairing request from", "Phone Connect pairing request notification") + " " + (device?.name || deviceId), msg);
        }

        function onShareReceived(deviceId, url) {
            const device = PhoneConnectService.getDevice(deviceId);
            const filename = url.split("/").pop() || url;
            const filePath = url.startsWith("file://") ? url.substring(7) : url;

            Quickshell.execDetached(["dms", "notify", "--app", serviceName, "--icon", "smartphone", "--file", filePath, I18n.tr("File received from", "Phone Connect file share notification") + " " + (device?.name || deviceId), filename]);
        }
    }

    function selectDevice(deviceId) {
        selectedDeviceId = deviceId;
        if (pluginService)
            pluginService.savePluginData("dankKDEConnect", "selectedDeviceId", deviceId);
    }

    function sendClipboardWayland(deviceId) {
        Proc.runCommand(null, ["wl-paste"], function(stdout, exitCode) {
            let content = stdout || "";
            content = content.trim();
            if (content.length > 0) {
                let isUrl = content.startsWith("http://") || content.startsWith("https://");
                if (isUrl)
                    PhoneConnectService.shareUrl(deviceId, content, function() {});
                else
                    PhoneConnectService.shareText(deviceId, content, function() {});
                
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo(I18n.tr("Clipboard sent", "Phone Connect clipboard action"));
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError(I18n.tr("Clipboard is empty or wl-paste failed."));
            }
        });
    }

    function handleAction(deviceId, action) {
        const device = PhoneConnectService.getDevice(deviceId);
        const deviceName = device?.name || I18n.tr("device", "Generic device name fallback");
        switch (action) {
        case "ring":
            PhoneConnectService.ringDevice(deviceId, function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to ring device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ringing", "Phone Connect ring action") + " " + deviceName + "...");
            });
            break;
        case "ping":
            PhoneConnectService.sendPing(deviceId, "", function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to send ping", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ping sent to", "Phone Connect ping action") + " " + deviceName);
            });
            break;
        case "clipboard":
            root.sendClipboardWayland(deviceId);
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
            PhoneConnectService.startBrowsing(deviceId, function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to browse device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Opening file browser", "Phone Connect browse action") + "...");
            });
            break;
        case "pair":
            PhoneConnectService.requestPairing(deviceId, function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Pairing failed", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Pairing request sent", "Phone Connect pairing action"));
            });
            break;
        case "acceptPair":
            PhoneConnectService.acceptPairing(deviceId, function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to accept pairing", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Device paired", "Phone Connect pairing action"));
            });
            break;
        case "rejectPair":
            PhoneConnectService.cancelPairing(deviceId, function(response) {
                if (response.error)
                    ToastService.showError(I18n.tr("Failed to reject pairing", "Phone Connect error"), response.error);
            });
            break;
        case "unpair":
            PhoneConnectService.unpair(deviceId, function(response) {
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
                visible: root.enableChargingAnimation &&
                         root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)

                Rectangle {
                    id: hWaveMask
                    anchors.fill: parent
                    radius: (root.barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
                    visible: false
                }

                Shape {
                    id: hWaveShape
                    anchors.fill: parent

                    property real value: (root.selectedDevice?.batteryCharge ?? 0) / 100.0
                    property real phase: 0
                    property real amp: 3
                    property color fillColor: {
                        const charge = root.selectedDevice?.batteryCharge ?? 0;
                        if (charge <= 20) return Theme.withAlpha(Theme.error, 0.3);
                        if (charge <= 50) return Theme.withAlpha(Theme.warning, 0.3);
                        return Theme.withAlpha(Theme.success, 0.3);
                    }

                    FrameAnimation {
                        running: hWaveContainer.visible
                        onTriggered: hWaveShape.phase += 0.08 * frameTime * 60
                    }

                    ShapePath {
                        fillColor: hWaveShape.fillColor
                        strokeColor: "transparent"

                        PathMove { x: 0; y: 0 }
                        PathLine {
                            x: {
                                let targetX = hWaveShape.width * hWaveShape.value;
                                return targetX + hWaveShape.amp * Math.sin(hWaveShape.phase);
                            }
                            y: 0
                        }
                        PathLine {
                            x: {
                                let targetX = hWaveShape.width * hWaveShape.value;
                                return targetX + hWaveShape.amp * Math.sin(hWaveShape.phase + 1.5);
                            }
                            y: hWaveShape.height * 0.25
                        }
                        PathLine {
                            x: {
                                let targetX = hWaveShape.width * hWaveShape.value;
                                return targetX + hWaveShape.amp * Math.sin(hWaveShape.phase + 3.0);
                            }
                            y: hWaveShape.height * 0.5
                        }
                        PathLine {
                            x: {
                                let targetX = hWaveShape.width * hWaveShape.value;
                                return targetX + hWaveShape.amp * Math.sin(hWaveShape.phase + 4.5);
                            }
                            y: hWaveShape.height * 0.75
                        }
                        PathLine {
                            x: {
                                let targetX = hWaveShape.width * hWaveShape.value;
                                return targetX + hWaveShape.amp * Math.sin(hWaveShape.phase + 6.0);
                            }
                            y: hWaveShape.height
                        }
                        PathLine { x: 0; y: hWaveShape.height }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: hWaveMask
                    }
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
                        name: root.hasDevice && root.selectedDevice.isReachable ? "smartphone" : "phonelink_off"
                        size: Theme.barIconSize(root.barThickness, -4)
                        color: {
                            if (!PhoneConnectService.available)
                                return Theme.widgetIconColor;
                            if (root.hasDevice && root.selectedDevice?.isReachable && root.selectedDevice?.batteryCharging)
                                return Theme.primary;
                            return Theme.widgetIconColor;
                        }
                    }

                    DankIcon {
                        visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)
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
                visible: root.enableChargingAnimation &&
                         root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)

                Rectangle {
                    id: vWaveMask
                    anchors.fill: parent
                    radius: (root.barConfig?.noBackground ?? false) ? 0 : Theme.cornerRadius
                    visible: false
                }

                Shape {
                    id: vWaveShape
                    anchors.fill: parent

                    property real value: (root.selectedDevice?.batteryCharge ?? 0) / 100.0
                    property real phase: 0
                    property real amp: 3
                    property color fillColor: {
                        const charge = root.selectedDevice?.batteryCharge ?? 0;
                        if (charge <= 20) return Theme.withAlpha(Theme.error, 0.3);
                        if (charge <= 50) return Theme.withAlpha(Theme.warning, 0.3);
                        return Theme.withAlpha(Theme.success, 0.3);
                    }

                    FrameAnimation {
                        running: vWaveContainer.visible
                        onTriggered: vWaveShape.phase += 0.08 * frameTime * 60
                    }

                    ShapePath {
                        fillColor: vWaveShape.fillColor
                        strokeColor: "transparent"

                        PathMove { x: 0; y: vWaveShape.height }
                        PathLine {
                            x: 0
                            y: {
                                let targetY = vWaveShape.height * (1.0 - vWaveShape.value);
                                return targetY + vWaveShape.amp * Math.sin(vWaveShape.phase);
                            }
                        }
                        PathLine {
                            x: vWaveShape.width * 0.25
                            y: {
                                let targetY = vWaveShape.height * (1.0 - vWaveShape.value);
                                return targetY + vWaveShape.amp * Math.sin(vWaveShape.phase + 1.5);
                            }
                        }
                        PathLine {
                            x: vWaveShape.width * 0.5
                            y: {
                                let targetY = vWaveShape.height * (1.0 - vWaveShape.value);
                                return targetY + vWaveShape.amp * Math.sin(vWaveShape.phase + 3.0);
                            }
                        }
                        PathLine {
                            x: vWaveShape.width * 0.75
                            y: {
                                let targetY = vWaveShape.height * (1.0 - vWaveShape.value);
                                return targetY + vWaveShape.amp * Math.sin(vWaveShape.phase + 4.5);
                            }
                        }
                        PathLine {
                            x: vWaveShape.width
                            y: {
                                let targetY = vWaveShape.height * (1.0 - vWaveShape.value);
                                return targetY + vWaveShape.amp * Math.sin(vWaveShape.phase + 6.0);
                            }
                        }
                        PathLine { x: vWaveShape.width; y: vWaveShape.height }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: vWaveMask
                    }
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
                        name: root.hasDevice && root.selectedDevice.isReachable ? "smartphone" : "phonelink_off"
                        size: Theme.barIconSize(root.barThickness)
                        color: {
                            if (!PhoneConnectService.available)
                                return Theme.widgetIconColor;
                            if (root.hasDevice && root.selectedDevice?.isReachable && root.selectedDevice?.batteryCharging)
                                return Theme.primary;
                            return Theme.widgetIconColor;
                        }
                    }

                    DankIcon {
                        visible: root.hasDevice && root.selectedDevice?.isReachable && (root.selectedDevice?.batteryCharging ?? false)
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

             SequentialAnimation {
                id: deviceChangeAnim
                ParallelAnimation {
                    NumberAnimation {
                        target: mainDeviceContainerRow
                        property: "opacity"
                        to: 0
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: mainContainerTranslate
                        property: "x"
                        to: -15
                        duration: 80
                        easing.type: Easing.OutQuad
                    }
                }
                ScriptAction {
                    script: { root.activeDeviceId = root.selectedDeviceId; }
                }
                PropertyAction {
                    target: mainContainerTranslate
                    property: "x"
                    value: 15
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: mainDeviceContainerRow
                        property: "opacity"
                        to: 1
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: mainContainerTranslate
                        property: "x"
                        to: 0
                        duration: 100
                        easing.type: Easing.OutQuad
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
                spacing: Theme.spacingM

                // Header card
                StyledRect {
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 72
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.6
                        shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
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
                            spacing: 2 // Gap between switch & refresh buttons
                            visible: true

                            // Switch Device button (only when multiple devices available)
                            Item {
                                id: switcherButton
                                width: 38
                                height: 38
                                visible: PhoneConnectService.deviceIds.length > 1
                                scale: switcherArea.pressed ? 0.92 : (switcherArea.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                MouseArea {
                                    id: switcherArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(m) { switcherRipple.trigger(m.x, m.y) }
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

                                    color: popout.switcherVisible
                                        ? Theme.withAlpha(Theme.secondary, 0.2)
                                        : (switcherArea.containsMouse ? Theme.withAlpha(Theme.secondary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4))
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.secondary, popout.switcherVisible || switcherArea.containsMouse ? 0.4 : 0.15)

                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
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

                                    Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                }
                            }

                            Item {
                                id: refreshButton
                                width: 38
                                height: 38
                                scale: refreshArea.pressed ? 0.92 : (refreshArea.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                MouseArea {
                                    id: refreshArea
                                    anchors.fill: parent
                                    hoverEnabled: !PhoneConnectService.isRefreshing
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(m) { refreshRipple.trigger(m.x, m.y) }
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
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }
                                    Behavior on topLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on topRightRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                                }

                                DankRipple {
                                    id: refreshRipple
                                    anchors.fill: parent
                                    cornerRadius: PhoneConnectService.isRefreshing ? width / 2 : (PhoneConnectService.deviceIds.length > 1 ? 8 : Theme.cornerRadius)
                                    rippleColor: Theme.primary
                                }

                                DankIcon {
                                    name: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                                    size: 20
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                    rotation: (refreshArea.containsMouse && !PhoneConnectService.isRefreshing) ? 180 : 0

                                    Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: PhoneConnectService.isRefreshing
                                    }
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
                            duration: 250
                            easing.type: Easing.InOutQuad
                        }
                    }
                    Behavior on opacity {
                        enabled: switcherContainer.animateHeight
                        NumberAnimation {
                            duration: 200
                        }
                    }

                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.6
                        shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                    }

                    Column {
                        id: switcherLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Repeater {
                            model: PhoneConnectService.deviceIds
                            DeviceCard {
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
                                    switcherContainer.animateHeight = true
                                    root.selectDevice(modelData)
                                    popout.switcherVisible = false
                                }
                                onAction: function(action) { root.handleAction(modelData, action); }
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

                // Main Container
                RowLayout {
                    id: mainDeviceContainerRow
                    width: parent.width
                    height: 255
                    spacing: Theme.spacingM
                    visible: root.hasDevice
                    transform: Translate { id: mainContainerTranslate; x: 0 }

                    // Container 1: Device Image
                    StyledRect {
                        Layout.preferredWidth: root.container1Width
                        Layout.fillHeight: true
                        radius: Theme.cornerRadius
                        color: root.cardColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 4
                            shadowBlur: 0.6
                            shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                        }

                        PhoneDisplay {
                            id: mainPhoneDisplay
                            anchors.centerIn: parent
                            backgroundImage: root.activeCustomPhoneImage
                            isReachable: root.activeDevice?.isReachable ?? false
                            deviceType: root.activeDevice?.type ?? "phone"
                            onClicked: root.handleAction(root.activeDeviceId, "ping")
                        }
                    }

                    // Container 2: Phone Name & Status
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 160
                        Layout.fillHeight: true
                        radius: Theme.cornerRadius
                        color: root.cardColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 4
                            shadowBlur: 0.6
                            shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            // Device Name & Actions
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true

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
                                                if (!enabled) return;
                                                root.handleAction(root.activeDeviceId, "ring")
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
                                                if (!enabled) return;
                                                root.handleAction(root.activeDeviceId, "browse")
                                            }
                                        }
                                    }

                                    Item {
                                        width: 32
                                        height: 32
                                        visible: root.enableClipboardAction
                                        enabled: root.activeDevice && root.activeDevice.isReachable
                                        DankKDEActionButton {
                                            anchors.fill: parent
                                            enabled: parent.enabled
                                            iconName: "content_paste"
                                            iconColor: Theme.primary
                                            buttonSize: 32
                                            tooltipText: I18n.tr("Send Clipboard", "KDE Connect send clipboard tooltip")
                                            onClicked: {
                                                if (!enabled) return;
                                                root.handleAction(root.activeDeviceId, "clipboard")
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
                                                if (!enabled) return;
                                                root.handleAction(root.activeDeviceId, "share")
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
                                                if (!enabled) return;
                                                root.handleAction(root.activeDeviceId, "sms")
                                            }
                                        }
                                    }
                                }
                            }

                            // Info Rows
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

                ShareDialog {
                    id: popoutShareDialog
                    isOpen: root.showShareDialog
                    width: parent.width
                    deviceId: root.shareDeviceId
                    parentPopout: popout.parentPopout
                    onClose: root.showShareDialog = false
                    onShare: {
                        if (isUrl) {
                            PhoneConnectService.shareUrl(root.shareDeviceId, content, function(response) {
                                if (response.error) {
                                    ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                    return;
                                }
                                ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                            });
                        } else {
                            PhoneConnectService.shareText(root.shareDeviceId, content, function(response) {
                                if (response.error) {
                                    ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                    return;
                                }
                                ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                            });
                        }
                        root.showShareDialog = false;
                    }
                    onShareFile: {
                        const fileUrl = "file://" + path;
                        PhoneConnectService.shareUrl(root.shareDeviceId, fileUrl, function(response) {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to send file", "Phone Connect error"), response.error);
                                return;
                            }
                            const filename = path.split("/").pop();
                            ToastService.showInfo(I18n.tr("Sending", "Phone Connect file send") + " " + filename + "...");
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
                    onSendSms: {
                        PhoneConnectService.sendSms(root.shareDeviceId, phoneNumber, message, [], function(response) {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to send SMS", "Phone Connect error"), response.error);
                                return;
                            }
                            ToastService.showInfo(I18n.tr("SMS sent successfully", "Phone Connect SMS action"));
                        });
                        root.showSmsDialog = false;
                    }
                    onLaunchApp: {
                        PhoneConnectService.launchSmsApp(root.shareDeviceId, function(response) {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to launch SMS app", "Phone Connect error"), response.error);
                                return;
                            }
                            ToastService.showInfo(I18n.tr("Opening SMS app", "Phone Connect SMS action") + "...");
                        });
                        root.showSmsDialog = false;
                    }
                }

                // Recent Images Section
                StyledRect {
                    id: recentImagesContainer
                    width: parent.width
                    height: recentImagesCol.implicitHeight + Theme.spacingM * 2
                    visible: root.hasDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp") && root.recentImages.length > 0
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.6
                        shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                    }

                    Column {
                        id: recentImagesCol
                        width: parent.width - Theme.spacingM * 2
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

                        Flow {
                            id: imagesGrid
                            width: parent.width
                            spacing: 4
                            property int columns: {
                                let count = root.recentImages.length;
                                if (count <= 0) return 0;
                                if (count <= 2) return count;
                                return Math.ceil(count / 2);
                            }

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
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    property bool hovered: imageMouseArea.containsMouse || sendBtnMa.containsMouse

                                    // Dynamic Corner Logic
                                    property real innerRadius: 6
                                    property real outerRadius: 12
                                    
                                    property int virtualIndex: isOddLayout ? (index === 0 ? 0 : index + 1) : index
                                    
                                    property bool isFirstRow: virtualIndex < Math.max(1, imagesGrid.columns)
                                    property bool isLastRow: {
                                        let totalVirtual = isOddLayout ? root.recentImages.length + 1 : root.recentImages.length;
                                        let cols = Math.max(1, imagesGrid.columns);
                                        return virtualIndex >= (Math.floor((totalVirtual - 1) / cols) * cols);
                                    }
                                    property bool isLeftCol: virtualIndex % Math.max(1, imagesGrid.columns) === 0
                                    property bool isRightCol: {
                                        let cols = Math.max(1, imagesGrid.columns);
                                        let endVirtual = isSpan2 ? 1 : virtualIndex;
                                        let totalVirtual = isOddLayout ? root.recentImages.length + 1 : root.recentImages.length;
                                        return (endVirtual % cols) === (cols - 1) || virtualIndex === (totalVirtual - 1);
                                    }

                                    property real tlr: (isFirstRow && isLeftCol) ? outerRadius : innerRadius
                                    property real trr: (isFirstRow && isRightCol) ? outerRadius : innerRadius
                                    property real blr: (isLastRow && isLeftCol) ? outerRadius : innerRadius
                                    property real brr: (isLastRow && isRightCol) ? outerRadius : innerRadius

                                    opacity: isDragging ? 0.45 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    MouseArea {
                                        id: imageMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        property real pressX: 0
                                        property real pressY: 0
                                        property bool dragLaunched: false

                                        onPressed: function(m) {
                                            pressX = m.x;
                                            pressY = m.y;
                                            dragLaunched = false;
                                            imageRipple.trigger(m.x, m.y);
                                        }

                                        onPositionChanged: function(m) {
                                            if (!dragLaunched && pressed) {
                                                let dx = m.x - pressX;
                                                let dy = m.y - pressY;
                                                if (Math.sqrt(dx*dx + dy*dy) > 12) {
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
                                    Canvas {
                                        id: imageMask
                                        anchors.fill: parent
                                        visible: false
                                        antialiasing: true
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.beginPath();
                                            ctx.moveTo(imageItem.tlr, 0);
                                            ctx.lineTo(width - imageItem.trr, 0);
                                            ctx.arcTo(width, 0, width, imageItem.trr, imageItem.trr);
                                            ctx.lineTo(width, height - imageItem.brr);
                                            ctx.arcTo(width, height, width - imageItem.brr, height, imageItem.brr);
                                            ctx.lineTo(imageItem.blr, height);
                                            ctx.arcTo(0, height, 0, height - imageItem.blr, imageItem.blr);
                                            ctx.lineTo(0, imageItem.tlr);
                                            ctx.arcTo(0, 0, imageItem.tlr, 0, imageItem.tlr);
                                            ctx.closePath();
                                            ctx.fillStyle = "black";
                                            ctx.fill();
                                        }
                                        function refresh() { requestPaint(); }
                                        Connections {
                                            target: imageItem
                                            function onTlrChanged() { imageMask.refresh(); }
                                            function onTrrChanged() { imageMask.refresh(); }
                                            function onBlrChanged() { imageMask.refresh(); }
                                            function onBrrChanged() { imageMask.refresh(); }
                                        }
                                        onWidthChanged: refresh()
                                        onHeightChanged: refresh()
                                    }

                                    Item {
                                        id: imageThumbCont
                                        anchors.fill: parent
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            maskEnabled: true
                                            maskSource: imageMask
                                        }
                                        
                                        Rectangle { anchors.fill: parent; color: Theme.surfaceContainer }
                                        Image {
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
                                            opacity: imageMouseArea.containsMouse ? 0.2 : 0
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }
                                    }

                                    // Border and Shadow Canvas
                                    Canvas {
                                        id: imageBorder
                                        anchors.fill: parent
                                        antialiasing: true
                                        property color borderColor: imageMouseArea.containsMouse ? Theme.primary : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.2)
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.beginPath();
                                            ctx.moveTo(imageItem.tlr, 0);
                                            ctx.lineTo(width - imageItem.trr, 0);
                                            ctx.arcTo(width, 0, width, imageItem.trr, imageItem.trr);
                                            ctx.lineTo(width, height - imageItem.brr);
                                            ctx.arcTo(width, height, width - imageItem.brr, height, imageItem.brr);
                                            ctx.lineTo(imageItem.blr, height);
                                            ctx.arcTo(0, height, 0, height - imageItem.blr, imageItem.blr);
                                            ctx.lineTo(0, imageItem.tlr);
                                            ctx.arcTo(0, 0, imageItem.tlr, 0, imageItem.tlr);
                                            ctx.closePath();
                                            ctx.strokeStyle = borderColor;
                                            ctx.lineWidth = 1.5;
                                            ctx.stroke();
                                        }
                                        onBorderColorChanged: requestPaint()
                                        function refresh() { requestPaint(); }
                                        Connections {
                                            target: imageItem
                                            function onTlrChanged() { imageBorder.refresh(); }
                                            function onTrrChanged() { imageBorder.refresh(); }
                                            function onBlrChanged() { imageBorder.refresh(); }
                                            function onBrrChanged() { imageBorder.refresh(); }
                                        }
                                        onWidthChanged: refresh()
                                        onHeightChanged: refresh()
                                        
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            shadowEnabled: true
                                            shadowBlur: 0.4
                                            shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", imageMouseArea.containsMouse ? 0.3 : 0.15)
                                            Behavior on shadowColor { ColorAnimation { duration: 250 } }
                                        }
                                    }

                                    DankRipple { id: imageRipple; anchors.fill: parent; cornerRadius: imageItem.tlr; rippleColor: Theme.primary }

                                    // Share/Send Button in the Corner (similar to the Pin button in QuickTote)
                                    Item {
                                        width: 32
                                        height: 32
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: -6
                                        anchors.rightMargin: -6
                                        scale: (imageItem.hovered) ? 1.0 : 0.0
                                        Behavior on scale { 
                                            SequentialAnimation {
                                                PauseAnimation { duration: 150 }
                                                NumberAnimation { duration: 500; easing.type: Easing.OutBack } 
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
                                            
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowBlur: 0.3
                                                shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", sendBtnMa.containsMouse ? 0.35 : 0)
                                                Behavior on shadowColor { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        DankIcon {
                                            name: "send"
                                            size: 14
                                            anchors.centerIn: parent
                                            color: sendBtnMa.containsMouse ? Theme.primary : Theme.surfaceText
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }

                                        MouseArea {
                                            id: sendBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                Quickshell.execDetached([
                                                    "sh",
                                                    "-c",
                                                    "gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Share.Share \"\" \"Share Image\" {} \"file://$1\" >/dev/null 2>&1 || dms open \"$1\"",
                                                    "--",
                                                    modelData.path
                                                ]);
                                                root.closePopout();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

            }
        }
    }

    function refreshImages(clearFirst) {
        if (clearFirst === true) {
            root.recentImages = [];
        }
        if (!root.recentImagesPath) {
            root.recentImages = [];
            return;
        }
        if (imagesScanner) {
            imagesScanner.running = false;
            Qt.callLater(function() {
                imagesScanner.running = true;
            });
        }
    }

    onRecentImagesPathChanged: refreshImages(true)
    onMaxRecentImagesChanged: refreshImages(true)

    Timer {
        id: imageRefreshTimer
        interval: 10000
        running: root.activeDeviceId !== "" && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshImages(false)
    }

    function getFileInfo(line) {
        let path = line.trim();
        if (!path || path.length < 3) return null;
        if (path.indexOf('|') !== -1) {
            path = path.split('|')[1];
        }
        try {
            path = path.replace(/^[a-z]+:\/\/\/?/i, "/");
            path = decodeURIComponent(path);
        } catch(e) {}
        path = path.split('"')[0].split("'")[0].split("<")[0];
        if (!path || path.length < 2) return null;
        return {
            path: path,
            name: path.split('/').pop(),
            time: Date.now()
        };
    }

    Process {
        id: imagesScanner
        running: false
        command: ["bash", "-c", `d="${root.recentImagesPath}"; d=\${d#file://}; d=\${d#localhost}; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" -maxdepth 1 -type f -not -name ".*" -not -name "*trashed*" \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxRecentImages}`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(function(l) { return l !== ""; });
                let newImages = lines.map(root.getFileInfo).filter(function(f) { return f !== null; });
                if (newImages.length !== root.recentImages.length) {
                    root.recentImages = newImages;
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
                    }
                }
            }
        }
    }

    // --- System Drag (works from layer shell via ripdrag/xdragon) ---
    function startSystemDrag(path) {
        fileDragger.running = false; // Reset the process object
        fileDragger.command = [
            "bash", "-c",
            "pkill -x ripdrag; pkill -x xdragon; pkill -x dragon; " +
            "f=" + JSON.stringify(path) + "; " +
            "if command -v ripdrag >/dev/null 2>&1; then ripdrag --and-exit --icons-only --icon-size 64 --content-width 90 --content-height 64 \"$f\"; " +
            "elif command -v xdragon >/dev/null 2>&1; then xdragon --and-exit --small \"$f\"; " +
            "elif command -v dragon >/dev/null 2>&1; then dragon --and-exit --small \"$f\"; fi"
        ];
        fileDragger.running = true;
    }

    Process {
        id: fileDragger
        running: false
    }
}
