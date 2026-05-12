import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"
import "./services"
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root

    property string selectedDeviceId: pluginData.selectedDeviceId || ""
    property string customPhoneImage: pluginData.customPhoneImage || ""
    property bool showShareDialog: false
    property string shareDeviceId: ""

    readonly property var selectedDevice: selectedDeviceId ? PhoneConnectService.devices[selectedDeviceId] ?? null : null
    readonly property bool hasDevice: selectedDevice !== null
    readonly property string serviceName: PhoneConnectService.backendName

    ccWidgetIcon: {
        if (!PhoneConnectService.available)
            return "phonelink_off";
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

    ccDetailHeight: 380
    onCcWidgetExpanded: PhoneConnectService.detectBackend()

    ccDetailContent: Component {
        KDEConnectDetailContent {
            listHeight: 300
            selectedDeviceId: root.selectedDeviceId
            customPhoneImage: root.customPhoneImage
            onDeviceSelected: deviceId => root.selectDevice(deviceId)
        }
    }

    onPluginServiceChanged: {
        if (!pluginService)
            return;
        const savedId = pluginService.loadPluginData("dankKDEConnect", "selectedDeviceId", "");
        if (savedId)
            selectedDeviceId = savedId;
            
        const savedImage = pluginService.loadPluginData("dankKDEConnect", "customPhoneImage", "");
        if (savedImage)
            customPhoneImage = savedImage;
    }

    onPluginDataChanged: {
        if (pluginData && pluginData.customPhoneImage !== undefined) {
            root.customPhoneImage = pluginData.customPhoneImage;
        }
    }

    Connections {
        target: PhoneConnectService
        function onDevicesListChanged() {
            if (!selectedDeviceId && PhoneConnectService.deviceIds.length > 0)
                selectDevice(PhoneConnectService.deviceIds[0]);
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

    function handleAction(deviceId, action) {
        const device = PhoneConnectService.getDevice(deviceId);
        const deviceName = device?.name || I18n.tr("device", "Generic device name fallback");
        switch (action) {
        case "ring":
            PhoneConnectService.ringDevice(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to ring device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ringing", "Phone Connect ring action") + " " + deviceName + "...");
            });
            break;
        case "ping":
            PhoneConnectService.sendPing(deviceId, "", response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to send ping", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Ping sent to", "Phone Connect ping action") + " " + deviceName);
            });
            break;
        case "clipboard":
            PhoneConnectService.sendClipboard(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to send clipboard", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Clipboard sent", "Phone Connect clipboard action"));
            });
            break;
        case "share":
            if (showShareDialog && shareDeviceId === deviceId) {
                showShareDialog = false;
                shareDeviceId = "";
            } else {
                shareDeviceId = deviceId;
                showShareDialog = true;
            }
            break;
        case "sms":
            closePopout();
            PhoneConnectService.launchSmsApp(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to launch SMS app", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Opening SMS app", "Phone Connect SMS action") + "...");
            });
            break;
        case "browse":
            closePopout();
            PhoneConnectService.startBrowsing(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to browse device", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Opening file browser", "Phone Connect browse action") + "...");
            });
            break;
        case "pair":
            PhoneConnectService.requestPairing(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Pairing failed", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Pairing request sent", "Phone Connect pairing action"));
            });
            break;
        case "acceptPair":
            PhoneConnectService.acceptPairing(deviceId, response => {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to accept pairing", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Device paired", "Phone Connect pairing action"));
            });
            break;
        case "rejectPair":
            PhoneConnectService.cancelPairing(deviceId, response => {
                if (response.error)
                    ToastService.showError(I18n.tr("Failed to reject pairing", "Phone Connect error"), response.error);
            });
            break;
        case "unpair":
            PhoneConnectService.unpair(deviceId, response => {
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
        Row {
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

    verticalBarPill: Component {
        Column {
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

    popoutContent: Component {
        PopoutComponent {
            id: popout
            property bool switcherVisible: false

            Component.onCompleted: PhoneConnectService.detectBackend()

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
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.primary, 0.15)

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 3
                        radius: 12.0
                        samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
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
                StyledRect {
                    width: parent.width
                    height: innerLayout.implicitHeight + Theme.spacingM * 2

                    Behavior on height {
                        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                    }
                    visible: root.hasDevice || PhoneConnectService.deviceIds.length > 0
                    clip: true
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.primary, 0.15)

                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 3
                        radius: 12.0
                        samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Column {
                        id: innerLayout
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingL

                        RowLayout {
                        width: parent.width
                        spacing: Theme.spacingL

                        // Phone Mockup
                        Item {
                            width: 115
                            height: 235
                            Layout.alignment: Qt.AlignVCenter

                            PhoneDisplay {
                                anchors.centerIn: parent
                                backgroundImage: root.customPhoneImage
                                isReachable: root.selectedDevice?.isReachable ?? false
                                onClicked: root.handleAction(root.selectedDeviceId, "ping")
                            }
                        }

                        // Stats Grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 1
                            rowSpacing: Theme.spacingM
                            Layout.alignment: Qt.AlignTop

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
                                }

                                RowLayout {
                                    spacing: Theme.spacingS
                                    DankActionButton {
                                        iconName: "phone_in_talk"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                                        onClicked: root.handleAction(root.selectedDeviceId, "ring")
                                    }
                                    DankActionButton {
                                        iconName: "folder"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                                        onClicked: root.handleAction(root.selectedDeviceId, "browse")
                                    }
                                    DankActionButton {
                                        iconName: "share"
                                        iconColor: Theme.primary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                                        onClicked: root.handleAction(root.selectedDeviceId, "share")
                                    }
                                    DankActionButton {
                                        visible: PhoneConnectService.deviceIds.length > 1
                                        iconName: "swap_horiz"
                                        iconColor: Theme.secondary
                                        buttonSize: 32
                                        tooltipText: I18n.tr("Switch Device", "KDE Connect switch device tooltip")
                                        onClicked: popout.switcherVisible = !popout.switcherVisible
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
                                icon: PhoneConnectService.getNetworkIcon(root.selectedDevice) || "network_check"
                                label: I18n.tr("Network", "KDE Connect network label")
                                value: root.selectedDevice?.networkType || I18n.tr("Unknown", "Status")
                            }

                            InfoRow {
                                icon: "notifications"
                                label: I18n.tr("Notifications", "KDE Connect notifications label")
                                value: root.selectedDevice?.notificationCount ?? 0
                            }
                        }
                    }

                    // Device Switcher List (shown when toggled)
                    Column {
                        id: deviceSwitcher
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: !root.hasDevice || popout.switcherVisible

                        Rectangle {
                            height: 1
                            width: parent.width
                            color: Theme.withAlpha(Theme.outline, 0.1)
                        }

                        Repeater {
                            model: PhoneConnectService.deviceIds
                            DeviceCard {
                                required property string modelData
                                width: parent.width
                                deviceId: modelData
                                device: PhoneConnectService.getDevice(modelData)
                                selectable: true
                                isSelected: root.selectedDeviceId === modelData
                                onClicked: {
                                    root.selectDevice(modelData)
                                    popout.switcherVisible = false
                                }
                                onAction: action => root.handleAction(modelData, action)
                            }
                        }
                    }
                    }
                }

                ShareDialog {
                    isOpen: root.showShareDialog
                    width: parent.width
                    deviceId: root.shareDeviceId
                    parentPopout: popout.parentPopout
                    onClose: root.showShareDialog = false
                    onShare: (content, isUrl) => {
                        if (isUrl) {
                            PhoneConnectService.shareUrl(root.shareDeviceId, content, response => {
                                if (response.error) {
                                    ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                    return;
                                }
                                ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                            });
                        } else {
                            PhoneConnectService.shareText(root.shareDeviceId, content, response => {
                                if (response.error) {
                                    ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                    return;
                                }
                                ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                            });
                        }
                        root.showShareDialog = false;
                    }
                    onShareFile: path => {
                        const fileUrl = "file://" + path;
                        PhoneConnectService.shareUrl(root.shareDeviceId, fileUrl, response => {
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
            }
        }
    }
}
