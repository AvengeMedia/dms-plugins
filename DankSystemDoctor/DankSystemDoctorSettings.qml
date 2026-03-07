import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankSystemDoctor"

    // Header
    StyledText {
        text: "System Doctor"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Tracks CPU, RAM, disk & temp in real-time. AI diagnostics and one-click fixes via Ollama."
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

    // ── AI Configuration ──────────────────────────
    StyledText {
        text: "AI Configuration"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "ollamaModel"
        label: "Ollama Model"
        description: "Model name to use for diagnostics (must be pulled in Ollama)"
        placeholder: "llama3.2"
        defaultValue: "llama3.2"
    }

    StyledRect {
        width: parent.width
        height: modelsCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: modelsCol
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingXS

            StyledText {
                text: "Recommended models"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceText
                width: parent.width
            }

            StyledText { text: ">  llama3.2       — Best balance of speed and quality (default)"; font.pixelSize: Theme.fontSizeSmall; font.family: "monospace"; color: Theme.surfaceVariantText; width: parent.width }
            StyledText { text: ">  llama3.2:1b    — Fastest, lower quality";                     font.pixelSize: Theme.fontSizeSmall; font.family: "monospace"; color: Theme.surfaceVariantText; width: parent.width }
            StyledText { text: ">  mistral        — Good for technical diagnostics";              font.pixelSize: Theme.fontSizeSmall; font.family: "monospace"; color: Theme.surfaceVariantText; width: parent.width }
            StyledText { text: ">  deepseek-r1:7b — Strong reasoning for complex issues";        font.pixelSize: Theme.fontSizeSmall; font.family: "monospace"; color: Theme.surfaceVariantText; width: parent.width }
            StyledText { text: ">  phi4           — Small but capable";                          font.pixelSize: Theme.fontSizeSmall; font.family: "monospace"; color: Theme.surfaceVariantText; width: parent.width }

            Item { width: 1; height: Theme.spacingXS }

            DankButton {
                text: "Test Ollama Connection"
                iconName: "wifi_find"
                width: parent.width
                onClicked: {
                    Quickshell.execDetached(["bash", "-c",
                        "curl -sf http://localhost:11434/api/tags > /dev/null 2>&1 " +
                        "&& dms notify 'Ollama Connected' 'Ollama is running and ready.' --icon smart_toy " +
                        "|| dms notify 'Ollama Offline' 'Start it with: ollama serve' --icon error"
                    ]);
                }
            }
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── Thresholds ────────────────────────────────
    StyledText {
        text: "Alert Thresholds"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        text: "Health score drops and bar icon turns orange/red when usage exceeds these values."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    SliderSetting {
        settingKey: "cpuThreshold"
        label: "CPU Threshold"
        description: "CPU usage % above which health score is penalised"
        defaultValue: 85
        minimum: 40
        maximum: 98
        unit: "%"
        rightIcon: "memory"
    }

    SliderSetting {
        settingKey: "ramThreshold"
        label: "RAM Threshold"
        description: "RAM usage % above which health score is penalised"
        defaultValue: 85
        minimum: 40
        maximum: 98
        unit: "%"
        rightIcon: "storage"
    }

    SliderSetting {
        settingKey: "diskThreshold"
        label: "Disk Threshold"
        description: "Disk usage % above which health score is penalised"
        defaultValue: 90
        minimum: 50
        maximum: 99
        unit: "%"
        rightIcon: "hard_drive"
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── Polling Intervals ─────────────────────────
    StyledText {
        text: "Polling Intervals"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "logInterval"
        label: "Log Check Interval"
        description: "How often to query journalctl for new errors"
        defaultValue: 30
        minimum: 10
        maximum: 120
        unit: "s"
        rightIcon: "article"
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    // ── Quick Actions ─────────────────────────────
    StyledText {
        text: "Quick Actions"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: actionsCol.implicitHeight + Theme.spacingL
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: actionsCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            DankButton {
                text: "Force Metrics Refresh"
                iconName: "refresh"
                width: parent.width
                onClicked: SystemDoctorService.refreshMetrics()
            }

            DankButton {
                text: "Force Log Refresh"
                iconName: "sync"
                width: parent.width
                onClicked: SystemDoctorService.refreshLogs()
            }

            DankButton {
                text: "Clear Journal Cache (user-level)"
                iconName: "delete_sweep"
                width: parent.width
                onClicked: {
                    Quickshell.execDetached(["bash", "-c",
                        "journalctl --user --vacuum-size=50M && " +
                        "dms notify 'Journal Cleared' 'User journal vacuumed to 50 MB.' --icon delete_sweep"
                    ]);
                }
            }

            DankButton {
                text: "Clear System Journal (root)"
                iconName: "admin_panel_settings"
                width: parent.width
                onClicked: {
                    Quickshell.execDetached(["pkexec", "bash", "-c",
                        "journalctl --vacuum-size=200M && " +
                        "dms notify 'System Journal Cleared' 'System journal vacuumed to 200 MB.' --icon delete_sweep"
                    ]);
                }
            }
        }
    }

    StyledText {
        text: "Metrics are collected every 5 seconds automatically. Logs are polled on the interval set above."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }
}
