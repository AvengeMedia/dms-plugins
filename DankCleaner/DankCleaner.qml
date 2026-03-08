import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    popoutWidth: 860
    popoutHeight: 580

    onPluginDataChanged: {
        CleanerService.cleanupCache = pluginData.cleanupCache !== false;
        CleanerService.cleanupTrash = pluginData.cleanupTrash !== false;
        CleanerService.cleanupBrowserCache = pluginData.cleanupBrowserCache !== false;
        CleanerService.cleanupTmp = pluginData.cleanupTmp === true;
        CleanerService.tmpAgeDays = parseInt(pluginData.tmpAgeDays) || 3;
        CleanerService.largeFileThresholdMb = parseInt(pluginData.largeFileThresholdMb) || 100;
        CleanerService.largeFilePaths = pluginData.largeFilePaths || "~/Downloads\n~/Videos\n~/Documents";
        CleanerService.diskAnalyzerPaths = pluginData.diskAnalyzerPaths || CleanerService.largeFilePaths;
        CleanerService.excludePatterns = pluginData.excludePatterns || "";
        CleanerService.refreshAll();
    }

    popoutContent: Component {
        PopoutComponent {
            DankCleanerPopout {
                width: popoutWidth
                height: popoutHeight - Theme.spacingS * 2
            }
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: CleanerService.running ? "hourglass_top" : "cleaning_services"
                color: CleanerService.running ? "#FF9800" : Theme.primary
                size: root.iconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: CleanerService.running ? "Scanning..." : CleanerService.totalCleanupLabel
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2

            DankIcon {
                name: CleanerService.running ? "hourglass_top" : "cleaning_services"
                color: CleanerService.running ? "#FF9800" : Theme.primary
                size: root.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: CleanerService.running ? "..." : CleanerService.totalCleanupShort
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeXSmall
            }
        }
    }
}
