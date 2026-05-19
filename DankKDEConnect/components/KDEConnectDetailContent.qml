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
    property string selectedDeviceId: ""
    property string customPhoneImage: ""
    readonly property var selectedDevice: selectedDeviceId ? PhoneConnectService.devices[selectedDeviceId] ?? null : null
    
    signal deviceSelected(string deviceId)

    implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingL

        RowLayout {
            spacing: Theme.spacingS
            width: parent.width

            StyledText {
                text: {
                    const count = PhoneConnectService.connectedCount;
                    if (count === 0)
                        return I18n.tr("No devices connected", "Status");
                    if (count === 1)
                        return I18n.tr("1 device connected", "Status");
                    return count + " " + I18n.tr("devices connected", "Status");
                }
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                Layout.fillWidth: true
            }

            DankActionButton {
                iconName: PhoneConnectService.isRefreshing ? "sync" : "refresh"
                buttonSize: 24
                onClicked: PhoneConnectService.refreshDevices()
                enabled: !PhoneConnectService.isRefreshing
            }
        }

        // Selected Device View
        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.selectedDevice !== null

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                PhoneDisplay {
                    height: 160
                    backgroundImage: root.customPhoneImage
                    isReachable: root.selectedDevice?.isReachable ?? false
                    onClicked: PhoneConnectService.sendPing(root.selectedDeviceId, "", function() {})
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 1
                    rowSpacing: Theme.spacingS

                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        StyledText {
                            text: root.selectedDevice?.name || ""
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: root.selectedDevice?.isReachable ? I18n.tr("Online", "Status") : I18n.tr("Offline", "Status")
                            font.pixelSize: Theme.fontSizeSmall
                            color: root.selectedDevice?.isReachable ? Theme.primary : Theme.surfaceVariantText
                        }
                    }

                    InfoRow {
                        icon: PhoneConnectService.getBatteryIcon(root.selectedDevice)
                        label: I18n.tr("Battery", "Label")
                        value: (root.selectedDevice?.batteryCharge ?? -1) >= 0 ? (root.selectedDevice.batteryCharge + "%") : "N/A"
                        valueColor: root.selectedDevice?.batteryCharging ? Theme.primary : Theme.surfaceText
                    }

                    InfoRow {
                        icon: PhoneConnectService.getNetworkIcon(root.selectedDevice) || "network_check"
                        label: I18n.tr("Network", "Label")
                        value: PhoneConnectService.getNetworkTypeLabel(root.selectedDevice)
                    }
                }
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingS
                
                DankActionButton {
                    iconName: "phone_in_talk"
                    iconColor: Theme.primary
                    buttonSize: 32
                    onClicked: PhoneConnectService.ringDevice(root.selectedDeviceId, function() {})
                }
                DankActionButton {
                    iconName: "folder"
                    iconColor: Theme.primary
                    buttonSize: 32
                    onClicked: {
                        PopoutService.closeControlCenter();
                        PhoneConnectService.startBrowsing(root.selectedDeviceId, function() {})
                    }
                }
                DankActionButton {
                    iconName: "share"
                    iconColor: Theme.primary
                    buttonSize: 32
                    onClicked: {
                        if (root.shareDeviceId === root.selectedDeviceId)
                            root.shareDeviceId = "";
                        else
                            root.shareDeviceId = root.selectedDeviceId;
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                DankActionButton {
                    visible: PhoneConnectService.deviceIds.length > 1
                    iconName: "swap_horiz"
                    iconColor: Theme.secondary
                    buttonSize: 32
                    onClicked: deviceSwitcherCol.visible = !deviceSwitcherCol.visible
                }
            }

            ShareDialog {
                visible: root.shareDeviceId === root.selectedDeviceId
                width: parent.width
                deviceId: root.selectedDeviceId
                parentPopout: root.parentPopout
                onClose: root.shareDeviceId = ""
                onShare: function(content, isUrl) {
                    if (isUrl)
                        PhoneConnectService.shareUrl(root.selectedDeviceId, content, function() {});
                    else
                        PhoneConnectService.shareText(root.selectedDeviceId, content, function() {});
                    root.shareDeviceId = "";
                }
                onShareFile: function(path) {
                    PhoneConnectService.shareUrl(root.selectedDeviceId, "file://" + path, function() {});
                    root.shareDeviceId = "";
                }
            }

            Column {
                id: deviceSwitcherCol
                width: parent.width
                spacing: Theme.spacingS
                visible: false

                Rectangle {
                    height: 1
                    width: parent.width
                    color: Theme.withAlpha(Theme.outline, 0.1)
                }

                Repeater {
                    model: PhoneConnectService.deviceIds
                    delegate: Rectangle {
                        required property string modelData
                        width: parent.width
                        height: 40
                        radius: Theme.cornerRadius
                        color: switchMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingS

                            DankIcon {
                                name: PhoneConnectService.getDeviceIcon(PhoneConnectService.getDevice(modelData))
                                size: 20
                                color: Theme.primary
                            }

                            StyledText {
                                text: PhoneConnectService.getDevice(modelData)?.name || modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: switchMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.deviceSelected(modelData)
                                deviceSwitcherCol.visible = false
                            }
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.selectedDevice === null

            DankIcon {
                name: "phonelink_off"
                size: 48
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.tr("No devices found", "Status")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
