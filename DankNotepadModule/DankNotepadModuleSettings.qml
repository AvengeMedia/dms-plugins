import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "dankNotepadModule"

    property var availableThemes: []

    Component.onCompleted: {
        loadAvailableThemes();
    }

    function loadAvailableThemes() {
        const process = Qt.createQmlObject(`import QtQuick; import Quickshell.Io; Process {
                command: ["dms", "chroma", "list-styles"]
                running: true
                stdout: StdioCollector { }
            }`, root, "themeLoader");

        if (!process) {
            console.warn("Failed to create theme loader process, using fallback themes");
            availableThemes = ["github-dark", "monokai", "dracula", "github", "nord", "onedark", "solarized-dark", "solarized-light"];
            return;
        }

        process.stdout.streamFinished.connect(() => {
            const output = process.stdout.text;
            const themes = output.trim().split('\n').filter(t => t.length > 0);
            availableThemes = themes.length > 0 ? themes : ["github-dark", "monokai", "dracula", "github", "nord", "onedark", "solarized-dark", "solarized-light"];
            process.destroy();
        });
    }

    Column {
        width: parent.width
        spacing: Theme.spacingL

        StyledText {
            text: "Notepad Module"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
        }

        StyledText {
            text: "Inline preview and chroma-based syntax highlighting for Notepad."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        SelectionSetting {
            settingKey: "style"
            label: I18n.trFor("dankNotepadModule", "Chroma Style")
            description: availableThemes.length > 0 ? I18n.trFor("dankNotepadModule", "Color theme for syntax highlighting. %1 themes available.").arg(availableThemes.length) : I18n.trFor("dankNotepadModule", "Color theme for syntax highlighting.")
            options: availableThemes.map(theme => ({
                        label: theme,
                        value: theme
                    }))
            defaultValue: "github-dark"
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        StyledText {
            text: "Preview is toggled from Notepad (off → split → full)."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceTextMedium
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outlineVariant
        }

        // About
        Column {
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                width: parent.width
                text: "About"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.DemiBold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "Notepad Syntax Module v1.0.0\n\nAdds markdown/HTML rendering and syntax highlighting to the Notepad module. View your notes in multiple formats: Markdown (rendered), HTML (raw), or plain text."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.WordWrap
                lineHeight: 1.4
            }
        }

        Item {
            width: parent.width
            height: Theme.spacingL
        }
    }

    function saveValue(key, value) {
        if (pluginService) {
            pluginService.savePluginData(root.pluginId, key, value);
        }
    }

    function loadValue(key, defaultValue) {
        if (pluginService) {
            return pluginService.loadPluginData(root.pluginId, key, defaultValue);
        }
        return defaultValue;
    }
}
