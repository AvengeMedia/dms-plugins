import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

Column {
    id: root

    spacing: Theme.spacingM

    // --- Inline metric card component ---
    component MetricCard: Rectangle {
        id: card

        property string label: ""
        property string icon: ""
        property real value: 0
        property int threshold: 85
        property string unit: "%"
        property string subtitle: ""

        readonly property color cardColor: {
            if (value >= threshold + 10) return "#F44336";
            if (value >= threshold - 10) return "#FF9800";
            return Theme.primary;
        }

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingXS

            Row {
                spacing: Theme.spacingXS

                DankIcon {
                    name: card.icon
                    color: card.cardColor
                    size: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: card.label
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: card.value.toFixed(0) + card.unit
                font.pixelSize: 28
                font.weight: Font.Bold
                color: card.cardColor
            }

            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.surfaceVariant

                Rectangle {
                    width: Math.min(parent.width, parent.width * (card.value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: card.cardColor

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                    }
                }
            }

            StyledText {
                text: card.subtitle
                visible: card.subtitle.length > 0
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    // --- Tab bar ---
    DankTabBar {
        id: tabBar
        width: parent.width - Theme.spacingM * 2
        anchors.horizontalCenter: parent.horizontalCenter
        currentIndex: 0
        model: [
            { text: "Overview",  icon: "monitor_heart" },
            { text: "Processes", icon: "memory"         },
            { text: "Logs",      icon: "article"        },
            { text: "AI Doctor", icon: "smart_toy"      }
        ]
        onTabClicked: index => { tabBar.currentIndex = index; }
    }

    // ─────────────────────────────────────────────
    // TAB 0 — Overview
    // ─────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 0
        width: parent.width
        height: parent.height - tabBar.height - Theme.spacingM * 2

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            // Health banner
            Rectangle {
                width: parent.width
                height: 48
                radius: Theme.cornerRadius
                color: {
                    var s = SystemDoctorService.healthScore;
                    if (s >= 80) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15);
                    if (s >= 50) return Qt.rgba(1, 0.6, 0, 0.15);
                    return Qt.rgba(0.96, 0.26, 0.21, 0.15);
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingS

                    DankIcon {
                        name: SystemDoctorService.healthIcon
                        color: {
                            var s = SystemDoctorService.healthScore;
                            if (s >= 80) return Theme.primary;
                            if (s >= 50) return "#FF9800";
                            return "#F44336";
                        }
                        size: 22
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "System Health: " + SystemDoctorService.healthLabel
                              + "  (" + SystemDoctorService.healthScore + "/100)"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.DemiBold
                        color: {
                            var s = SystemDoctorService.healthScore;
                            if (s >= 80) return Theme.primary;
                            if (s >= 50) return "#FF9800";
                            return "#F44336";
                        }
                    }
                }
            }

            // Metric cards grid
            GridLayout {
                width: parent.width
                height: parent.height - 48 - Theme.spacingM
                columns: 2
                columnSpacing: Theme.spacingM
                rowSpacing: Theme.spacingM

                MetricCard {
                    label: "CPU Usage"
                    icon: "memory"
                    value: SystemDoctorService.cpuPct
                    threshold: SystemDoctorService.cpuThreshold
                    subtitle: "Threshold: " + SystemDoctorService.cpuThreshold + "%"
                }

                MetricCard {
                    label: "RAM Usage"
                    icon: "storage"
                    value: SystemDoctorService.ramPct
                    threshold: SystemDoctorService.ramThreshold
                    subtitle: SystemDoctorService.formatMb(SystemDoctorService.ramUsedMb)
                              + " / " + SystemDoctorService.formatMb(SystemDoctorService.ramTotalMb)
                }

                MetricCard {
                    label: "Disk ( / )"
                    icon: "hard_drive"
                    value: SystemDoctorService.diskPct
                    threshold: SystemDoctorService.diskThreshold
                    subtitle: "Threshold: " + SystemDoctorService.diskThreshold + "%"
                }

                MetricCard {
                    label: "Temperature"
                    icon: "thermostat"
                    value: SystemDoctorService.tempC > 0 ? SystemDoctorService.tempC : 0
                    threshold: 80
                    unit: "°C"
                    subtitle: SystemDoctorService.tempC < 0 ? "No sensor data" : ""
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // TAB 1 — Processes
    // ─────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 1
        width: parent.width
        height: parent.height - tabBar.height - Theme.spacingM * 2

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // Header row
            Row {
                width: parent.width
                height: 28
                spacing: 0

                StyledText {
                    width: parent.width * 0.38
                    text: "Command"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width * 0.15
                    text: "PID"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width * 0.22
                    text: "CPU %"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width * 0.15
                    text: "RAM %"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }
                StyledText {
                    width: parent.width * 0.10
                    text: "User"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceVariant
            }

            Flickable {
                width: parent.width
                height: parent.height - 29 - Theme.spacingS - 1
                contentHeight: procColumn.implicitHeight
                clip: true

                Column {
                    id: procColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: SystemDoctorService.topProcs

                        Rectangle {
                            id: procRow
                            required property var modelData
                            required property int index

                            width: procColumn.width
                            height: 36
                            radius: 6
                            color: index % 2 === 0 ? "transparent" : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                StyledText {
                                    width: parent.width * 0.38
                                    text: procRow.modelData.cmd
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    width: parent.width * 0.15
                                    text: procRow.modelData.pid
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // CPU bar + value
                                Item {
                                    width: parent.width * 0.22
                                    height: parent.height
                                    anchors.verticalCenter: parent.verticalCenter

                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingXS

                                        Rectangle {
                                            width: 60
                                            height: 6
                                            radius: 3
                                            color: Theme.surfaceVariant
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: Math.min(parent.width, parent.width * (procRow.modelData.cpu / 100))
                                                height: parent.height
                                                radius: parent.radius
                                                color: procRow.modelData.cpu > 50 ? "#F44336" : procRow.modelData.cpu > 25 ? "#FF9800" : Theme.primary
                                            }
                                        }

                                        StyledText {
                                            text: procRow.modelData.cpu.toFixed(1)
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }

                                StyledText {
                                    width: parent.width * 0.15
                                    text: procRow.modelData.mem.toFixed(1)
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    width: parent.width * 0.10
                                    text: procRow.modelData.user
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    elide: Text.ElideRight
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // TAB 2 — Logs
    // ─────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 2
        width: parent.width
        height: parent.height - tabBar.height - Theme.spacingM * 2

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                DankIcon {
                    name: "article"
                    color: SystemDoctorService.logErrors.length > 0 ? "#FF9800" : Theme.primary
                    size: 18
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemDoctorService.logErrors.length > 0
                          ? SystemDoctorService.logErrors.length + " error entries (journalctl -p err)"
                          : "No errors found in recent journal"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: SystemDoctorService.logErrors.length > 0 ? "#FF9800" : Theme.primary
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.surfaceVariant
            }

            Flickable {
                width: parent.width
                height: parent.height - 20 - Theme.spacingS * 2 - 1
                contentHeight: logColumn.implicitHeight
                clip: true

                Column {
                    id: logColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: SystemDoctorService.logErrors

                        Rectangle {
                            id: logEntry
                            required property string modelData
                            required property int index

                            width: logColumn.width
                            height: logText.implicitHeight + Theme.spacingXS * 2
                            radius: 4
                            color: index % 2 === 0 ? "transparent"
                                                   : Qt.rgba(Theme.surfaceVariant.r, Theme.surfaceVariant.g, Theme.surfaceVariant.b, 0.3)

                            StyledText {
                                id: logText
                                text: logEntry.modelData
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.spacingXS
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: Theme.surfaceText
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: SystemDoctorService.logErrors.length === 0 ? 60 : 0
                        visible: SystemDoctorService.logErrors.length === 0
                        color: "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "No recent errors"
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // TAB 3 — AI Doctor
    // ─────────────────────────────────────────────
    AiPanel {
        visible: tabBar.currentIndex === 3
        width: parent.width
        height: parent.height - tabBar.height - Theme.spacingM * 2
    }
}
