import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./services"

PluginSettings {
    id: root
    pluginId: "dankKDEConnect"

    readonly property string serviceName: PhoneConnectService.backendName

    StyledText {
        text: serviceName
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Connect your phone and desktop. Share files, clipboard, notifications, and more."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Status"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    Row {
        spacing: Theme.spacingS

        DankIcon {
            name: PhoneConnectService.available ? "check_circle" : "error"
            size: Theme.iconSize
            color: PhoneConnectService.available ? Theme.success : Theme.error
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: PhoneConnectService.available ? (serviceName + " running") : "No backend running"
            font.pixelSize: Theme.fontSizeSmall
            color: PhoneConnectService.available ? Theme.success : Theme.error
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        visible: PhoneConnectService.available
        spacing: Theme.spacingS

        StyledText {
            text: "Connected: " + PhoneConnectService.connectedCount
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            text: "•"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            text: "Paired: " + PhoneConnectService.pairedCount
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }
    }

    Column {
        visible: PhoneConnectService.available && PhoneConnectService.selfId
        width: parent.width
        spacing: 4

        StyledText {
            text: "This device: " + PhoneConnectService.announcedName
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            text: "ID: " + PhoneConnectService.selfId
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            opacity: 0.7
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length > 0
        text: "Devices"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    Repeater {
        model: PhoneConnectService.deviceIds

        StyledRect {
            required property string modelData
            readonly property var device: PhoneConnectService.getDevice(modelData)

            width: parent.width
            height: deviceRow.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                id: deviceRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon {
                    name: PhoneConnectService.getDeviceIcon(device)
                    size: Theme.iconSize
                    color: device?.isReachable ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: device?.name || modelData
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    StyledText {
                        text: device?.isReachable ? "Connected" : (device?.isPaired ? "Offline" : "Not paired")
                        font.pixelSize: Theme.fontSizeSmall
                        color: device?.isReachable ? Theme.success : Theme.surfaceVariantText
                    }
                }
            }

            Row {
                visible: device && (device.batteryCharge ?? -1) >= 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.spacingS
                spacing: 4

                DankIcon {
                    name: PhoneConnectService.getBatteryIcon(device)
                    size: Theme.iconSize - 4
                    color: device?.batteryCharging ? Theme.success : Theme.surfaceVariantText
                }

                StyledText {
                    text: (device?.batteryCharge ?? 0) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }

    StyledText {
        visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length === 0
        text: "No devices found. Make sure KDE Connect or Valent is running on your other devices."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Quick Actions"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Actions available in the popout for paired devices:"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingXS

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "phone_in_talk"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "Ring - Make your phone ring to find it"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "notifications_active"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "Ping - Send a notification to the device"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "content_paste"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "Clipboard - Send clipboard to the device"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "share"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "Share - Send URLs or text to the device"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "folder"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "Browse - Open device file browser (SFTP)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }

        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "sms"
                size: Theme.iconSize - 4
                color: Theme.surfaceVariantText
            }
            StyledText {
                text: "SMS - Send text messages or open SMS app"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Requirements"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "• DMS daemon version 1.4 or higher\n• KDE Connect (kdeconnectd) or Valent\n• KDE Connect app on your mobile device"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    DankButton {
        visible: PhoneConnectService.available
        text: "Refresh Devices"
        iconName: "refresh"
        onClicked: PhoneConnectService.refreshDevices()
    }
}
