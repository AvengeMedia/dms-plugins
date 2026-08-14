import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankPomodoroTimer"

    StyledText {
        width: parent.width
        text: "Pomodoro Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure timer durations and behavior"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: durationsColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: durationsColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Durations"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            StringSetting {
                settingKey: "workDuration"
                label: "Work Duration (minutes)"
                description: "Length of each focus session"
                placeholder: "25"
                defaultValue: "25"
            }

            StringSetting {
                settingKey: "shortBreakDuration"
                label: "Short Break (minutes)"
                description: "Break after each pomodoro"
                placeholder: "5"
                defaultValue: "5"
            }

            StringSetting {
                settingKey: "longBreakDuration"
                label: "Long Break (minutes)"
                description: "Break after 4 pomodoros"
                placeholder: "15"
                defaultValue: "15"
            }
        }
    }

    StyledRect {
        width: parent.width
        height: behaviorColumn.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: behaviorColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Behavior"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
            }

            ToggleSetting {
                settingKey: "autoStartBreaks"
                label: "Auto-start Breaks"
                description: "Automatically start break timers after work sessions"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "autoStartPomodoros"
                label: "Auto-start Pomodoros"
                description: "Automatically start work sessions after breaks"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "autoSetDND"
                label: "Do Not Disturb Work"
                description: "Automatically enable Do Not Disturb mode during work sessions"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "playCompletionSound"
                label: "Play Completion Sound"
                description: "Play a sound when a work session or break ends"
                defaultValue: true
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
                    text: "About Pomodoro Technique"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: "The Pomodoro Technique uses 25-minute focused work sessions followed by short breaks. After 4 pomodoros, take a longer break to recharge.\n\n• Work: 25 minutes of focused work\n• Short Break: 5 minute rest\n• Long Break: 15 minutes after 4 pomodoros\n\nNotifications will alert you when each session completes."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
                width: parent.width
                lineHeight: 1.4
            }
        }
    }
}
