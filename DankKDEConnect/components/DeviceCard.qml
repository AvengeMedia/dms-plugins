import QtQuick
import qs.Common
import qs.Widgets
import "../services"

StyledRect {
    id: root

    required property string deviceId
    required property var device
    property bool selectable: false
    property bool isSelected: false

    signal clicked
    signal action(string actionName)

    height: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: cardMouseArea.containsMouse && selectable ? Theme.withAlpha(Theme.primary, 0.08) : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
    border.width: 0
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: root.selectable
        cursorShape: root.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.selectable)
            root.clicked()
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: PhoneConnectService.getDeviceIcon(root.device)
                size: Theme.iconSize + 4
                color: root.device?.isReachable ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Theme.iconSize - Theme.spacingM * 2 - statusRow.width - 8

                StyledText {
                    text: root.device?.name || root.deviceId
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
                }
            }

            Row {
                id: statusRow
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    visible: root.device && root.device.batteryCharge >= 0
                    spacing: 4

                    DankIcon {
                        name: PhoneConnectService.getBatteryIcon(root.device)
                        size: Theme.iconSize - 4
                        color: root.device?.batteryCharging ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: (root.device?.batteryCharge ?? 0) + "%"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                DankIcon {
                    visible: PhoneConnectService.getNetworkIcon(root.device) !== ""
                    name: PhoneConnectService.getNetworkIcon(root.device)
                    size: Theme.iconSize - 4
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Row {
            visible: root.device?.isReachable && root.device?.isPaired
            spacing: Theme.spacingXS

            DankActionButton {
                iconName: "phone_in_talk"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                tooltipSide: "top"
                onClicked: root.action("ring")
            }

            DankActionButton {
                iconName: "notifications_active"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Ping", "KDE Connect ping tooltip")
                tooltipSide: "top"
                onClicked: root.action("ping")
            }

            DankActionButton {
                iconName: "content_paste"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Send Clipboard", "KDE Connect clipboard tooltip")
                tooltipSide: "top"
                onClicked: root.action("clipboard")
            }

            DankActionButton {
                iconName: "share"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                tooltipSide: "top"
                onClicked: root.action("share")
            }

            DankActionButton {
                iconName: "folder"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                tooltipSide: "top"
                onClicked: root.action("browse")
            }

            DankActionButton {
                visible: PhoneConnectService.supportsSms
                iconName: "sms"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                tooltipSide: "top"
                onClicked: root.action("sms")
            }

            DankActionButton {
                visible: root.device?.isPaired
                iconName: "link_off"
                iconColor: Theme.primary
                buttonSize: 36
                tooltipText: I18n.tr("Unpair", "KDE Connect unpair tooltip")
                tooltipSide: "top"
                onClicked: root.action("unpair")
            }
        }

        Row {
            visible: root.device?.isPairRequestedByPeer
            spacing: Theme.spacingS

            DankButton {
                text: I18n.tr("Accept", "KDE Connect accept pairing button")
                iconName: "check"
                onClicked: root.action("acceptPair")
            }

            DankButton {
                text: I18n.tr("Reject", "KDE Connect reject pairing button")
                iconName: "close"
                onClicked: root.action("rejectPair")
            }
        }

        Row {
            visible: root.device?.isReachable && !root.device?.isPaired && !root.device?.isPairRequestedByPeer
            spacing: Theme.spacingS

            DankButton {
                text: I18n.tr("Request Pairing", "KDE Connect request pairing button")
                iconName: "link"
                onClicked: root.action("pair")
            }
        }
    }

    function getStatusText() {
        if (!root.device)
            return I18n.tr("Unknown", "KDE Connect unknown device status");
        if (root.device.isPairRequestedByPeer)
            return I18n.tr("Pairing requested", "KDE Connect pairing requested status");
        if (root.device.isPairRequested)
            return I18n.tr("Pairing", "KDE Connect pairing in progress status") + "...";
        if (!root.device.isPaired)
            return I18n.tr("Not paired", "KDE Connect not paired status");
        if (!root.device.isReachable)
            return I18n.tr("Offline", "KDE Connect offline status");
        return "";
    }

    function getStatusColor() {
        if (!root.device)
            return Theme.surfaceVariantText;
        if (root.device.isPairRequestedByPeer)
            return Theme.warning;
        if (root.device.isPairRequested)
            return Theme.warning;
        return Theme.surfaceVariantText;
    }
}
