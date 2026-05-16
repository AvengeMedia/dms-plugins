import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "./components"
import "./services"

PluginComponent {
    id: root

    property string selectedDeviceId: pluginData.selectedDeviceId || ""
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

    ccDetailHeight: 350
    onCcWidgetExpanded: PhoneConnectService.detectBackend()

    ccDetailContent: Component {
        KDEConnectDetailContent {
            listHeight: 300
        }
    }

    onPluginServiceChanged: {
        if (!pluginService)
            return;
        const savedId = pluginService.loadPluginData("dankKDEConnect", "selectedDeviceId", "");
        if (savedId)
            selectedDeviceId = savedId;
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

            Component.onCompleted: PhoneConnectService.detectBackend()

            headerText: root.serviceName
            detailsText: PhoneConnectService.connectedCount + " connected • " + PhoneConnectService.pairedCount + " paired"
            showCloseButton: true
            headerActions: Component {
                DankActionButton {
                    iconName: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                    iconColor: Theme.surfaceVariantText
                    buttonSize: 28
                    enabled: !PhoneConnectService.isRefreshing
                    tooltipText: I18n.tr("Refresh", "Phone Connect refresh tooltip")
                    tooltipSide: "bottom"
                    onClicked: PhoneConnectService.refreshDevices()
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                UnavailableMessage {
                    visible: !PhoneConnectService.available
                    width: parent.width
                }

                EmptyState {
                    visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length === 0
                    width: parent.width
                }

                Repeater {
                    model: PhoneConnectService.deviceIds

                    DeviceCard {
                        required property string modelData
                        width: parent.width
                        deviceId: modelData
                        device: PhoneConnectService.getDevice(modelData)
                        selectable: PhoneConnectService.deviceIds.length > 1
                        isSelected: root.selectedDeviceId === modelData
                        onClicked: root.selectDevice(modelData)
                        onAction: action => root.handleAction(modelData, action)
                    }
                }

                ShareDialog {
                    visible: root.showShareDialog
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
