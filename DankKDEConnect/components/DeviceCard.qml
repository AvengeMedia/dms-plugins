import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Widgets
import "../services"

StyledRect {
    id: root

    required property string deviceId
    required property var device
    property bool selectable: false
    property bool isSelected: false

    property bool isFirst: false
    property bool isLast: false

    signal clicked
    signal action(string actionName)

    height: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: 0
    topLeftRadius: isFirst ? Theme.cornerRadius : 4
    topRightRadius: isFirst ? Theme.cornerRadius : 4
    bottomLeftRadius: isLast ? Theme.cornerRadius : 4
    bottomRightRadius: isLast ? Theme.cornerRadius : 4

    color: isSelected ? Theme.withAlpha(Theme.primary, 0.12) : (cardMouseArea.containsMouse && selectable ? Theme.withAlpha(Theme.surfaceContainerHighest, 0.8) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.4))
    border.width: isSelected ? 1 : 0
    border.color: Theme.primary

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
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                width: 36
                height: 36
                enabled: root.device && root.device.isReachable && PhoneConnectService.hasPlugin(root.deviceId, "findmyphone")
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "phone_in_talk"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("Ring", "KDE Connect ring tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("ring");
                    }
                }
            }

            Item {
                width: 36
                height: 36
                enabled: root.device && root.device.isReachable && PhoneConnectService.hasPlugin(root.deviceId, "ping")
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "notifications_active"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("Ping", "KDE Connect ping tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("ping");
                    }
                }
            }

            Item {
                width: 36
                height: 36
                visible: typeof SettingsData !== "undefined" ? (SettingsData.getPluginSettingsForPlugin("dankKDEConnect")?.enableClipboardAction ?? true) : true
                enabled: root.device && root.device.isReachable
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "content_paste"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("Send Clipboard", "KDE Connect clipboard tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("clipboard");
                    }
                }
            }

            Item {
                width: 36
                height: 36
                enabled: root.device && root.device.isReachable && PhoneConnectService.hasPlugin(root.deviceId, "share")
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "share"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("Share", "KDE Connect share tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("share");
                    }
                }
            }

            Item {
                width: 36
                height: 36
                enabled: root.device && root.device.isReachable && PhoneConnectService.hasPlugin(root.deviceId, "sftp")
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "folder"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("Browse Files", "KDE Connect browse tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("browse");
                    }
                }
            }

            Item {
                width: 36
                height: 36
                enabled: root.device && root.device.isReachable && PhoneConnectService.hasPlugin(root.deviceId, "sms")
                DankActionButton {
                    anchors.fill: parent
                    enabled: parent.enabled
                    opacity: enabled ? 1.0 : 0.4
                    iconName: "sms"
                    iconColor: Theme.primary
                    buttonSize: 36
                    tooltipText: I18n.tr("SMS", "KDE Connect SMS tooltip")
                    tooltipSide: "top"
                    onClicked: {
                        if (!enabled) return;
                        root.action("sms");
                    }
                }
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
