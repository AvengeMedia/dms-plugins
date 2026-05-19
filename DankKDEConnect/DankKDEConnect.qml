import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    property string recentImagesPath: ""
    property int maxRecentImages: 4
    property var recentImages: []
    readonly property bool loadingImages: imagesScanner && imagesScanner.running
    property bool showShareDialog: false
    property string shareDeviceId: ""

    readonly property var selectedDevice: selectedDeviceId ? PhoneConnectService.devices[selectedDeviceId] ?? null : null
    readonly property bool hasDevice: selectedDevice !== null
    readonly property string serviceName: PhoneConnectService.backendName

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

    ccDetailHeight: 380 + (hasDevice && recentImages.length > 0 ? (recentImagesContainer.height + Theme.spacingM) : 0)
    onCcWidgetExpanded: PhoneConnectService.detectBackend()

    ccDetailContent: Component {
        KDEConnectDetailContent {
            listHeight: 300
            selectedDeviceId: root.selectedDeviceId
            customPhoneImage: root.customPhoneImage
            onDeviceSelected: function(deviceId) { root.selectDevice(deviceId); }
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

        const savedImagesPath = pluginService.loadPluginData("dankKDEConnect", "recentImagesPath", "");
        if (savedImagesPath)
            recentImagesPath = savedImagesPath;

        const savedMaxImages = pluginService.loadPluginData("dankKDEConnect", "maxRecentImages", 4);
        if (savedMaxImages)
            maxRecentImages = savedMaxImages;
    }

    onPluginDataChanged: {
        if (pluginData && pluginData.customPhoneImage !== undefined) {
            root.customPhoneImage = pluginData.customPhoneImage;
        }
        if (pluginData && pluginData.recentImagesPath !== undefined) {
            root.recentImagesPath = pluginData.recentImagesPath;
        }
        if (pluginData && pluginData.maxRecentImages !== undefined) {
            root.maxRecentImages = pluginData.maxRecentImages;
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
            PhoneConnectService.sendClipboard(deviceId, function(response) {
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
            PhoneConnectService.launchSmsApp(deviceId, function(response) {
                if (response.error) {
                    ToastService.showError(I18n.tr("Failed to launch SMS app", "Phone Connect error"), response.error);
                    return;
                }
                ToastService.showInfo(I18n.tr("Opening SMS app", "Phone Connect SMS action") + "...");
            });
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
                            onClicked: root.handleAction(root.selectedDeviceId, "ping")
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
                                value: PhoneConnectService.getNetworkTypeLabel(root.selectedDevice)
                            }

                            InfoRow {
                                icon: "notifications"
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
                    visible: (!root.hasDevice || popout.switcherVisible) && PhoneConnectService.deviceIds.length > 0
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
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

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
                                onAction: function(action) { root.handleAction(modelData, action); }
                            }
                        }
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
                                        
                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            transparentBorder: true
                                            radius: 8
                                            samples: 16
                                            color: Theme.withAlpha(Theme.shadowColor || "#000000", imageMouseArea.containsMouse ? 0.3 : 0.15)
                                            Behavior on color { ColorAnimation { duration: 250 } }
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
                                                root.closePopout();
                                            }
                                        }
                                    }
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
                    onShare: function(content, isUrl) {
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
                    onShareFile: function(path) {
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
            }
        }
    }

    function refreshImages() {
        if (imagesScanner) {
            imagesScanner.running = false;
            imagesScanner.running = true;
        }
    }

    onRecentImagesPathChanged: refreshImages()
    onMaxRecentImagesChanged: refreshImages()

    Timer {
        id: imageRefreshTimer
        interval: 10000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refreshImages()
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
                root.recentImages = lines.map(root.getFileInfo).filter(function(f) { return f !== null; });
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
