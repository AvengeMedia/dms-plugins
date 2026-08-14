import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "AnsiParser.js" as AnsiParser

PluginComponent {
    id: root

    property string variantId: ""
    property var variantData: null

    property string displayIcon: "terminal"
    property string displayText: ""
    property string displayCommand: ""
    property string clickCommand: ""
    property string middleClickCommand: ""
    property string rightClickCommand: ""
    property int updateInterval: 0
    property bool showIcon: true
    property bool showText: true

    property string currentOutput: ""
    property bool isLoading: false

    visibilityCommand: variantData?.visibilityCommand || ""
    visibilityInterval: variantData?.visibilityInterval || 0

    onVariantDataChanged: {
        updatePropertiesFromVariantData();
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === "dankActions" && variantId) {
                const newData = PluginService.getPluginVariantData("dankActions", variantId);
                if (newData) {
                    variantData = newData;
                }
            }
        }
    }

    function updatePropertiesFromVariantData() {
        if (!variantData) {
            displayIcon = "terminal";
            displayText = "";
            displayCommand = "";
            clickCommand = "";
            middleClickCommand = "";
            rightClickCommand = "";
            updateInterval = 0;
            showIcon = true;
            showText = true;
            currentOutput = "";
            return;
        }

        displayIcon = variantData.icon || "terminal";
        displayText = variantData.displayText || "";
        displayCommand = variantData.displayCommand || "";
        clickCommand = variantData.clickCommand || "";
        middleClickCommand = variantData.middleClickCommand || "";
        rightClickCommand = variantData.rightClickCommand || "";
        updateInterval = variantData.updateInterval || 0;
        showIcon = variantData.showIcon !== undefined ? variantData.showIcon : true;
        showText = variantData.showText !== undefined ? variantData.showText : true;

        if (displayCommand) {
            Qt.callLater(refreshOutput);
        } else {
            currentOutput = AnsiParser.parseAnsiToHtml(displayText);
        }
        if (updateInterval > 0) {
            updateTimer.restart();
        }
    }

    onDisplayCommandChanged: {
        if (displayCommand) {
            Qt.callLater(refreshOutput);
        } else {
            currentOutput = AnsiParser.parseAnsiToHtml(displayText);
        }
    }

    onDisplayTextChanged: {
        if (!displayCommand) {
            currentOutput = AnsiParser.parseAnsiToHtml(displayText);
        }
    }

    onUpdateIntervalChanged: {
        if (updateInterval > 0) {
            updateTimer.restart();
        } else {
            updateTimer.stop();
        }
    }

    Component.onCompleted: {
        if (displayCommand) {
            Qt.callLater(refreshOutput);
        } else {
            currentOutput = AnsiParser.parseAnsiToHtml(displayText);
        }
        if (updateInterval > 0) {
            updateTimer.start();
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval * 1000
        repeat: true
        running: false
        onTriggered: {
            if (root.displayCommand) {
                root.refreshOutput();
            }
        }
    }

    function refreshOutput() {
        if (!displayCommand) {
            currentOutput = AnsiParser.parseAnsiToHtml(displayText);
            return;
        }

        isLoading = true;
        displayProcess.running = true;
    }

    function executeCommand(command) {
        if (!command)
            return;
        isLoading = true;
        actionProcess.command = ["sh", "-c", command];
        actionProcess.running = true;
    }

    Process {
        id: displayProcess
        command: ["sh", "-c", root.displayCommand]
        running: false

        stdout: SplitParser {
            onRead: function(data) {
                const output = data.trim();
                root.currentOutput = AnsiParser.parseAnsiToHtml(output);
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isLoading = false;
            if (exitCode !== 0) {
                console.warn("CustomActions: Display command failed with code", exitCode);
            }
        }
    }

    Process {
        id: actionProcess
        command: ["sh", "-c", ""]
        running: false

        onExited: function(exitCode, exitStatus) {
            root.isLoading = false;
            if (exitCode === 0) {
                if (root.displayCommand) {
                    root.refreshOutput();
                }
            } else {
                console.warn("CustomActions: Action command failed with code", exitCode);
            }
        }
    }

    pillClickAction: function() {
        if (root.clickCommand) {
            root.executeCommand(root.clickCommand);
        }
    }

    horizontalBarPill: Component {
        MouseArea {
            implicitWidth: contentRow.implicitWidth
            implicitHeight: contentRow.implicitHeight
            acceptedButtons: Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton && root.middleClickCommand) {
                    root.executeCommand(root.middleClickCommand);
                } else if (mouse.button === Qt.RightButton && root.rightClickCommand) {
                    root.executeCommand(root.rightClickCommand);
                }
            }

            Row {
                id: contentRow
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.displayIcon
                    size: Theme.iconSize - 6
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showIcon
                }

                StyledText {
                    text: root.currentOutput || ""
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showText && root.currentOutput
                }
            }
        }
    }

    verticalBarPill: Component {
        MouseArea {
            implicitWidth: contentColumn.implicitWidth
            implicitHeight: contentColumn.implicitHeight
            acceptedButtons: Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: function(mouse) {
                if (mouse.button === Qt.MiddleButton && root.middleClickCommand) {
                    root.executeCommand(root.middleClickCommand);
                } else if (mouse.button === Qt.RightButton && root.rightClickCommand) {
                    root.executeCommand(root.rightClickCommand);
                }
            }

            Column {
                id: contentColumn
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.displayIcon
                    size: Theme.iconSize - 6
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showIcon
                }

                StyledText {
                    text: root.currentOutput || ""
                    textFormat: Text.RichText
                    wrapMode: Text.NoWrap
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.showText && root.currentOutput
                }
            }
        }
    }
}
