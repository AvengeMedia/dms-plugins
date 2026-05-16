import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../services"

Rectangle {
    id: root

    property var parentPopout: null
    property int listHeight: 280
    property string shareDeviceId: ""

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            spacing: Theme.spacingS
            width: parent.width

            StyledText {
                text: {
                    const count = PhoneConnectService.connectedCount;
                    if (count === 0)
                        return I18n.tr("No devices connected", "KDE Connect status");
                    if (count === 1)
                        return I18n.tr("1 device connected", "KDE Connect status single device");
                    return count + " " + I18n.tr("devices connected", "KDE Connect status multiple devices");
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                font.weight: Font.Medium
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                Layout.fillWidth: true
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: refreshArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                Layout.alignment: Qt.AlignVCenter
                opacity: PhoneConnectService.isRefreshing ? 0.5 : 1.0

                DankIcon {
                    anchors.centerIn: parent
                    name: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                    size: Theme.iconSize - 4
                    color: Theme.primary
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: PhoneConnectService.isRefreshing ? Qt.BusyCursor : Qt.PointingHandCursor
                    enabled: !PhoneConnectService.isRefreshing
                    onClicked: PhoneConnectService.refreshDevices()
                }
            }
        }

        Rectangle {
            height: 1
            width: parent.width
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
        }

        Item {
            width: parent.width
            height: root.listHeight

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !PhoneConnectService.available

                DankIcon {
                    name: "phonelink_off"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Phone Connect unavailable", "Phone Connect service unavailable message")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Start KDE Connect or Valent", "Phone Connect start daemon hint")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length === 0

                DankIcon {
                    name: "devices"
                    size: 36
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("No devices found", "KDE Connect no devices message")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Open KDE Connect on your phone", "KDE Connect open app hint")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DankListView {
                id: deviceListView
                anchors.fill: parent
                visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length > 0
                spacing: 8
                clip: true

                model: PhoneConnectService.deviceIds

                delegate: Rectangle {
                    id: deviceDelegate
                    required property string modelData

                    property var device: PhoneConnectService.getDevice(modelData)
                    property bool canControl: device?.isReachable && device?.isPaired
                    property bool isShareTarget: root.shareDeviceId === modelData

                    width: deviceListView.width
                    height: contentCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                    Column {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            DankIcon {
                                name: PhoneConnectService.getDeviceIcon(device)
                                size: Theme.iconSize + 4
                                color: device?.isReachable ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - Theme.iconSize - Theme.spacingM * 2 - statusRow.width - 8

                                StyledText {
                                    text: device?.name || modelData
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                StyledText {
                                    text: getStatusText()
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: getStatusColor()
                                    visible: text.length > 0

                                    function getStatusText() {
                                        if (!device)
                                            return I18n.tr("Unknown", "KDE Connect unknown device status");
                                        if (device.isPairRequestedByPeer)
                                            return I18n.tr("Pairing requested", "KDE Connect pairing requested status");
                                        if (device.isPairRequested)
                                            return I18n.tr("Pairing", "KDE Connect pairing in progress status") + "...";
                                        if (!device.isPaired)
                                            return I18n.tr("Not paired", "KDE Connect not paired status");
                                        if (!device.isReachable)
                                            return I18n.tr("Offline", "KDE Connect offline status");
                                        return "";
                                    }

                                    function getStatusColor() {
                                        if (!device)
                                            return Theme.surfaceVariantText;
                                        if (device.isPairRequestedByPeer)
                                            return Theme.warning;
                                        if (device.isPairRequested)
                                            return Theme.warning;
                                        return Theme.surfaceVariantText;
                                    }
                                }
                            }

                            Row {
                                id: statusRow
                                spacing: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    visible: device && device.batteryCharge >= 0
                                    spacing: 4

                                    DankIcon {
                                        name: PhoneConnectService.getBatteryIcon(device)
                                        size: Theme.iconSize - 4
                                        color: device?.batteryCharging ? Theme.primary : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: (device?.batteryCharge ?? 0) + "%"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                DankIcon {
                                    visible: PhoneConnectService.getNetworkIcon(device) !== ""
                                    name: PhoneConnectService.getNetworkIcon(device)
                                    size: Theme.iconSize - 4
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        Row {
                            visible: canControl
                            spacing: Theme.spacingXS

                            DankActionButton {
                                iconName: "phone_in_talk"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                                onClicked: {
                                    PhoneConnectService.ringDevice(modelData, response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Ringing", "KDE Connect ring action") + " " + (device?.name || I18n.tr("device", "Generic device name")));
                                    });
                                }
                            }

                            DankActionButton {
                                iconName: "notifications_active"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Ping", "KDE Connect ping tooltip")
                                onClicked: {
                                    PhoneConnectService.sendPing(modelData, "", response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Ping sent", "KDE Connect ping action"));
                                    });
                                }
                            }

                            DankActionButton {
                                iconName: "content_paste"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Send Clipboard", "KDE Connect clipboard tooltip")
                                onClicked: {
                                    PhoneConnectService.sendClipboard(modelData, response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Clipboard sent", "KDE Connect clipboard action"));
                                    });
                                }
                            }

                            DankActionButton {
                                iconName: "share"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                                onClicked: {
                                    if (deviceDelegate.isShareTarget)
                                        root.shareDeviceId = "";
                                    else
                                        root.shareDeviceId = modelData;
                                }
                            }

                            DankActionButton {
                                iconName: "folder"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                                onClicked: {
                                    PopoutService.closeControlCenter();
                                    PhoneConnectService.startBrowsing(modelData, response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Opening files", "KDE Connect browse action") + "...");
                                    });
                                }
                            }

                            DankActionButton {
                                visible: PhoneConnectService.supportsSms
                                iconName: "sms"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                                onClicked: {
                                    PopoutService.closeControlCenter();
                                    PhoneConnectService.launchSmsApp(modelData, response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Opening SMS", "KDE Connect SMS action") + "...");
                                    });
                                }
                            }

                            DankActionButton {
                                visible: device?.isPaired
                                iconName: "link_off"
                                iconColor: Theme.primary
                                buttonSize: 36
                                tooltipText: I18n.tr("Unpair", "KDE Connect unpair tooltip")
                                onClicked: {
                                    PhoneConnectService.unpair(modelData, response => {
                                        if (response.error)
                                            return;
                                        ToastService.showInfo(I18n.tr("Device unpaired", "KDE Connect unpair action"));
                                    });
                                }
                            }
                        }

                        Row {
                            visible: device?.isPairRequestedByPeer
                            spacing: Theme.spacingS

                            DankButton {
                                text: I18n.tr("Accept", "KDE Connect accept pairing button")
                                iconName: "check"
                                buttonHeight: 32
                                onClicked: PhoneConnectService.acceptPairing(modelData)
                            }

                            DankButton {
                                text: I18n.tr("Reject", "KDE Connect reject pairing button")
                                iconName: "close"
                                buttonHeight: 32
                                backgroundColor: Theme.error
                                textColor: Theme.primaryText
                                onClicked: PhoneConnectService.cancelPairing(modelData)
                            }
                        }

                        Row {
                            visible: device?.isReachable && !device?.isPaired && !device?.isPairRequestedByPeer
                            spacing: Theme.spacingS

                            DankButton {
                                text: I18n.tr("Pair", "KDE Connect pair button")
                                iconName: "link"
                                buttonHeight: 32
                                onClicked: PhoneConnectService.requestPairing(modelData)
                            }
                        }

                        ShareDialog {
                            visible: deviceDelegate.isShareTarget
                            width: parent.width
                            deviceId: modelData
                            parentPopout: root.parentPopout
                            onClose: root.shareDeviceId = ""
                            onShare: (content, isUrl) => {
                                function handleResponse(response) {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to share", "Phone Connect error"), response.error);
                                        return;
                                    }
                                    ToastService.showInfo(I18n.tr("Shared", "Phone Connect share success"));
                                }
                                if (isUrl)
                                    PhoneConnectService.shareUrl(modelData, content, handleResponse);
                                else
                                    PhoneConnectService.shareText(modelData, content, handleResponse);
                                root.shareDeviceId = "";
                            }
                            onShareFile: path => {
                                PhoneConnectService.shareUrl(modelData, "file://" + path, response => {
                                    if (response.error) {
                                        ToastService.showError(I18n.tr("Failed to send file", "Phone Connect error"), response.error);
                                        return;
                                    }
                                    ToastService.showInfo(I18n.tr("Sending", "Phone Connect file send") + " " + path.split("/").pop() + "...");
                                });
                                root.shareDeviceId = "";
                            }
                        }
                    }
                }
            }
        }
    }
}
