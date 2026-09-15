import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankLauncherKeys"

    property var availableProviders: []
    property var selectedProviders: []
    property bool _initialized: false

    Component.onCompleted: {
        loadAvailableProviders();
    }

    onPluginServiceChanged: {
        if (pluginService) {
            selectedProviders = loadValue("providers", []);
            if (selectedProviders.length === 0)
                selectedProviders = detectDefaultProviders();
            Qt.callLater(() => {
                _initialized = true;
            });
        }
    }

    function detectDefaultProviders() {
        if (CompositorService.isNiri)
            return ["niri"];
        if (CompositorService.isHyprland)
            return ["hyprland"];
        if (CompositorService.isSway)
            return ["sway"];
        return ["niri"];
    }

    function loadAvailableProviders() {
        providerListProcess.running = true;
    }

    Process {
        id: providerListProcess
        running: false
        command: ["dms", "keybinds", "list", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.availableProviders = JSON.parse(text).sort();
                } catch (e) {
                    console.error("[DankLauncherKeysSettings] Failed to parse providers:", e);
                    root.availableProviders = ["hyprland", "niri", "sway"];
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.availableProviders = ["hyprland", "niri", "sway"];
            }
        }
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("dankLauncherKeys", "Keybinds Search Settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("dankLauncherKeys", "Search keyboard shortcuts from your compositor and applications")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: triggerColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: triggerColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("dankLauncherKeys", "Activation")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                id: noTriggerToggle
                settingKey: "noTrigger"
                label: I18n.trFor("dankLauncherKeys", "Always Active")
                description: value ? I18n.trFor("dankLauncherKeys", "Keybinds shown alongside regular search results") : I18n.trFor("dankLauncherKeys", "Use trigger prefix to activate")
                defaultValue: false
                onValueChanged: {
                    if (!isInitialized)
                        return;
                    if (value)
                        root.saveValue("trigger", "");
                    else
                        root.saveValue("trigger", triggerSetting.value || "\\");
                }
            }

            StringSetting {
                id: triggerSetting
                visible: !noTriggerToggle.value
                settingKey: "trigger"
                label: I18n.trFor("dankLauncherKeys", "Trigger Prefix")
                description: I18n.trFor("dankLauncherKeys", "Type this prefix to search keybinds")
                placeholder: "\\"
                defaultValue: "\\"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: providersColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: providersColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("dankLauncherKeys", "Keybind Sources")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StyledText {
                text: I18n.trFor("dankLauncherKeys", "Select which keybind providers to include")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            DankButtonGroup {
                id: providerButtonGroup
                width: parent.width
                model: root.availableProviders
                selectionMode: "multi"
                initialSelection: root.selectedProviders
                currentSelection: root.selectedProviders
                buttonHeight: 32
                minButtonWidth: 48
                textSize: Theme.fontSizeSmall
                onSelectionChanged: {
                    if (!root._initialized)
                        return;
                    root.selectedProviders = currentSelection;
                    root.saveValue("providers", currentSelection);
                }
            }

            StyledText {
                visible: root.selectedProviders.length === 0
                text: I18n.trFor("dankLauncherKeys", "Select at least one provider")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
            }
        }
    }

    StyledRect {
        width: parent.width
        height: infoColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surface

        Column {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                spacing: Theme.spacingM

                DankIcon {
                    name: "info"
                    size: Theme.iconSize
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: I18n.trFor("dankLauncherKeys", "Usage Tips")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: I18n.trFor("dankLauncherKeys", "Search by key combo, description, or action name.\n\nDefault action copies the keybind to clipboard.\nRight-click or press Right Arrow to pin frequently used keybinds - they'll appear at the top when not searching.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
