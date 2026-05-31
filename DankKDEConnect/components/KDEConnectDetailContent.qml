import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import Qt5Compat.GraphicalEffects
import qs.Modules.Plugins

// Self-contained CC detail content — reads device from PhoneConnectService directly
// so it works in the CC panel where the plugin instance has no pluginService/pluginData.
Item {
    id: root

    property var parentPopout: null
    property string customPhoneImage: ""
    // selectedDeviceId can be injected (popout), or falls back to first available device
    property string selectedDeviceId: ""
    property var recentImages: []
    property string recentImagesPath: ""
    property var pluginRoot: null
    property string pluginId: "dankKDEConnect"

    property bool enableClipboardAction: {
        let _ = typeof SettingsData !== "undefined" ? SettingsData.pluginSettings : null;
        return typeof SettingsData !== "undefined" ? SettingsData.getPluginSetting(pluginId, "enableClipboardAction", true) : true;
    }
    property bool showOngoingMedia: {
        let _ = typeof SettingsData !== "undefined" ? SettingsData.pluginSettings : null;
        return typeof SettingsData !== "undefined" ? SettingsData.getPluginSetting(pluginId, "showOngoingMedia", true) : true;
    }

    function sendClipboardWayland() {
        if (typeof DMSService === "undefined" || !DMSService.isConnected) {
            if (typeof ToastService !== "undefined")
                ToastService.showError(I18n.tr("DMS Service is not connected"));
            return;
        }
        DMSService.sendRequest("clipboard.paste", null, function(response) {
            if (response.error) {
                if (typeof ToastService !== "undefined")
                    ToastService.showError(I18n.tr("Failed to read clipboard: ") + response.error);
                return;
            }
            let content = response.result?.text || "";
            content = content.trim();
            if (content.length > 0) {
                if (typeof shareDialog !== "undefined" && shareDialog) {
                    shareDialog.shareText = content;
                }
                
                let isUrl = content.startsWith("http://") || content.startsWith("https://");
                if (isUrl)
                    PhoneConnectService.shareUrl(root.effectiveDeviceId, content, function() {});
                else
                    PhoneConnectService.shareText(root.effectiveDeviceId, content, function() {});
                
                if (typeof shareDialog !== "undefined" && shareDialog) {
                    shareDialog.shareText = "";
                }
                
                if (typeof ToastService !== "undefined")
                    ToastService.showInfo(I18n.tr("Clipboard sent"));
            } else {
                if (typeof ToastService !== "undefined")
                    ToastService.showError(I18n.tr("Clipboard is empty."));
            }
        });
    }

    // Effective device: injected ID, or first connected device, or first paired device
    readonly property string effectiveDeviceId: {
        if (selectedDeviceId && PhoneConnectService.devices[selectedDeviceId])
            return selectedDeviceId;
        const ids = PhoneConnectService.deviceIds;
        if (ids.length > 0)
            return ids[0];
        return "";
    }
    property var selectedDevice: null
    readonly property bool hasDevice: selectedDevice !== null

    Connections {
        target: PhoneConnectService
        function onDeviceUpdated(deviceId) {
            if (deviceId === root.effectiveDeviceId) {
                root.selectedDevice = PhoneConnectService.devices[deviceId] ?? null;
            }
        }
        function onDevicesListChanged() {
            root.selectedDevice = root.effectiveDeviceId ? PhoneConnectService.devices[root.effectiveDeviceId] ?? null : null;
        }
    }

    onEffectiveDeviceIdChanged: {
        selectedDevice = effectiveDeviceId ? PhoneConnectService.devices[effectiveDeviceId] ?? null : null;
    }

    Component.onCompleted: {
        selectedDevice = effectiveDeviceId ? PhoneConnectService.devices[effectiveDeviceId] ?? null : null;
    }

    property string shareDeviceId: ""
    property string smsDeviceId: ""
    property bool switcherVisible: false

    // Colors
    readonly property color cardColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color cardBorderColor: Theme.withAlpha(Theme.primary, 0.15)

    signal deviceSelected(string deviceId)

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    height: contentColumn.implicitHeight + Theme.spacingM * 2

    Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // Header card
                StyledRect {
                    width: parent.width
                    height: 72
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16.0
                        samples: 32
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
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
                                name: "smartphone"
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
                                text: I18n.tr("KDE Connect", "Service name")
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

                        Item {
                            width: 38
                            height: 38
                            Layout.alignment: Qt.AlignVCenter

                            MouseArea {
                                id: refreshArea
                                anchors.fill: parent
                                hoverEnabled: !PhoneConnectService.isRefreshing
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PhoneConnectService.refreshDevices()
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius
                                color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                                border.width: 1
                                border.color: Theme.withAlpha(Theme.primary, refreshArea.containsMouse ? 0.3 : 0.15)
                                
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }

                            DankIcon {
                                name: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                                size: 20
                                color: Theme.primary
                                anchors.centerIn: parent
                                scale: refreshArea.containsMouse ? 1.15 : 1.0
                                rotation: (refreshArea.containsMouse && !PhoneConnectService.isRefreshing) ? 180 : 0

                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
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
                    width: parent.width
                    height: 255
                    spacing: Theme.spacingM
                    visible: root.hasDevice

                    // Container 1: Phone Image
                    StyledRect {
                        Layout.preferredWidth: 135
                        Layout.fillHeight: true
                        radius: Theme.cornerRadius
                        color: root.cardColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 0
                            verticalOffset: 4
                            radius: 16.0
                            samples: 32
                            color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                        }

                        PhoneDisplay {
                            anchors.centerIn: parent
                            backgroundImage: root.customPhoneImage
                            isReachable: root.selectedDevice?.isReachable ?? false
                            onClicked: PhoneConnectService.sendPing(root.effectiveDeviceId, "", function(response) {})
                        }
                    }

                    // Container 2: Phone Name & Status
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.cornerRadius
                        color: root.cardColor
                        border.width: 1
                        border.color: root.cardBorderColor

                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 0
                            verticalOffset: 4
                            radius: 16.0
                            samples: 32
                            color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
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
                                    text: root.selectedDevice?.name || ""
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    spacing: Theme.spacingS
                                    Layout.alignment: Qt.AlignHCenter
                                    DankActionButton {
                                        enabled: root.selectedDevice && root.selectedDevice.supportedPlugins ? (root.selectedDevice.supportedPlugins.includes("findmyphone") || root.selectedDevice.supportedPlugins.includes("kdeconnect_findmyphone")) : false
                                        opacity: enabled ? 1.0 : 0.4
                                        iconName: "phone_in_talk"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                                        onClicked: {
                                            if (!enabled) return;
                                            root.shareDeviceId = "";
                                            root.smsDeviceId = "";
                                            PhoneConnectService.ringDevice(root.effectiveDeviceId, function() {})
                                        }
                                    }
                                    DankActionButton {
                                        enabled: root.selectedDevice && root.selectedDevice.supportedPlugins ? (root.selectedDevice.supportedPlugins.includes("sftp") || root.selectedDevice.supportedPlugins.includes("kdeconnect_sftp")) : false
                                        opacity: enabled ? 1.0 : 0.4
                                        iconName: "folder"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                                        onClicked: {
                                            if (!enabled) return;
                                            root.shareDeviceId = "";
                                            root.smsDeviceId = "";
                                            PopoutService.closeControlCenter();
                                            PhoneConnectService.startBrowsing(root.effectiveDeviceId, function() {})
                                        }
                                    }
                                    DankActionButton {
                                        visible: root.enableClipboardAction
                                        enabled: root.selectedDevice && root.selectedDevice.supportedPlugins ? (root.selectedDevice.supportedPlugins.includes("clipboard") || root.selectedDevice.supportedPlugins.includes("kdeconnect_clipboard")) : false
                                        opacity: enabled ? 1.0 : 0.4
                                        iconName: "content_copy"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Send Clipboard", "KDE Connect send clipboard tooltip")
                                        onClicked: {
                                            if (!enabled) return;
                                            root.sendClipboardWayland()
                                        }
                                    }
                                    DankActionButton {
                                        enabled: root.selectedDevice && root.selectedDevice.supportedPlugins ? (root.selectedDevice.supportedPlugins.includes("share") || root.selectedDevice.supportedPlugins.includes("kdeconnect_share")) : false
                                        opacity: enabled ? 1.0 : 0.4
                                        iconName: "share"
                                        iconColor: root.shareDeviceId === root.effectiveDeviceId ? Theme.secondary : Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                                        onClicked: {
                                            if (!enabled) return;
                                            root.smsDeviceId = "";
                                            root.shareDeviceId = (root.shareDeviceId === root.effectiveDeviceId) ? "" : root.effectiveDeviceId;
                                        }
                                    }
                                    DankActionButton {
                                        enabled: root.selectedDevice && root.selectedDevice.supportedPlugins ? (root.selectedDevice.supportedPlugins.includes("sms") || root.selectedDevice.supportedPlugins.includes("kdeconnect_sms")) : false
                                        opacity: enabled ? 1.0 : 0.4
                                        iconName: "sms"
                                        iconColor: root.smsDeviceId === root.effectiveDeviceId ? Theme.secondary : Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                                        onClicked: {
                                            if (!enabled) return;
                                            root.shareDeviceId = "";
                                            root.smsDeviceId = (root.smsDeviceId === root.effectiveDeviceId) ? "" : root.effectiveDeviceId;
                                        }
                                    }
                                    DankActionButton {
                                        visible: PhoneConnectService.deviceIds.length > 1
                                        iconName: "swap_horiz"
                                        iconColor: Theme.secondary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Switch Device", "KDE Connect switch device tooltip")
                                        onClicked: root.switcherVisible = !root.switcherVisible
                                    }
                                }
                            }

                            // Info Rows
                            InfoRow {
                                icon: PhoneConnectService.getBatteryIcon(root.selectedDevice)
                                label: I18n.tr("Battery", "KDE Connect battery label")
                                value: (root.selectedDevice?.batteryCharge ?? -1) >= 0 ? (root.selectedDevice.batteryCharge + "%") : I18n.tr("Unknown", "Status")
                                valueColor: root.selectedDevice?.batteryCharging ? Theme.primary : Theme.surfaceText
                            }

                            InfoRow {
                                icon: PhoneConnectService.getNetworkIcon(root.selectedDevice) || "signal_cellular_null"
                                label: I18n.tr("Signal Strength", "KDE Connect signal strength label")
                                value: I18n.tr(PhoneConnectService.getNetworkStrengthLabel(root.selectedDevice), "Network signal strength status")
                            }

                            InfoRow {
                                icon: PhoneConnectService.getNetworkTypeIcon(root.selectedDevice)
                                label: I18n.tr("Network Type", "KDE Connect network type label")
                                value: PhoneConnectService.getNetworkTypeLabel(root.selectedDevice)
                            }

                            InfoRow {
                                icon: "sms"
                                label: I18n.tr("Notifications", "KDE Connect notifications label")
                                value: root.selectedDevice?.notificationCount ?? 0
                            }
                        }
                    }
                }

                // Device Switcher Container
                StyledRect {
                    width: parent.width
                    height: switcherLayout.implicitHeight + Theme.spacingM * 2
                    visible: (!root.hasDevice || root.switcherVisible) && PhoneConnectService.deviceIds.length > 0
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16.0
                        samples: 32
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
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
                            delegate: DeviceCard {
                                required property string modelData
                                width: parent.width
                                deviceId: modelData
                                device: PhoneConnectService.getDevice(modelData)
                                selectable: true
                                isSelected: root.effectiveDeviceId === modelData
                                onClicked: {
                                    root.deviceSelected(modelData)
                                    root.switcherVisible = false
                                }
                                onAction: function(action) {
                                    if (action === "ring") {
                                        PhoneConnectService.ringDevice(modelData, function() {});
                                    } else if (action === "ping") {
                                        PhoneConnectService.sendPing(modelData, "", function() {});
                                    } else if (action === "clipboard") {
                                        PhoneConnectService.sendClipboard(modelData, function() {});
                                    } else if (action === "share") {
                                        root.shareDeviceId = modelData;
                                    } else if (action === "sms") {
                                        root.smsDeviceId = modelData;
                                    } else if (action === "browse") {
                                        PopoutService.closeControlCenter();
                                        PhoneConnectService.startBrowsing(modelData, function() {});
                                    } else if (action === "pair") {
                                        PhoneConnectService.requestPairing(modelData, function() {});
                                    } else if (action === "acceptPair") {
                                        PhoneConnectService.acceptPairing(modelData, function() {});
                                    } else if (action === "rejectPair") {
                                        PhoneConnectService.cancelPairing(modelData, function() {});
                                    } else if (action === "unpair") {
                                        PhoneConnectService.unpair(modelData, function() {});
                                    }
                                }
                            }
                        }
                    }
                }

                // Share dialog
                ShareDialog {
                    id: shareDialog
                    isOpen: root.shareDeviceId === root.effectiveDeviceId
                    width: parent.width
                    deviceId: root.effectiveDeviceId
                    parentPopout: root.parentPopout
                    onClose: root.shareDeviceId = ""
                    onShare: {
                        if (isUrl)
                            PhoneConnectService.shareUrl(root.effectiveDeviceId, content, function() {});
                        else
                            PhoneConnectService.shareText(root.effectiveDeviceId, content, function() {});
                        root.shareDeviceId = "";
                    }
                    onShareFile: {
                        PhoneConnectService.shareUrl(root.effectiveDeviceId, "file://" + path, function() {});
                        root.shareDeviceId = "";
                    }
                    onShareClipboard: {
                        root.sendClipboardWayland()
                        root.shareDeviceId = "";
                    }
                }

                // SMS dialog
                SmsDialog {
                    isOpen: root.smsDeviceId === root.effectiveDeviceId
                    width: parent.width
                    deviceId: root.effectiveDeviceId
                    onClose: root.smsDeviceId = ""
                    onSendSms: {
                        PhoneConnectService.sendSms(root.effectiveDeviceId, phoneNumber, message, [], function(response) {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to send SMS", "Phone Connect error"), response.error);
                                return;
                            }
                            ToastService.showInfo(I18n.tr("SMS sent successfully", "Phone Connect SMS action"));
                        });
                        root.smsDeviceId = "";
                    }
                    onLaunchApp: {
                        PhoneConnectService.launchSmsApp(root.effectiveDeviceId, function(response) {
                            if (response.error) {
                                ToastService.showError(I18n.tr("Failed to launch SMS app", "Phone Connect error"), response.error);
                                return;
                            }
                            ToastService.showInfo(I18n.tr("Opening SMS app", "Phone Connect SMS action") + "...");
                        });
                        root.smsDeviceId = "";
                    }
                }

                // Recent Images Section
                StyledRect {
                    id: recentImagesContainer
                    width: parent.width
                    height: recentImagesCol.implicitHeight + Theme.spacingM * 2
                    visible: root.hasDevice && root.recentImages.length > 0
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16.0
                        samples: 32
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
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
                                                    if (root.pluginRoot) {
                                                        root.pluginRoot.startSystemDrag(modelData.path);
                                                    }
                                                    PopoutService.closeControlCenter();
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
                                                PopoutService.closeControlCenter();
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
                                        layer.effect: OpacityMask { maskSource: imageMask }
                                        
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
                                    }

                                    DankRipple { id: imageRipple; anchors.fill: parent; cornerRadius: imageItem.tlr; rippleColor: Theme.primary }

                                    // Share/Send Button in the Corner
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
                                            layer.effect: DropShadow {
                                                transparentBorder: true
                                                radius: 6
                                                samples: 12
                                                color: Theme.withAlpha(Theme.shadowColor || "#000000", sendBtnMa.containsMouse ? 0.35 : 0)
                                                Behavior on color { ColorAnimation { duration: 200 } }
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
                                                PopoutService.closeControlCenter();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Ongoing Media Section
                StyledRect {
                    id: mprisContainer
                    width: parent.width
                    height: Math.max(80, mprisCol.implicitHeight) + Theme.spacingM * 2
                    visible: root.hasDevice && root.showOngoingMedia && (root.selectedDevice?.mediaTitle || "") !== ""
                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 4
                        radius: 16.0
                        samples: 32
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
                    }

                    // --- Ocean Wave Background ---
                    Canvas {
                        id: waveCanvas
                        anchors.fill: parent
                        z: 1
                        opacity: root.selectedDevice?.mediaIsPlaying ? 0.35 : 0.1
                        
                        property real phase: 0
                        
                        Timer {
                            interval: 16
                            running: root.selectedDevice?.mediaIsPlaying || false
                            repeat: true
                            onTriggered: {
                                waveCanvas.phase += 0.05;
                                waveCanvas.requestPaint();
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            
                            drawWave(ctx, Theme.withAlpha(Theme.primary, 0.15), 0.5, 12, phase);
                            drawWave(ctx, Theme.withAlpha(Theme.primary, 0.25), 0.8, 8, phase * 0.7);
                            drawWave(ctx, Theme.withAlpha(Theme.primary, 0.30), 0.8, 8, phase * 0.9);
                        }

                        function drawWave(ctx, color, speed, amplitude, currentPhase) {
                            ctx.beginPath();
                            ctx.fillStyle = color;
                            
                            var waveHeight = height * 0.75;
                            ctx.moveTo(0, height);
                            
                            for (var x = 0; x <= width; x += 5) {
                                var y = waveHeight + Math.sin(x * 0.025 + currentPhase) * amplitude;
                                ctx.lineTo(x, y);
                            }
                            
                            ctx.lineTo(width, height);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM
                        z: 2

                        // Rotating Vinyl Record / CD
                        Rectangle {
                            id: thumbnailContainer
                            width: 80
                            height: 80
                            radius: 40
                            color: Theme.withAlpha(Theme.surfaceContainerHighest || "#000000", 0.4)
                            border.color: Theme.withAlpha(Theme.primary, 0.2)
                            border.width: 1
                            clip: true
                            Layout.alignment: Qt.AlignVCenter

                            property real albumRotation: 0

                            NumberAnimation {
                                id: rotationAnimation
                                target: thumbnailContainer
                                property: "albumRotation"
                                from: 0
                                to: 360
                                duration: 20000
                                running: root.selectedDevice?.mediaIsPlaying || false
                                loops: Animation.Infinite
                            }

                            Item {
                                anchors.fill: parent
                                rotation: thumbnailContainer.albumRotation

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Theme.withAlpha(Theme.surfaceText, 0.15)
                                    border.width: 1
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Theme.withAlpha(Theme.surfaceText, 0.1)
                                    border.width: 1
                                }

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    anchors.centerIn: parent
                                    color: Theme.primary
                                    
                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "music_note"
                                        size: 16
                                        color: Theme.surface
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: mprisCol
                            Layout.fillWidth: true
                            spacing: Theme.spacingXS

                            // Header with Player Name
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "music_note"
                                    size: 14
                                    color: Theme.primary
                                }

                                StyledText {
                                    text: root.selectedDevice?.mediaPlayer || I18n.tr("Media Player")
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.primary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Track details
                            StyledText {
                                text: root.selectedDevice?.mediaTitle || ""
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: {
                                    let artist = root.selectedDevice?.mediaArtist || "";
                                    let album = root.selectedDevice?.mediaAlbum || "";
                                    if (artist && album) return artist + " — " + album;
                                    return artist || album || I18n.tr("Unknown Artist");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Playback Controls
                            RowLayout {
                                spacing: Theme.spacingM
                                Layout.alignment: Qt.AlignLeft

                                DankActionButton {
                                    iconName: "skip_previous"
                                    iconColor: Theme.surfaceText
                                    buttonSize: 28
                                    tooltipText: I18n.tr("Previous")
                                    onClicked: PhoneConnectService.mprisAction(root.effectiveDeviceId, "previous", function() {})
                                }

                                DankActionButton {
                                    iconName: root.selectedDevice?.mediaIsPlaying ? "pause" : "play_arrow"
                                    iconColor: Theme.primary
                                    buttonSize: 32
                                    tooltipText: root.selectedDevice?.mediaIsPlaying ? I18n.tr("Pause") : I18n.tr("Play")
                                    onClicked: PhoneConnectService.mprisAction(root.effectiveDeviceId, "playpause", function() {})
                                }

                                DankActionButton {
                                    iconName: "skip_next"
                                    iconColor: Theme.surfaceText
                                    buttonSize: 28
                                    tooltipText: I18n.tr("Next")
                                    onClicked: PhoneConnectService.mprisAction(root.effectiveDeviceId, "next", function() {})
                                }
                            }
                        }
                    }
                }

            }
        }
