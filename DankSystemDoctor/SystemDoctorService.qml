pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- Public metrics ---
    property real cpuPct: 0
    property real ramPct: 0
    property int ramUsedMb: 0
    property int ramTotalMb: 0
    property real diskPct: 0
    property real tempC: -1
    property var topProcs: []
    property var logErrors: []

    // --- Health state ---
    property int healthScore: 100
    property string healthLabel: "Good"
    property string healthIcon: "monitor_heart"

    // --- Thresholds and AI config (written by plugin settings handler) ---
    property int cpuThreshold: 85
    property int ramThreshold: 85
    property int diskThreshold: 90
    property string ollamaModel: "llama3.2"

    // --- CPU delta tracking ---
    property real _prevTotal: 0
    property real _prevIdle: 0

    // --- Initialization ---
    Component.onCompleted: {
        console.log("DankSystemDoctor: Service started");
        refreshMetrics();
        Qt.callLater(refreshLogs);
    }

    Component.onDestruction: {
        console.log("DankSystemDoctor: Service stopped");
    }

    // --- Metric polling timer (every 5 seconds) ---
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refreshMetrics()
    }

    // --- Log polling timer (every 30 seconds) ---
    Timer {
        id: logTimer
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refreshLogs()
    }

    // --- Generic shell command runner ---
    Component {
        id: cmdRunner
        Process {
            id: cmdProc
            property string shellCmd: ""
            property var onFinished: null
            command: ["bash", "-c", shellCmd]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (cmdProc.onFinished) cmdProc.onFinished(text);
                }
            }
            stderr: StdioCollector {}
            onExited: exitCode => { cmdProc.destroy(); }
        }
    }

    function run(shellCmd, cb) {
        var p = cmdRunner.createObject(root, { shellCmd: shellCmd, onFinished: cb });
        p.running = true;
    }

    // --- Metric collection ---
    function refreshMetrics() {
        run("head -1 /proc/stat", parseCpu);
        run("free -m", parseRam);
        run("df / 2>/dev/null | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'", parseDisk);
        run("cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -rn | head -1", parseTemp);
        run("ps aux --sort=-%cpu | head -9", parseProcs);
    }

    function refreshLogs() {
        run("journalctl -p 3 -n 20 --no-pager --output=short 2>/dev/null", parseLogs);
    }

    // --- Parsers ---
    function parseCpu(text) {
        var f = text.trim().split(/\s+/);
        if (f.length < 5 || f[0] !== "cpu") return;
        var total = 0;
        for (var i = 1; i < f.length; i++) total += (parseInt(f[i]) || 0);
        var idle = parseInt(f[4]) || 0;
        if (root._prevTotal > 0) {
            var dt = total - root._prevTotal;
            var di = idle - root._prevIdle;
            root.cpuPct = dt > 0 ? Math.max(0, Math.min(100, Math.round((1 - di / dt) * 100))) : 0;
        }
        root._prevTotal = total;
        root._prevIdle = idle;
        updateHealth();
    }

    function parseRam(text) {
        var lines = text.split("\n");
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("Mem:") === 0) {
                var f = lines[i].trim().split(/\s+/);
                root.ramTotalMb = parseInt(f[1]) || 0;
                root.ramUsedMb = parseInt(f[2]) || 0;
                root.ramPct = root.ramTotalMb > 0
                    ? Math.round(root.ramUsedMb / root.ramTotalMb * 100) : 0;
                break;
            }
        }
        updateHealth();
    }

    function parseDisk(text) {
        var val = parseInt(text.trim());
        if (!isNaN(val)) root.diskPct = val;
        updateHealth();
    }

    function parseTemp(text) {
        var raw = text.trim();
        if (raw.length === 0) {
            root.tempC = -1;
            return;
        }
        var val = parseInt(raw);
        if (!isNaN(val)) root.tempC = val > 1000 ? Math.round(val / 1000) : val;
        updateHealth();
    }

    function parseProcs(text) {
        var lines = text.split("\n");
        var procs = [];
        for (var i = 1; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            var f = line.split(/\s+/);
            if (f.length < 11) continue;
            var cmd = f.slice(10).join(" ");
            if (cmd.length > 32) cmd = cmd.substring(0, 30) + "..";
            procs.push({
                user: f[0].length > 10 ? f[0].substring(0, 9) + "." : f[0],
                pid: f[1],
                cpu: parseFloat(f[2]),
                mem: parseFloat(f[3]),
                cmd: cmd
            });
        }
        root.topProcs = procs;
    }

    function parseLogs(text) {
        var lines = text.split("\n").filter(function(l) { return l.trim().length > 0; });
        root.logErrors = lines;
        updateHealth();
    }

    // --- Health scoring ---
    function updateHealth() {
        var score = 100;
        if (root.cpuPct > root.cpuThreshold) score -= 20;
        if (root.ramPct > root.ramThreshold) score -= 20;
        if (root.diskPct > root.diskThreshold) score -= 15;
        if (root.tempC > 90) score -= 30;
        else if (root.tempC > 80) score -= 15;
        if (root.logErrors.length > 10) score -= 15;
        else if (root.logErrors.length > 0) score -= 10;
        root.healthScore = Math.max(0, score);

        if (root.healthScore >= 80) {
            root.healthLabel = "Good";
            root.healthIcon = "monitor_heart";
        } else if (root.healthScore >= 50) {
            root.healthLabel = "Warning";
            root.healthIcon = "warning";
        } else {
            root.healthLabel = "Critical";
            root.healthIcon = "dangerous";
        }
    }

    // --- Public helpers ---
    function formatMb(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(1) + " GB";
        return mb + " MB";
    }

    function setLogInterval(seconds) {
        logTimer.interval = seconds * 1000;
    }
}
