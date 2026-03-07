import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    // --- State ---
    property bool isLoading: false
    property string aiResponse: ""
    property var fixCommands: []
    property string errorMessage: ""
    property string customQuestion: ""

    // --- Command runner for applying fixes ---
    Component {
        id: fixRunner
        Process {
            id: fixProc
            property string fixCmd: ""
            property bool needsRoot: false
            command: needsRoot ? ["pkexec", "bash", "-c", fixCmd] : ["bash", "-c", fixCmd]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        ToastService.showInfo("Fix Applied", text.trim().substring(0, 120));
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        ToastService.showError("Fix Error", text.trim().substring(0, 120));
                    }
                }
            }
            onExited: exitCode => {
                if (exitCode === 0) {
                    ToastService.showInfo("Done", "Command completed successfully");
                }
                fixProc.destroy();
            }
        }
    }

    function applyFix(cmd, needsRoot) {
        var p = fixRunner.createObject(root, { fixCmd: cmd, needsRoot: needsRoot });
        p.running = true;
        ToastService.showInfo("Running Fix", "Executing: " + cmd.substring(0, 60));
    }

    function buildContext() {
        var svc = SystemDoctorService;
        var ctx = "You are a Linux system diagnostics expert. Analyze this system status and respond with:\n";
        ctx += "1. A brief diagnosis of the problems (if any)\n";
        ctx += "2. Specific fix commands in ```bash code blocks\n";
        ctx += "3. Commands needing root access must start with: sudo\n\n";
        ctx += "=== SYSTEM STATUS ===\n";
        ctx += "CPU: " + svc.cpuPct.toFixed(0) + "%  (threshold: " + svc.cpuThreshold + "%)\n";
        ctx += "RAM: " + svc.ramPct.toFixed(0) + "% — "
               + svc.formatMb(svc.ramUsedMb) + " used / " + svc.formatMb(svc.ramTotalMb) + " total\n";
        ctx += "Disk (/): " + svc.diskPct.toFixed(0) + "%\n";
        ctx += "Temperature: " + (svc.tempC > 0 ? svc.tempC.toFixed(0) + "°C" : "N/A") + "\n";
        ctx += "Health Score: " + svc.healthScore + "/100 (" + svc.healthLabel + ")\n\n";

        if (svc.topProcs.length > 0) {
            ctx += "=== TOP PROCESSES (CPU%) ===\n";
            for (var i = 0; i < Math.min(6, svc.topProcs.length); i++) {
                var p = svc.topProcs[i];
                ctx += "  " + p.cmd + "  [CPU " + p.cpu.toFixed(1) + "%, RAM " + p.mem.toFixed(1) + "%]\n";
            }
            ctx += "\n";
        }

        if (svc.logErrors.length > 0) {
            ctx += "=== RECENT SYSTEM ERRORS ===\n";
            for (var j = 0; j < Math.min(10, svc.logErrors.length); j++) {
                ctx += svc.logErrors[j] + "\n";
            }
            ctx += "\n";
        }

        if (root.customQuestion.trim().length > 0) {
            ctx += "=== USER QUESTION ===\n" + root.customQuestion.trim() + "\n";
        }

        return ctx;
    }

    function analyze() {
        root.isLoading = true;
        root.aiResponse = "";
        root.fixCommands = [];
        root.errorMessage = "";

        var context = buildContext();
        var body = JSON.stringify({
            model: SystemDoctorService.ollamaModel,
            stream: false,
            messages: [{ role: "user", content: context }]
        });

        var xhr = new XMLHttpRequest();
        xhr.open("POST", "http://localhost:11434/api/chat", true);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.timeout = 120000;

        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.isLoading = false;

            if (xhr.status === 200) {
                try {
                    var resp = JSON.parse(xhr.responseText);
                    root.aiResponse = resp.message ? resp.message.content : resp.response || "No response";
                    root.fixCommands = parseFixes(root.aiResponse);
                } catch(e) {
                    root.errorMessage = "Parse error: " + e.toString();
                }
            } else if (xhr.status === 0) {
                root.errorMessage = "Cannot connect to Ollama at localhost:11434.\nMake sure Ollama is running: ollama serve";
            } else {
                root.errorMessage = "HTTP " + xhr.status + ": " + xhr.statusText;
            }
        };

        xhr.ontimeout = function() {
            root.isLoading = false;
            root.errorMessage = "Request timed out (120s). Try a faster model or check Ollama.";
        };

        xhr.send(body);
    }

    function parseFixes(text) {
        var fixes = [];
        var re = /```(?:bash|sh|shell|zsh)?\s*\n([\s\S]*?)```/g;
        var m;
        while ((m = re.exec(text)) !== null) {
            var block = m[1].trim();
            if (block.length === 0) continue;
            var lines = block.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.length === 0 || line.startsWith("#")) continue;
                var needsRoot = line.startsWith("sudo ");
                var actualCmd = needsRoot ? line.substring(5) : line;
                var label = actualCmd.length > 55 ? actualCmd.substring(0, 52) + "..." : actualCmd;
                fixes.push({ label: label, cmd: actualCmd, needsRoot: needsRoot });
            }
        }
        return fixes;
    }

    // ─────────────────────────────────────────────
    // UI Layout
    // ─────────────────────────────────────────────
    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingM

        // Context summary bar
        Rectangle {
            width: parent.width
            height: 44
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingL

                Repeater {
                    model: [
                        { icon: "memory",      label: "CPU",  value: SystemDoctorService.cpuPct.toFixed(0) + "%" },
                        { icon: "storage",     label: "RAM",  value: SystemDoctorService.ramPct.toFixed(0) + "%" },
                        { icon: "hard_drive",  label: "Disk", value: SystemDoctorService.diskPct.toFixed(0) + "%" },
                        { icon: "thermostat",  label: "Temp",
                          value: SystemDoctorService.tempC > 0 ? SystemDoctorService.tempC.toFixed(0) + "°C" : "N/A" }
                    ]

                    Row {
                        required property var modelData
                        spacing: 4
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            name: modelData.icon
                            color: Theme.surfaceVariantText
                            size: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: modelData.label + " " + modelData.value
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // Custom question input row
        Row {
            width: parent.width
            spacing: Theme.spacingS
            height: 42

            Rectangle {
                width: parent.width - analyzeBtn.width - Theme.spacingS
                height: parent.height
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerHigh
                border.color: questionInput.activeFocus ? Theme.primary : "transparent"
                border.width: 2

                TextInput {
                    id: questionInput
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    clip: true
                    text: root.customQuestion
                    onTextChanged: root.customQuestion = text
                    Keys.onReturnPressed: root.analyze()

                    Text {
                        anchors.fill: parent
                        text: "Ask a specific question (optional)..."
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            DankButton {
                id: analyzeBtn
                text: root.isLoading ? "Analyzing..." : "Ask AI Doctor"
                iconName: root.isLoading ? "hourglass_top" : "smart_toy"
                height: parent.height
                enabled: !root.isLoading
                onClicked: root.analyze()
            }
        }

        // Loading indicator
        Rectangle {
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surfaceVariant
            visible: root.isLoading

            Rectangle {
                id: loadingBar
                width: parent.width * 0.3
                height: parent.height
                radius: parent.radius
                color: Theme.primary

                SequentialAnimation on x {
                    running: root.isLoading
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: loadingBar.parent.width - loadingBar.width; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: loadingBar.parent.width - loadingBar.width; to: 0; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        // Error message
        Rectangle {
            visible: root.errorMessage.length > 0
            width: parent.width
            height: errorText.implicitHeight + Theme.spacingM
            radius: Theme.cornerRadius
            color: Qt.rgba(0.96, 0.26, 0.21, 0.15)

            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                DankIcon { name: "error"; color: "#F44336"; size: 18; anchors.verticalCenter: parent.verticalCenter }

                StyledText {
                    id: errorText
                    text: root.errorMessage
                    color: "#F44336"
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    width: parent.width - 26 - Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Fix buttons strip (if fixes were parsed)
        Column {
            visible: root.fixCommands.length > 0
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: "One-Click Fixes"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.DemiBold
                color: Theme.surfaceVariantText
            }

            Repeater {
                model: root.fixCommands

                Rectangle {
                    id: fixRow
                    required property var modelData
                    width: parent.width
                    height: 36
                    radius: 6
                    color: Theme.surfaceContainerHigh

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spacingS
                        anchors.rightMargin: Theme.spacingXS
                        spacing: Theme.spacingS

                        DankIcon {
                            name: fixRow.modelData.needsRoot ? "admin_panel_settings" : "terminal"
                            color: fixRow.modelData.needsRoot ? "#FF9800" : Theme.primary
                            size: 16
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: fixRow.modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: "monospace"
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                            width: parent.width - applyBtn.width - 32 - Theme.spacingS * 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        DankButton {
                            id: applyBtn
                            text: "Apply"
                            iconName: "play_arrow"
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.applyFix(fixRow.modelData.cmd, fixRow.modelData.needsRoot)
                        }
                    }
                }
            }
        }

        // AI response text area
        Flickable {
            id: responseFlick
            width: parent.width
            height: parent.height - 44 - 42 - Theme.spacingM * 4
                    - (root.isLoading ? 4 + Theme.spacingM : 0)
                    - (root.errorMessage.length > 0 ? 40 + Theme.spacingM : 0)
                    - (root.fixCommands.length > 0 ? root.fixCommands.length * 40 + 20 + Theme.spacingM : 0)
            contentHeight: responseText.implicitHeight
            clip: true
            visible: root.aiResponse.length > 0 || !root.isLoading

            StyledText {
                id: responseText
                width: responseFlick.width
                text: root.aiResponse.length > 0
                      ? root.aiResponse
                      : (root.isLoading ? "" : "Click \"Ask AI Doctor\" to analyze your system with Ollama AI.\n\nThe AI will:\n• Identify performance issues and bottlenecks\n• Check for problematic log errors\n• Suggest specific fix commands\n• Provide one-click fix buttons for each command")
                color: root.aiResponse.length > 0 ? Theme.surfaceText : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
