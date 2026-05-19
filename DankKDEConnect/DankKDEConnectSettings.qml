import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Modals.FileBrowser
import QtQuick.Layouts
import qs.Services
import "./services"

PluginSettings {
    id: root
    pluginId: "dankKDEConnect"

    readonly property string serviceName: PhoneConnectService.backendName

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
            PluginService.setGlobalVar(root.pluginId, key, val);
        }



        // 1. Connection Status Card
        Rectangle {
            width: parent.width
            height: statusCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: statusCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingM
                    DankIcon { 
                        name: PhoneConnectService.available ? "check_circle" : "error"
                        size: 22
                        color: PhoneConnectService.available ? Theme.success : Theme.error
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Column {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Theme.spacingXXS
                        StyledText { 
                            text: PhoneConnectService.available ? (serviceName + " Running") : "No Backend Running"
                            font.weight: Font.Medium
                            color: Theme.surfaceText 
                        }
                        StyledText { 
                            text: PhoneConnectService.available ? ("Announced as: " + PhoneConnectService.announcedName + " (" + PhoneConnectService.selfId + ")") : "Please start kdeconnectd or Valent"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText 
                            width: parent.width
                            wrapMode: Text.WordWrap
                        }
                    }
                    DankButton {
                        visible: PhoneConnectService.available
                        text: "Refresh"
                        iconName: "refresh"
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: PhoneConnectService.refreshDevices()
                    }
                }

                // Device List inside status card
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length > 0

                    StyledText {
                        text: "Paired Devices"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.surfaceText
                    }

                    Repeater {
                        model: PhoneConnectService.deviceIds

                        Rectangle {
                            required property string modelData
                            readonly property var device: PhoneConnectService.getDevice(modelData)

                            width: parent.width
                            height: deviceRow.implicitHeight + Theme.spacingS * 2
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh
                            border.color: Theme.withAlpha(Theme.outline, 0.15)
                            border.width: 1

                            Row {
                                id: deviceRow
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.spacingS
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
                }

                StyledText {
                    visible: PhoneConnectService.available && PhoneConnectService.deviceIds.length === 0
                    text: "No devices found. Pair a device using KDE Connect settings."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
        }

        // 2. Folder Configuration Card
        Rectangle {
            id: folderConfigRect
            width: parent.width
            height: folderConfigCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: folderConfigCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                // Custom Phone Image Setting
                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "image"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Custom Phone Image"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Custom image to display for the phone model in CC."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: customImageField
                            Layout.fillWidth: true
                            placeholderText: "Absolute path or URL"
                            Component.onCompleted: {
                                text = mainSettingsCol.loadValue("customPhoneImage", "")
                            }
                            onEditingFinished: {
                                mainSettingsCol.saveValue("customPhoneImage", text)
                            }
                        }

                        DankButton {
                            iconName: "folder"
                            text: "Browse"
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: imageBrowser.open()
                        }
                    }
                }

                // Recent Images Folder Setting
                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "folder"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Recent Images Path"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Directory to monitor for quick media sharing."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingS

                        DankTextField {
                            id: recentImagesPathField
                            Layout.fillWidth: true
                            placeholderText: "e.g. ~/Pictures or ~/Screenshots"
                            Component.onCompleted: {
                                text = mainSettingsCol.loadValue("recentImagesPath", "")
                            }
                            onEditingFinished: {
                                mainSettingsCol.saveValue("recentImagesPath", text)
                            }
                        }

                        DankButton {
                            iconName: "folder"
                            text: "Browse"
                            Layout.alignment: Qt.AlignVCenter
                            onClicked: recentImagesBrowser.open()
                        }
                    }
                }
            }
        }

        // 3. Limits & Recent Images Customization Card
        Rectangle {
            id: limitRect
            width: parent.width
            height: limitsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: limitsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "photo_library"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Recent Images"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of recent images to display in the popout."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            id: limitResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: limitResetMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: limitResetMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1
                            opacity: limitSlider.value !== limitSlider.defaultValue ? (limitResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: limitResetMa.containsMouse ? 1.1 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                            DankRipple { 
                                id: limitRip
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                rippleColor: Theme.primary 
                            }

                            DankIcon {
                                name: "restart_alt"
                                size: 18
                                anchors.centerIn: parent
                                color: limitResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                rotation: limitResetMa.containsMouse ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: limitResetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    limitResetAnim.restart();
                                    mainSettingsCol.saveValue(limitSlider.settingKey, limitSlider.defaultValue);
                                }
                                onPressed: function(m) { limitRip.trigger(m.x, m.y) }
                            }
                        }
                    }

                    NumberAnimation {
                        id: limitResetAnim
                        target: limitSlider
                        property: "value"
                        to: limitSlider.defaultValue
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                    DankSlider {
                        id: limitSlider
                        property int defaultValue: 4
                        property string settingKey: "maxRecentImages"
                        width: parent.width
                        minimum: 1
                        maximum: 12
                        step: 1
                        unit: " images"
                        
                        function loadValue() {
                            value = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: {
                            value = newValue;
                            mainSettingsCol.saveValue(settingKey, newValue);
                        }
                    }
                }
            }
        }

        // 4. Quick Actions Description Card
        Rectangle {
            width: parent.width
            height: actionsCol.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: actionsCol
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingXXS
                    StyledText { text: "Quick Actions Guide"; font.weight: Font.Medium; color: Theme.surfaceText }
                    StyledText { text: "Actions available in the popout for paired devices:"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "phone_in_talk"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "Ring - Make your phone ring to find it"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "notifications_active"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "Ping - Send a notification to the device"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "content_paste"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "Clipboard - Send clipboard to the device"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "share"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "Share - Send URLs or text to the device"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "folder"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "Browse - Open device file browser (SFTP)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                    Row {
                        spacing: Theme.spacingS
                        DankIcon { name: "sms"; size: 16; color: Theme.surfaceVariantText }
                        StyledText { text: "SMS - Send text messages or open SMS app"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                    }
                }
            }
        }

        // Requirements info (Simple footer)
        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "Requirements:"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: "• DMS daemon version 1.4 or higher\n• KDE Connect (kdeconnectd) or Valent\n• KDE Connect app on your mobile device"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }
        }
    }

    FileBrowserSurfaceModal {
        id: imageBrowser
        browserTitle: "Select Custom Phone Image"
        browserIcon: "image"
        browserType: "generic"
        showHiddenFiles: false
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        
        onFileSelected: function(path) {
            customImageField.text = "file://" + path
            mainSettingsCol.saveValue("customPhoneImage", "file://" + path)
        }
    }

    FileBrowserSurfaceModal {
        id: recentImagesBrowser
        browserTitle: "Select Recent Images Folder"
        browserIcon: "folder"
        browserType: "folder"
        showHiddenFiles: false
        
        onFileSelected: function(path) {
            recentImagesPathField.text = path
            mainSettingsCol.saveValue("recentImagesPath", path)
        }
    }
}
