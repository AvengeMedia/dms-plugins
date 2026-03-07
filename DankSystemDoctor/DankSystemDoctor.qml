import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 820
    popoutHeight: 560

    onPluginDataChanged: {
        SystemDoctorService.cpuThreshold = parseInt(pluginData.cpuThreshold) || 85;
        SystemDoctorService.ramThreshold = parseInt(pluginData.ramThreshold) || 85;
        SystemDoctorService.diskThreshold = parseInt(pluginData.diskThreshold) || 90;
        SystemDoctorService.setLogInterval(parseInt(pluginData.logInterval) || 30);
        SystemDoctorService.ollamaModel = pluginData.ollamaModel || "llama3.2";
    }

    popoutContent: Component {
        PopoutComponent {
            DankSystemDoctorPopout {
                width: popoutWidth
                height: popoutHeight - Theme.spacingS * 2
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            id: hPill
            spacing: Theme.spacingXS

            readonly property color pillColor: {
                var s = SystemDoctorService.healthScore;
                if (s >= 80) return Theme.primary;
                if (s >= 50) return "#FF9800";
                return "#F44336";
            }

            DankIcon {
                name: SystemDoctorService.healthIcon
                color: hPill.pillColor
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemDoctorService.healthScore + "%"
                font.pixelSize: Theme.fontSizeXLarge
                color: hPill.pillColor
            }
        }
    }

    verticalBarPill: Component {
        Column {
            id: vPill
            spacing: 2

            readonly property color pillColor: {
                var s = SystemDoctorService.healthScore;
                if (s >= 80) return Theme.primary;
                if (s >= 50) return "#FF9800";
                return "#F44336";
            }

            DankIcon {
                name: SystemDoctorService.healthIcon
                color: vPill.pillColor
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SystemDoctorService.healthScore + "%"
                font.pixelSize: Theme.fontSizeSmall
                color: vPill.pillColor
            }
        }
    }
}
