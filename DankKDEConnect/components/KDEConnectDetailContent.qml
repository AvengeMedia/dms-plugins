import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import "../services"
import QtQuick.Effects
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
    property string shareDeviceId: ""
    property string smsDeviceId: ""
    property bool switcherVisible: false


    property bool enableClipboardAction: pluginRoot ? pluginRoot.enableClipboardAction : true
    property bool showOngoingMedia: pluginRoot ? pluginRoot.showOngoingMedia : true
    property bool showDevicePlaceholder: pluginRoot ? pluginRoot.showDevicePlaceholder : (() => {
        try {
            const val = PluginService.loadPluginData(root.pluginId, "showDevicePlaceholder", "true");
            return val === true || val === "true" || val === 1;
        } catch(e) {}
        return true;
    })()

    // Colors
    readonly property color cardColor: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    readonly property color cardBorderColor: Theme.withAlpha(Theme.primary, 0.15)

    signal deviceSelected(string deviceId)

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    height: contentColumn.implicitHeight + Theme.spacingM * 2

    function sendClipboardWayland() {
        Proc.runCommand(null, ["wl-paste"], function(stdout, exitCode) {
            let content = stdout || "";
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
                    ToastService.showError(I18n.tr("Clipboard is empty or wl-paste failed."));
            }
        });
    }

    readonly property string effectiveDeviceId: (() => {
        if (selectedDeviceId && PhoneConnectService.deviceIds.includes(selectedDeviceId))
            return selectedDeviceId;
        const ids = PhoneConnectService.deviceIds;
        if (ids.length > 0)
            return ids[0];
        return "";
    })()

    readonly property bool hasDevice: effectiveDeviceId !== ""
    readonly property var selectedDevice: hasDevice ? (PhoneConnectService.devices[effectiveDeviceId] ?? null) : null
    readonly property bool isSelectedDeviceMobile: root.selectedDevice && (root.selectedDevice.type === "phone" || root.selectedDevice.type === "smartphone" || root.selectedDevice.type === "tablet")

    // Animated/active state for smooth device switching transitions
    property string activeDeviceId: ""
    readonly property var activeDevice: activeDeviceId ? (PhoneConnectService.devices[activeDeviceId] ?? null) : null
    readonly property string activeCustomPhoneImage: (() => {
        if (pluginRoot) {
            return pluginRoot.getDeviceImage(activeDeviceId);
        }
        try {
            const rawMap = PluginService.loadPluginData(root.pluginId, "deviceImageMap", "");
            if (rawMap) {
                const map = JSON.parse(rawMap);
                return map[activeDeviceId] || "";
            }
        } catch(e) {}
        return "";
    })()

    onEffectiveDeviceIdChanged: {
        if (activeDeviceId === "") {
            activeDeviceId = effectiveDeviceId;
        } else if (effectiveDeviceId !== activeDeviceId) {
            detailChangeAnim.restart();
        }
    }

    Component.onCompleted: {
        if (activeDeviceId === "" && effectiveDeviceId !== "") {
            activeDeviceId = effectiveDeviceId;
        }
    }

    SequentialAnimation {
        id: detailChangeAnim
        ParallelAnimation {
            NumberAnimation {
                target: detailDeviceContainerRow
                property: "opacity"
                to: 0
                duration: Theme.shorterDuration * 0.5
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: detailContainerTranslate
                property: "x"
                to: -15
                duration: Theme.shorterDuration * 0.5
                easing.type: Easing.OutQuad
            }
        }
        ScriptAction {
            script: { root.activeDeviceId = root.effectiveDeviceId; }
        }
        PropertyAction {
            target: detailContainerTranslate
            property: "x"
            value: 15
        }
        ParallelAnimation {
            NumberAnimation {
                target: detailDeviceContainerRow
                property: "opacity"
                to: 1
                duration: Theme.shorterDuration * 0.5
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: detailContainerTranslate
                property: "x"
                to: 0
                duration: Theme.shorterDuration * 0.5
                easing.type: Easing.OutQuad
            }
        }
    }

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

                        // Grouped Actions Container (for Switch & Refresh buttons to keep gap small)
                        Row {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0 // No gap between the buttons
                            visible: true

                            // Switch Device button (only when multiple devices available)
                            Item {
                                id: switcherButton
                                width: 38
                                height: 38
                                visible: PhoneConnectService.deviceIds.length > 1
                                scale: detailSwitcherArea.pressed ? 0.92 : (detailSwitcherArea.containsMouse ? 1.05 : 1.0)
                                
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                MouseArea {
                                    id: detailSwitcherArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(m) { detailSwitcherRipple.trigger(m.x, m.y) }
                                    onClicked: root.switcherVisible = !root.switcherVisible
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: root.switcherVisible ? height / 2 : Theme.cornerRadius
                                    bottomLeftRadius: root.switcherVisible ? height / 2 : Theme.cornerRadius
                                    topRightRadius: root.switcherVisible ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)
                                    bottomRightRadius: root.switcherVisible ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)

                                    color: root.switcherVisible
                                        ? Theme.withAlpha(Theme.secondary, 0.2)
                                        : (detailSwitcherArea.containsMouse ? Theme.withAlpha(Theme.secondary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4))
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.secondary, root.switcherVisible || detailSwitcherArea.containsMouse ? 0.4 : 0.15)

                                    Behavior on color { ColorAnimation { duration: Theme.popoutAnimationDuration } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.popoutAnimationDuration } }
                                    Behavior on topLeftRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on topRightRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                }

                                DankRipple {
                                    id: detailSwitcherRipple
                                    anchors.fill: parent
                                    cornerRadius: root.switcherVisible ? width / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)
                                    rippleColor: Theme.secondary
                                }

                                DankIcon {
                                    name: "swap_horiz"
                                    size: 20
                                    color: Theme.secondary
                                    anchors.centerIn: parent
                                    rotation: root.switcherVisible ? 180 : 0

                                    Behavior on rotation { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.OutBack } }
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
                                    onPressed: function(m) { detailRefreshRipple.trigger(m.x, m.y) }
                                    onClicked: PhoneConnectService.refreshDevices()
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    topLeftRadius: PhoneConnectService.isRefreshing ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)
                                    bottomLeftRadius: PhoneConnectService.isRefreshing ? height / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)
                                    topRightRadius: PhoneConnectService.isRefreshing ? height / 2 : Theme.cornerRadius
                                    bottomRightRadius: PhoneConnectService.isRefreshing ? height / 2 : Theme.cornerRadius

                                    color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                                    border.width: 1
                                    border.color: Theme.withAlpha(Theme.primary, refreshArea.containsMouse ? 0.3 : 0.15)
                                    
                                    Behavior on color { ColorAnimation { duration: Theme.popoutAnimationDuration } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.popoutAnimationDuration } }
                                    Behavior on topLeftRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomLeftRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on topRightRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                    Behavior on bottomRightRadius { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.InOutQuad } }
                                }

                                DankRipple {
                                    id: detailRefreshRipple
                                    anchors.fill: parent
                                    cornerRadius: PhoneConnectService.isRefreshing ? width / 2 : (PhoneConnectService.deviceIds.length > 1 ? 12 : Theme.cornerRadius)
                                    rippleColor: Theme.primary
                                }

                                DankIcon {
                                    name: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                                    size: 20
                                    color: Theme.primary
                                    anchors.centerIn: parent
                                    rotation: (refreshArea.containsMouse && !PhoneConnectService.isRefreshing) ? 180 : 0

                                    Behavior on rotation { NumberAnimation { duration: Theme.popoutAnimationDuration; easing.type: Easing.OutBack } }

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

                    readonly property bool shouldBeVisible: (!root.hasDevice || root.switcherVisible) && PhoneConnectService.deviceIds.length > 0

                    height: shouldBeVisible ? (switcherLayout.implicitHeight + Theme.spacingM * 2) : 0
                    opacity: shouldBeVisible ? 1.0 : 0.0
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
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
                            delegate: DeviceCard {
                                required property string modelData
                                required property int index
                                width: parent.width
                                deviceId: modelData
                                device: PhoneConnectService.getDevice(modelData)
                                selectable: true
                                isSelected: root.effectiveDeviceId === modelData
                                isFirst: index === 0
                                isLast: index === PhoneConnectService.deviceIds.length - 1
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
                    id: detailDeviceContainerRow
                    width: parent.width
                    height: {
                        if (!root.showDevicePlaceholder) {
                            return detailInfoColumn.implicitHeight + Theme.spacingM * 2;
                        }
                        const type = root.activeDevice?.type;
                        if (type === "desktop" || type === "computer" || type === "laptop" || type === "tablet" || type === "tv") {
                            return Math.max(detailInfoColumn.implicitHeight + Theme.spacingM * 2, 160);
                        }
                        return 255;
                    }
                    spacing: Theme.spacingM
                    visible: root.hasDevice
                    transform: Translate { id: detailContainerTranslate; x: 0 }

                    // Container 1: Device Image
                    StyledRect {
                        visible: root.showDevicePlaceholder
                        Layout.preferredWidth: {
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
                            id: detailPhoneDisplay
                            anchors.centerIn: parent
                            height: parent.height - 20
                            backgroundImage: root.activeCustomPhoneImage
                            isReachable: root.activeDevice?.isReachable ?? false
                            deviceType: root.activeDevice?.type ?? "phone"
                            onClicked: PhoneConnectService.sendPing(root.activeDeviceId, "", function(response) {})
                        }
                    }

                    // Container 2: Phone Name & Status
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 160
                        Layout.fillHeight: root.showDevicePlaceholder
                        Layout.preferredHeight: root.showDevicePlaceholder ? -1 : (detailInfoColumn.implicitHeight + Theme.spacingM * 2)
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
                            id: detailInfoColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: root.showDevicePlaceholder ? parent.bottom : undefined
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM

                            // Top Group: Device Name & Actions (Centered)
                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter

                                StyledText {
                                    text: root.activeDevice?.name || ""
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
                                                root.shareDeviceId = "";
                                                root.smsDeviceId = "";
                                                PhoneConnectService.ringDevice(root.activeDeviceId, function() {})
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
                                                if (!enabled) return;
                                                root.shareDeviceId = "";
                                                root.smsDeviceId = "";
                                                PhoneConnectService.sendPing(root.activeDeviceId, "", function(response) {});
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
                                                root.shareDeviceId = "";
                                                root.smsDeviceId = "";
                                                PopoutService.closeControlCenter();
                                                PhoneConnectService.startBrowsing(root.activeDeviceId, function() {})
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
                                                if (!enabled) return;
                                                root.sendClipboardWayland()
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
                                            iconColor: root.shareDeviceId === root.activeDeviceId ? Theme.secondary : Theme.primary
                                            buttonSize: 32
                                            tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                                            onClicked: {
                                                if (!enabled) return;
                                                root.smsDeviceId = "";
                                                root.shareDeviceId = (root.shareDeviceId === root.activeDeviceId) ? "" : root.activeDeviceId;
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
                                            iconColor: root.smsDeviceId === root.activeDeviceId ? Theme.secondary : Theme.primary
                                            buttonSize: 32
                                            tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                                            onClicked: {
                                                if (!enabled) return;
                                                root.shareDeviceId = "";
                                                root.smsDeviceId = (root.smsDeviceId === root.activeDeviceId) ? "" : root.activeDeviceId;
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
                    clip: true

                    readonly property bool shouldBeVisible: root.hasDevice && PhoneConnectService.hasPlugin(root.activeDeviceId, "sftp") && root.recentImages.length > 0
                    height: shouldBeVisible ? (recentImagesCol.implicitHeight + Theme.spacingM * 2) : 0
                    opacity: shouldBeVisible ? 1.0 : 0.0
                    visible: height > 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.shorterDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    radius: Theme.cornerRadius
                    color: root.cardColor
                    border.width: 1
                    border.color: root.cardBorderColor

                    layer.enabled: shouldBeVisible || height > 0
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
                            property int columns: (() => {
                                let count = root.recentImages.length;
                                if (count <= 0) return 0;
                                if (count <= 2) return count;
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
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
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
                                            layer.effect: MultiEffect {
                                                shadowEnabled: true
                                                shadowBlur: 0.3
                                                shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", sendBtnMa.containsMouse ? 0.35 : 0)
                                                Behavior on shadowColor { ColorAnimation { duration: 200 } }
                                            }
                                        }

                                        DankRipple {
                                            id: sendRipple
                                            anchors.fill: sendBtnBg
                                            cornerRadius: sendBtnBg.radius
                                            rippleColor: Theme.primary
                                        }

                                        DankIcon {
                                            name: "send"
                                            size: 14
                                            anchors.centerIn: parent
                                            color: sendBtnMa.containsMouse ? Theme.primary : Theme.surfaceText
                                        }

                                        MouseArea {
                                            id: sendBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onPressed: function(m) { sendRipple.trigger(m.x, m.y) }
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
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 4
                        shadowBlur: 0.6
                        shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.25)
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

                                DankKDEActionButton {
                                    iconName: "skip_previous"
                                    iconColor: Theme.surfaceText
                                    buttonSize: 28
                                    tooltipText: I18n.tr("Previous")
                                    onClicked: PhoneConnectService.mprisAction(root.effectiveDeviceId, "previous", function() {})
                                }

                                DankKDEActionButton {
                                    iconName: root.selectedDevice?.mediaIsPlaying ? "pause" : "play_arrow"
                                    iconColor: Theme.primary
                                    buttonSize: 32
                                    tooltipText: root.selectedDevice?.mediaIsPlaying ? I18n.tr("Pause") : I18n.tr("Play")
                                    onClicked: PhoneConnectService.mprisAction(root.effectiveDeviceId, "playpause", function() {})
                                }

                                DankKDEActionButton {
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
