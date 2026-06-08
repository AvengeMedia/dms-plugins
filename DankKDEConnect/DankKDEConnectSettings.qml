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

        readonly property string selectedDeviceId: loadValue("selectedDeviceId", "")
        readonly property string targetDeviceId: selectedDeviceId || (PhoneConnectService.deviceIds.length > 0 ? PhoneConnectService.deviceIds[0] : "")
        readonly property var targetDevice: PhoneConnectService.getDevice(targetDeviceId)
        readonly property string targetDeviceName: targetDevice ? targetDevice.name : "Device 1"

        property var deviceTypeMap: ({})
        property var deviceImageMap: ({})

        function refreshDeviceTypeMap() {
            const rawMap = loadValue("deviceTypeMap", "");
            if (rawMap) {
                try {
                    deviceTypeMap = JSON.parse(rawMap);
                    return;
                } catch(e) {}
            }
            deviceTypeMap = {};
        }

        function refreshDeviceImageMap() {
            const rawMap = loadValue("deviceImageMap", "");
            if (rawMap) {
                try {
                    deviceImageMap = JSON.parse(rawMap);
                    return;
                } catch(e) {}
            }
            deviceImageMap = {};
        }

        Component.onCompleted: {
            refreshDeviceTypeMap();
            refreshDeviceImageMap();
        }

        Connections {
            target: PluginService
            ignoreUnknownSignals: true
            function onGlobalVarChanged(pluginId, varName) {
                if (pluginId === root.pluginId) {
                    if (varName === "deviceTypeMap") {
                        mainSettingsCol.refreshDeviceTypeMap();
                    } else if (varName === "deviceImageMap") {
                        mainSettingsCol.refreshDeviceImageMap();
                    }
                }
            }
            function onPluginDataChanged(pluginId) {
                if (pluginId === root.pluginId) {
                    mainSettingsCol.refreshDeviceTypeMap();
                    mainSettingsCol.refreshDeviceImageMap();
                }
            }
        }

        function getDeviceImage(deviceId) {
            if (!deviceId) return "";
            if (deviceImageMap[deviceId]) return deviceImageMap[deviceId];
            // Fallback to legacy single image if it's the first device
            if (PhoneConnectService.deviceIds.length > 0 && deviceId === PhoneConnectService.deviceIds[0]) {
                return loadValue("customPhoneImage", "");
            }
            return "";
        }

        function saveDeviceImage(deviceId, path) {
            if (!deviceId) return;
            let newMap = Object.assign({}, deviceImageMap);
            if (path === "" || path === null) {
                delete newMap[deviceId];
            } else {
                newMap[deviceId] = path;
            }
            deviceImageMap = newMap;
            saveValue("deviceImageMap", JSON.stringify(newMap));
        }

        function getDeviceRecentImagesPath(deviceId) {
            if (!deviceId) return "";
            const rawMap = loadValue("deviceRecentImagesPathMap", "");
            if (rawMap) {
                try {
                    const map = JSON.parse(rawMap);
                    if (map[deviceId]) return map[deviceId];
                } catch(e) {}
            }
            // Fallback to legacy single recentImagesPath if it's the first device
            if (PhoneConnectService.deviceIds.length > 0 && deviceId === PhoneConnectService.deviceIds[0]) {
                return loadValue("recentImagesPath", "");
            }
            return "";
        }

        function saveDeviceRecentImagesPath(deviceId, path) {
            if (!deviceId) return;
            let map = {};
            const rawMap = loadValue("deviceRecentImagesPathMap", "");
            if (rawMap) {
                try { map = JSON.parse(rawMap); } catch(e) {}
            }
            if (path === "" || path === null) {
                delete map[deviceId];
            } else {
                map[deviceId] = path;
            }
            const serialized = JSON.stringify(map);
            saveValue("deviceRecentImagesPathMap", serialized);
        }

        function getDeviceType(deviceId) {
            if (!deviceId) return "Phone";
            if (deviceTypeMap[deviceId]) {
                switch (deviceTypeMap[deviceId]) {
                case "phone": return "Phone";
                case "tablet": return "Tablet";
                case "laptop": return "Laptop";
                case "desktop": return "PC";
                }
            }
            // Fallback to real device type from service
            const dev = PhoneConnectService.getDevice(deviceId);
            if (dev && dev.type) {
                switch (dev.type) {
                case "phone":
                case "smartphone":
                    return "Phone";
                case "tablet":
                    return "Tablet";
                case "laptop":
                    return "Laptop";
                case "desktop":
                case "computer":
                    return "PC";
                }
            }
            return "Phone";
        }

        function saveDeviceType(deviceId, typeStr) {
            if (!deviceId) return;
            let typeVal = "";
            switch (typeStr) {
            case "Phone": typeVal = "phone"; break;
            case "Tablet": typeVal = "tablet"; break;
            case "Laptop": typeVal = "laptop"; break;
            case "PC": typeVal = "desktop"; break;
            }

            let newMap = Object.assign({}, deviceTypeMap);
            if (typeVal === "") {
                delete newMap[deviceId];
            } else {
                newMap[deviceId] = typeVal;
            }
            deviceTypeMap = newMap;
            saveValue("deviceTypeMap", JSON.stringify(newMap));
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

        // 2. Folder Configuration Cards (per paired device)
        Repeater {
            model: PhoneConnectService.deviceIds

            Rectangle {
                id: deviceSettingsRect
                required property string modelData
                required property int index

                readonly property var device: PhoneConnectService.getDevice(modelData)
                readonly property string deviceName: device ? device.name : modelData

                width: parent.width
                height: deviceSettingsCol.implicitHeight + Theme.spacingM * 2
                color: Theme.surfaceContainer
                radius: Theme.cornerRadius
                border.color: Theme.outline
                border.width: 1
                opacity: 0.8

                Column {
                    id: deviceSettingsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    // Device Header (similar to Recent Images Container title style in widget)
                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankIcon {
                            name: PhoneConnectService.getDeviceIcon(deviceSettingsRect.device)
                            size: 16
                            color: Theme.surfaceText
                        }

                        StyledText {
                            text: deviceSettingsRect.deviceName + " Settings"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            Layout.fillWidth: true
                        }
                    }

                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.15)
                    }

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
                                StyledText { text: "Custom Image"; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Custom image to display for this device model in Control Center & Widget Pop-Up."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankTextField {
                                id: customImageField
                                Layout.fillWidth: true
                                placeholderText: "Absolute path or URL"
                                text: mainSettingsCol.getDeviceImage(deviceSettingsRect.modelData)
                                onEditingFinished: {
                                    mainSettingsCol.saveDeviceImage(deviceSettingsRect.modelData, text)
                                }
                            }

                            RowLayout {
                                spacing: 1
                                Layout.alignment: Qt.AlignVCenter

                                // Browse Button Item
                                Item {
                                    id: browseBtnItem
                                    height: 36
                                    width: 96

                                    Rectangle {
                                        anchors.fill: parent
                                        topLeftRadius: Theme.cornerRadius
                                        bottomLeftRadius: Theme.cornerRadius
                                        topRightRadius: clearBtnContainer.isShown ? 0 : Theme.cornerRadius
                                        bottomRightRadius: clearBtnContainer.isShown ? 0 : Theme.cornerRadius

                                        color: browseMA.containsMouse 
                                            ? Theme.withAlpha(Theme.primary, 0.15) 
                                            : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                                        border.width: 1
                                        border.color: Theme.withAlpha(Theme.primary, browseMA.containsMouse ? 0.3 : 0.15)
                                    }

                                    DankRipple {
                                        anchors.fill: parent
                                        cornerRadius: Theme.cornerRadius
                                        rippleColor: Theme.primary
                                    }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXXS
                                        DankIcon {
                                            name: "folder"
                                            size: 16
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: "Browse"
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: Font.Medium
                                            color: Theme.primary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: browseMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            imageBrowser.targetDeviceId = deviceSettingsRect.modelData;
                                            imageBrowser.targetField = customImageField;
                                            imageBrowser.open();
                                        }
                                    }
                                }

                                // Animated container for Clear Button
                                Item {
                                    id: clearBtnContainer
                                    height: 36
                                    property bool isShown: customImageField.text !== ""
                                    width: isShown ? 88 : 0
                                    opacity: isShown ? 1.0 : 0.0
                                    scale: isShown ? 1.0 : 0.8
                                    clip: true

                                    Behavior on width {
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
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.shorterDuration
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Item {
                                        width: 88
                                        height: 36

                                        Rectangle {
                                            anchors.fill: parent
                                            topLeftRadius: 0
                                            bottomLeftRadius: 0
                                            topRightRadius: Theme.cornerRadius
                                            bottomRightRadius: Theme.cornerRadius

                                            color: clearMA.containsMouse 
                                                ? Theme.withAlpha(Theme.primary, 0.15) 
                                                : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                                            border.width: 1
                                            border.color: Theme.withAlpha(Theme.primary, clearMA.containsMouse ? 0.3 : 0.15)
                                        }

                                        DankRipple {
                                            anchors.fill: parent
                                            cornerRadius: Theme.cornerRadius
                                            rippleColor: Theme.primary
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingXXS
                                            DankIcon {
                                                name: "clear"
                                                size: 16
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: "Clear"
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.Medium
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: clearMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                customImageField.text = "";
                                                mainSettingsCol.saveDeviceImage(deviceSettingsRect.modelData, "");
                                            }
                                        }
                                    }
                                }
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
                                text: mainSettingsCol.getDeviceRecentImagesPath(deviceSettingsRect.modelData)
                                onEditingFinished: {
                                    mainSettingsCol.saveDeviceRecentImagesPath(deviceSettingsRect.modelData, text)
                                }
                            }

                            DankButton {
                                iconName: "folder"
                                text: "Browse"
                                Layout.alignment: Qt.AlignVCenter
                                onClicked: {
                                    recentImagesBrowser.targetDeviceId = deviceSettingsRect.modelData;
                                    recentImagesBrowser.targetField = recentImagesPathField;
                                    recentImagesBrowser.open();
                                }
                            }
                        }
                    }

                    // Device Type Override Dropdown
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM
                            DankIcon { name: "devices"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                            Column {
                                width: parent.width - 22 - Theme.spacingM
                                spacing: Theme.spacingXXS
                                StyledText { text: "Override Device Type"; font.weight: Font.Medium; color: Theme.surfaceText }
                                StyledText { text: "Select the type of device to override standard framing, icon, and layouts."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingS

                            DankDropdown {
                                id: deviceTypeDropdown
                                Layout.fillWidth: true
                                compactMode: true
                                dropdownWidth: 200
                                currentValue: mainSettingsCol.getDeviceType(deviceSettingsRect.modelData)
                                options: ["Phone", "Tablet", "Laptop", "PC"]
                                optionIcons: ["smartphone", "tablet", "laptop", "desktop_windows"]
                                onValueChanged: function(val) {
                                    mainSettingsCol.saveDeviceType(deviceSettingsRect.modelData, val);
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3. Limits & Appearance Card
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

                    DankToggle {
                        id: chargingAnimToggle
                        width: parent.width
                        text: "Show Charging Animation"
                        description: "Display a wavy green/yellow animation on the panel pill when the device is charging."
                        Component.onCompleted: {
                            checked = mainSettingsCol.loadValue("enableChargingAnimation", true);
                        }
                        onToggled: function(newChecked) {
                            checked = newChecked;
                            mainSettingsCol.saveValue("enableChargingAnimation", newChecked);
                        }
                    }

                    DankToggle {
                        id: clipboardActionToggle
                        width: parent.width
                        text: "Show Clipboard Quick Action"
                        description: "Show a top-level action button next to Ring and Browse for instantly sending the clipboard to your device."
                        Component.onCompleted: {
                            checked = mainSettingsCol.loadValue("enableClipboardAction", true);
                        }
                        onToggled: function(newChecked) {
                            checked = newChecked;
                            mainSettingsCol.saveValue("enableClipboardAction", newChecked);
                        }
                    }

                    DankToggle {
                        id: showOngoingMediaToggle
                        width: parent.width
                        text: "Show Ongoing Media"
                        description: "Show active media playing on your phone in the plugin dashboard."
                        Component.onCompleted: {
                            checked = mainSettingsCol.loadValue("showOngoingMedia", true);
                        }
                        onToggled: function(newChecked) {
                            checked = newChecked;
                            mainSettingsCol.saveValue("showOngoingMedia", newChecked);
                        }
                    }

                    DankToggle {
                        id: showDevicePlaceholderToggle
                        width: parent.width
                        text: "Show Device Image Placeholder"
                        description: "Show the device graphics representation or custom image in the device details."
                        Component.onCompleted: {
                            checked = mainSettingsCol.loadValue("showDevicePlaceholder", true);
                        }
                        onToggled: function(newChecked) {
                            checked = newChecked;
                            mainSettingsCol.saveValue("showDevicePlaceholder", newChecked);
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

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
                        wheelEnabled: false
                        
                        function loadValue() {
                            value = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: {
                            value = newValue;
                            mainSettingsCol.saveValue(settingKey, newValue);
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                wheel.accepted = false;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "sync"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "State Update Interval"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "How often to automatically update/refresh the plugin state (0 to disable)."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    DankSlider {
                        id: updateIntervalSlider
                        property int defaultValue: 30
                        property string settingKey: "stateUpdateInterval"
                        width: parent.width
                        minimum: 0
                        maximum: 300
                        step: 5
                        unit: value === 0 ? " (Disabled)" : " seconds"
                        wheelEnabled: false
                        
                        function loadValue() {
                            value = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: {
                            value = newValue;
                            mainSettingsCol.saveValue(settingKey, newValue);
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                wheel.accepted = false;
                            }
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
        property string targetDeviceId: ""
        property var targetField: null

        browserTitle: "Select Custom Phone Image"
        browserIcon: "image"
        browserType: "generic"
        showHiddenFiles: false
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        
        onFileSelected: function(path) {
            const urlPath = "file://" + path
            if (targetField) {
                targetField.text = urlPath
            }
            mainSettingsCol.saveDeviceImage(targetDeviceId, urlPath)
        }
    }

    FileBrowserSurfaceModal {
        id: recentImagesBrowser
        property string targetDeviceId: ""
        property var targetField: null

        browserTitle: "Select Recent Images Folder"
        browserIcon: "folder"
        browserType: "folder"
        showHiddenFiles: false
        
        onFileSelected: function(path) {
            if (targetField) {
                targetField.text = path
            }
            mainSettingsCol.saveDeviceRecentImagesPath(targetDeviceId, path)
        }
    }
}
