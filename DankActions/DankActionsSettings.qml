import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankActions"

    property string editingVariantId: ""

    function loadVariantForEditing(variantData) {
        editingVariantId = variantData.id || "";
        nameField.text = variantData.name || "";
        iconField.text = variantData.icon || "";
        displayTextField.text = variantData.displayText || "";
        displayCommandField.text = variantData.displayCommand || "";
        clickCommandField.text = variantData.clickCommand || "";
        middleClickCommandField.text = variantData.middleClickCommand || "";
        rightClickCommandField.text = variantData.rightClickCommand || "";
        updateIntervalField.text = (variantData.updateInterval || 0).toString();
        showIconToggle.checked = variantData.showIcon !== undefined ? variantData.showIcon : true;
        showTextToggle.checked = variantData.showText !== undefined ? variantData.showText : true;
        visibilityCommandField.text = variantData.visibilityCommand || "";
        visibilityIntervalField.text = (variantData.visibilityInterval || 0).toString();
    }

    function clearForm() {
        editingVariantId = "";
        nameField.text = "";
        iconField.text = "";
        displayTextField.text = "";
        displayCommandField.text = "";
        clickCommandField.text = "";
        middleClickCommandField.text = "";
        rightClickCommandField.text = "";
        updateIntervalField.text = "0";
        showIconToggle.checked = true;
        showTextToggle.checked = true;
        visibilityCommandField.text = "";
        visibilityIntervalField.text = "0";
    }

    StyledText {
        width: parent.width
        text: "Custom Action Manager"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Create custom widgets that execute commands and display dynamic output"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: addActionColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: addActionColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: root.editingVariantId ? "Edit Action" : "Create New Action"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankButton {
                    text: "Cancel"
                    iconName: "close"
                    visible: root.editingVariantId !== ""
                    onClicked: root.clearForm()
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Variant Name *"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: nameField
                        width: parent.width
                        placeholderText: "e.g., Power Profile"
                        keyNavigationTab: iconField
                        onFocusStateChanged: function(hasFocus) {
                            if (hasFocus)
                                root.ensureItemVisible(nameField);
                        }
                    }
                }

                Column {
                    width: (parent.width - Theme.spacingM) / 2
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Icon Name"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankTextField {
                        id: iconField
                        width: parent.width
                        placeholderText: "e.g., power_settings_new"
                        keyNavigationBacktab: nameField
                        keyNavigationTab: displayTextField
                        onFocusStateChanged: function(hasFocus) {
                            if (hasFocus)
                                root.ensureItemVisible(iconField);
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Static Display Text (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: displayTextField
                    width: parent.width
                    placeholderText: "Text to show (or leave empty if using command output)"
                    keyNavigationBacktab: iconField
                    keyNavigationTab: displayCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(displayTextField);
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Display Command (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: displayCommandField
                    width: parent.width
                    placeholderText: 'e.g., echo "Hello World" or powerprofilesctl get'
                    keyNavigationBacktab: displayTextField
                    keyNavigationTab: clickCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(displayCommandField);
                    }
                }

                StyledText {
                    text: "Command output will replace static text. Runs on widget load."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Left Click Command (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: clickCommandField
                    width: parent.width
                    placeholderText: "e.g., notify-send 'Clicked!' or cycle-power-profile.sh"
                    keyNavigationBacktab: displayCommandField
                    keyNavigationTab: middleClickCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(clickCommandField);
                    }
                }

                StyledText {
                    text: "Command to run on left click. After completion, display command refreshes."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Middle Click Command (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: middleClickCommandField
                    width: parent.width
                    placeholderText: "e.g., notify-send 'Middle clicked!'"
                    keyNavigationBacktab: clickCommandField
                    keyNavigationTab: rightClickCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(middleClickCommandField);
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Right Click Command (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: rightClickCommandField
                    width: parent.width
                    placeholderText: "e.g., notify-send 'Right clicked!'"
                    keyNavigationBacktab: middleClickCommandField
                    keyNavigationTab: updateIntervalField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(rightClickCommandField);
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Update Interval (seconds, 0 = disabled)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: updateIntervalField
                    width: parent.width
                    placeholderText: "0"
                    text: "0"
                    keyNavigationBacktab: rightClickCommandField
                    keyNavigationTab: visibilityCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(updateIntervalField);
                    }
                }

                StyledText {
                    text: "Automatically re-run display command every N seconds. Set to 0 to disable."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Visibility Condition (optional)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: visibilityCommandField
                    width: parent.width
                    placeholderText: "e.g., pgrep -x firefox (exit 0 = show, non-zero = hide)"
                    keyNavigationBacktab: updateIntervalField
                    keyNavigationTab: visibilityIntervalField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(visibilityCommandField);
                    }
                }

                StyledText {
                    text: "Widget shows when command exits 0, hides when non-zero."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS

                StyledText {
                    text: "Visibility Check Interval (seconds, 0 = once on load)"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankTextField {
                    id: visibilityIntervalField
                    width: parent.width
                    placeholderText: "0"
                    text: "0"
                    keyNavigationBacktab: visibilityCommandField
                    onFocusStateChanged: function(hasFocus) {
                        if (hasFocus)
                            root.ensureItemVisible(visibilityIntervalField);
                    }
                }

                StyledText {
                    text: "How often to re-check visibility condition. Set to 0 to check only once."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingL

                Column {
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Show Icon"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankToggle {
                        id: showIconToggle
                        checked: true
                        onToggled: function(isChecked) {
                            checked = isChecked;
                        }
                    }
                }

                Column {
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "Show Text"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                    }

                    DankToggle {
                        id: showTextToggle
                        checked: true
                        onToggled: function(isChecked) {
                            checked = isChecked;
                        }
                    }
                }
            }

            DankButton {
                text: root.editingVariantId ? "Update Action" : "Create Action"
                iconName: root.editingVariantId ? "check" : "add"
                onClicked: {
                    if (!nameField.text) {
                        ToastService.showError("Please enter a variant name");
                        return;
                    }

                    var interval = parseInt(updateIntervalField.text) || 0;
                    if (interval < 0) {
                        ToastService.showError("Update interval must be 0 or greater");
                        return;
                    }

                    var visInterval = parseInt(visibilityIntervalField.text) || 0;
                    if (visInterval < 0) {
                        ToastService.showError("Visibility interval must be 0 or greater");
                        return;
                    }

                    var variantConfig = {
                        icon: iconField.text || "terminal",
                        displayText: displayTextField.text || "",
                        displayCommand: displayCommandField.text || "",
                        clickCommand: clickCommandField.text || "",
                        middleClickCommand: middleClickCommandField.text || "",
                        rightClickCommand: rightClickCommandField.text || "",
                        updateInterval: interval,
                        showIcon: showIconToggle.checked,
                        showText: showTextToggle.checked,
                        visibilityCommand: visibilityCommandField.text || "",
                        visibilityInterval: visInterval
                    };

                    if (root.editingVariantId) {
                        variantConfig.name = nameField.text;
                        updateVariant(root.editingVariantId, variantConfig);
                    } else {
                        createVariant(nameField.text, variantConfig);
                    }

                    root.clearForm();
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: Math.max(200, variantsColumn.implicitHeight + Theme.spacingL * 2)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: variantsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Existing Actions"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ListView {
                width: parent.width
                height: Math.max(100, contentHeight)
                clip: true
                spacing: Theme.spacingXS

                model: root.variantsModel

                delegate: StyledRect {
                    required property var model
                    width: ListView.view.width
                    height: variantColumn.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: variantMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                    Column {
                        id: variantColumn
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingM

                            Item {
                                width: Theme.iconSize
                                height: Theme.iconSize
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: model.icon || "terminal"
                                    size: Theme.iconSize
                                    color: Theme.surfaceText
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                width: parent.width - Theme.iconSize - (editButton.width + deleteButton.width + Theme.spacingXS) - Theme.spacingM * 3

                                StyledText {
                                    text: model.name || "Unnamed"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: {
                                        var parts = [];
                                        if (model.displayText)
                                            parts.push("Text: " + model.displayText);
                                        if (model.displayCommand)
                                            parts.push("Cmd: " + model.displayCommand);
                                        if (model.updateInterval && model.updateInterval > 0)
                                            parts.push("Update: " + model.updateInterval + "s");
                                        if (model.visibilityCommand)
                                            parts.push("Vis: " + model.visibilityCommand);
                                        return parts.join(" | ") || "No display config";
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    text: {
                                        var actions = [];
                                        if (model.clickCommand)
                                            actions.push("L: " + model.clickCommand);
                                        if (model.middleClickCommand)
                                            actions.push("M: " + model.middleClickCommand);
                                        if (model.rightClickCommand)
                                            actions.push("R: " + model.rightClickCommand);
                                        return actions.join(" | ") || "No click actions";
                                    }
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXS

                                Rectangle {
                                    id: editButton
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: editArea.containsMouse ? Theme.primary : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "edit"
                                        size: 16
                                        color: editArea.containsMouse ? Theme.onPrimary : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: editArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.loadVariantForEditing(model);
                                        }
                                    }
                                }

                                Rectangle {
                                    id: deleteButton
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: deleteArea.containsMouse ? Theme.error : "transparent"

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "delete"
                                        size: 16
                                        color: deleteArea.containsMouse ? Theme.onError : Theme.surfaceVariantText
                                    }

                                    MouseArea {
                                        id: deleteArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            removeVariant(model.id);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: variantMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "No actions created yet"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    visible: variantsModel.count === 0
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: examplesColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: examplesColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "lightbulb"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: "Usage Examples"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    text: "• Power Profile Cycler"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                StyledText {
                    text: "Display: powerprofilesctl get\nClick: powerprofilesctl set $(powerprofilesctl list | grep -v \"$(powerprofilesctl get)\" | head -1)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "monospace"
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                    width: parent.width
                    leftPadding: Theme.spacingM
                }

                StyledText {
                    text: "• System Uptime"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                StyledText {
                    text: "Display: uptime -p | sed 's/up //'\nClick: notify-send \"Uptime\" \"$(uptime -p)\""
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "monospace"
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                    width: parent.width
                    leftPadding: Theme.spacingM
                }

                StyledText {
                    text: "• Custom Greeting"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                StyledText {
                    text: "Display: echo \"Hello $(whoami)!\"\nClick: notify-send \"Hi!\" \"Welcome back!\""
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "monospace"
                    color: Theme.surfaceVariantText
                    wrapMode: Text.Wrap
                    width: parent.width
                    leftPadding: Theme.spacingM
                }
            }

            StyledText {
                text: "After creating actions, add them to your bar from Bar Settings → Add Widget"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }
    }
}
