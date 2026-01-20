import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankNotepadMarkdown"

    StyledText {
        text: "Notepad Markdown & Syntax"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Enhance DMS Notepad with markdown preview and syntax highlighting for code files"
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
        text: "Markdown Preview"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enableMarkdownPreview"
        label: "Enable Markdown Preview"
        description: "Render markdown formatting in .md files (headers, bold, links, tables, etc.)"
        defaultValue: true
    }

    StyledText {
        text: "Supported: headers, bold, italic, links, images, code blocks, tables, task lists (CommonMark + GitHub extensions)"
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
        text: "Syntax Highlighting"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "enableSyntaxHighlighting"
        label: "Enable Syntax Highlighting"
        description: "Highlight code syntax in programming files (.py, .js, .go, etc.)"
        defaultValue: true
    }

    SelectionSetting {
        settingKey: "syntaxTheme"
        label: "Color Theme"
        description: "Choose the syntax highlighting color scheme"
        defaultValue: "monokai"
        options: [
            { value: "monokai", label: "Monokai" },
            { value: "dracula", label: "Dracula" },
            { value: "github", label: "GitHub" },
            { value: "github-dark", label: "GitHub Dark" },
            { value: "nord", label: "Nord" },
            { value: "onedark", label: "One Dark" },
            { value: "solarized-dark", label: "Solarized Dark" },
            { value: "solarized-light", label: "Solarized Light" },
            { value: "gruvbox", label: "Gruvbox" },
            { value: "catppuccin-mocha", label: "Catppuccin Mocha" },
            { value: "catppuccin-latte", label: "Catppuccin Latte" },
            { value: "doom-one", label: "Doom One" }
        ]
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Supported Languages"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Python, JavaScript, TypeScript, Go, Rust, C/C++, Java, Kotlin, Ruby, PHP, Shell, SQL, HTML, CSS, JSON, YAML, QML, and 400+ more languages via Chroma"
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
        text: "How It Works"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "• Markdown preview uses Qt's built-in CommonMark renderer\n• Syntax highlighting runs via 'dms chroma' when you switch tabs or load files\n• Highlighting is event-driven (no timers) for optimal performance"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }
}
