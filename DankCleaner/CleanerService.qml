pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool cleanupCache: true
    property bool cleanupTrash: true
    property bool cleanupBrowserCache: true
    property bool cleanupTmp: false
    property int tmpAgeDays: 3
    property int largeFileThresholdMb: 100
    property string largeFilePaths: "~/Downloads\n~/Videos\n~/Documents"
    property string excludePatterns: ""
    property string diskAnalyzerPaths: "~/Downloads\n~/Documents\n~/Videos\n~/Pictures"

    property bool running: false
    property string statusText: "Idle"
    property real totalCleanupBytes: 0
    property string totalCleanupLabel: "0 B reclaimable"
    property string totalCleanupShort: "0B"

    property real cacheBytes: 0
    property real trashBytes: 0
    property real browserCacheBytes: 0
    property real tmpBytes: 0

    property var largeFiles: []
    property real lastCleanupBytes: 0
    property string lastCleanupLabel: "0 B"

    property var diskTopDirs: []
    property var diskCategoryBuckets: []
    property real diskTotalBytes: 0
    property bool refreshPending: false

    readonly property string homeDir: Quickshell.env("HOME") || ""

    Component {
        id: cmdRunner
        Process {
            id: cmdProc
            property string shellCmd: ""
            property var onFinished: null
            command: ["bash", "-lc", shellCmd]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (cmdProc.onFinished) cmdProc.onFinished(text);
                }
            }
            stderr: StdioCollector {}
            onExited: {
                cmdProc.destroy();
            }
        }
    }

    function run(shellCmd, cb) {
        var p = cmdRunner.createObject(root, { shellCmd: shellCmd, onFinished: cb });
        p.running = true;
    }

    function shellQuote(input) {
        return "'" + String(input).replace(/'/g, "'\"'\"'") + "'";
    }

    function formatBytes(bytes) {
        var v = Number(bytes) || 0;
        if (v <= 0) return "0 B";
        var units = ["B", "KB", "MB", "GB", "TB"];
        var u = 0;
        while (v >= 1024 && u < units.length - 1) {
            v /= 1024;
            u++;
        }
        var precision = v >= 10 || u === 0 ? 0 : 1;
        return v.toFixed(precision) + " " + units[u];
    }

    function formatShort(bytes) {
        var text = formatBytes(bytes);
        return text.replace(" ", "");
    }

    function parseNumber(text) {
        var n = parseInt(String(text).trim(), 10);
        return isNaN(n) ? 0 : n;
    }

    function expandTilde(pathValue) {
        if (!pathValue) return "";
        var p = String(pathValue).trim();
        if (p.indexOf("~/") === 0) return root.homeDir + p.substring(1);
        if (p === "~") return root.homeDir;
        return p;
    }

    function safeHomePath(pathValue) {
        var p = expandTilde(pathValue);
        return p.length > 1 && p.indexOf(root.homeDir + "/") === 0;
    }

    function normalizeSearchPaths() {
        return normalizePaths(root.largeFilePaths, [root.homeDir + "/Downloads", root.homeDir + "/Videos", root.homeDir + "/Documents"]);
    }

    function normalizePaths(rawValue, fallbackPaths) {
        var raw = String(rawValue || "").split(/\n|,/);
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var item = expandTilde(raw[i]);
            if (!item || !safeHomePath(item)) continue;
            if (out.indexOf(item) === -1) out.push(item);
        }
        if (out.length === 0) out = fallbackPaths;
        return out;
    }

    function patternToRegex(pattern) {
        var s = String(pattern).trim();
        if (!s) return null;
        var escaped = s.replace(/[.+^${}()|[\]\\]/g, "\\$&");
        escaped = escaped.replace(/\*/g, ".*").replace(/\?/g, ".");
        try {
            return new RegExp("^" + escaped + "$");
        } catch (err) {
            return null;
        }
    }

    function parseExclusionRegexes() {
        var rows = String(root.excludePatterns || "").split(/\n|,/);
        var rules = [];
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i].trim();
            if (!row) continue;
            var full = row.indexOf("~/") === 0 || row === "~" ? expandTilde(row) : row;
            var rx = patternToRegex(full);
            if (rx) rules.push(rx);
        }
        return rules;
    }

    function isExcluded(pathValue, regexes) {
        for (var i = 0; i < regexes.length; i++) {
            if (regexes[i].test(pathValue)) return true;
        }
        return false;
    }

    function refreshAll() {
        if (running) {
            refreshPending = true;
            return;
        }
        running = true;
        statusText = "Scanning cleanup categories";
        estimateCleanup(function() {
            statusText = "Scanning large files";
            scanLargeFiles(function() {
                statusText = "Analyzing disk usage";
                scanDiskUsage(function() {
                    running = false;
                    statusText = "Ready";
                    if (refreshPending) {
                        refreshPending = false;
                        Qt.callLater(refreshAll);
                    }
                });
            });
        });
    }

    function updateTotals() {
        totalCleanupBytes = (cleanupCache ? cacheBytes : 0)
            + (cleanupTrash ? trashBytes : 0)
            + (cleanupBrowserCache ? browserCacheBytes : 0)
            + (cleanupTmp ? tmpBytes : 0);
        totalCleanupLabel = formatBytes(totalCleanupBytes) + " reclaimable";
        totalCleanupShort = formatShort(totalCleanupBytes);
    }

    function estimateCleanup(done) {
        var steps = [];

        steps.push(function(next) {
            if (!cleanupCache) {
                cacheBytes = 0;
                next();
                return;
            }
            run("du -sb \"$HOME/.cache\" 2>/dev/null | awk '{print $1}'", function(out) {
                cacheBytes = parseNumber(out);
                next();
            });
        });

        steps.push(function(next) {
            if (!cleanupTrash) {
                trashBytes = 0;
                next();
                return;
            }
            var cmd = "du -sb \"$HOME/.local/share/Trash/files\" \"$HOME/.local/share/Trash/info\" 2>/dev/null | awk '{sum+=$1} END{print sum+0}'";
            run(cmd, function(out) {
                trashBytes = parseNumber(out);
                next();
            });
        });

        steps.push(function(next) {
            if (!cleanupBrowserCache) {
                browserCacheBytes = 0;
                next();
                return;
            }
            var cmd = "du -sb \"$HOME/.cache/mozilla\" \"$HOME/.cache/google-chrome\" \"$HOME/.cache/chromium\" 2>/dev/null | awk '{sum+=$1} END{print sum+0}'";
            run(cmd, function(out) {
                browserCacheBytes = parseNumber(out);
                next();
            });
        });

        steps.push(function(next) {
            if (!cleanupTmp) {
                tmpBytes = 0;
                next();
                return;
            }
            var age = Math.max(1, parseInt(tmpAgeDays) || 3);
            var cmd = "find /tmp -maxdepth 1 -user \"$USER\" -mtime +" + age + " -print0 2>/dev/null | du --files0-from=- -cb 2>/dev/null | tail -n 1 | awk '{print $1+0}'";
            run(cmd, function(out) {
                tmpBytes = parseNumber(out);
                next();
            });
        });

        runSequence(steps, function() {
            updateTotals();
            if (done) done();
        });
    }

    function runSequence(steps, onDone) {
        var i = 0;
        function next() {
            if (i >= steps.length) {
                if (onDone) onDone();
                return;
            }
            var step = steps[i++];
            step(next);
        }
        next();
    }

    function scanLargeFiles(done) {
        var threshold = Math.max(1, parseInt(root.largeFileThresholdMb) || 100);
        var paths = normalizeSearchPaths();
        var exclusionRegexes = parseExclusionRegexes();
        var aggregated = [];
        var steps = [];

        for (var i = 0; i < paths.length; i++) {
            (function(searchPath) {
                steps.push(function(next) {
                    if (!safeHomePath(searchPath)) {
                        next();
                        return;
                    }
                    var cmd = "find " + shellQuote(searchPath) + " -type f -size +" + threshold + "M -printf '%s|%T@|%p\\n' 2>/dev/null";
                    run(cmd, function(out) {
                        var lines = String(out).split("\n");
                        for (var j = 0; j < lines.length; j++) {
                            var line = lines[j].trim();
                            if (!line) continue;
                            var parts = line.split("|");
                            if (parts.length < 3) continue;
                            var filePath = parts.slice(2).join("|");
                            if (!safeHomePath(filePath)) continue;
                            if (isExcluded(filePath, exclusionRegexes)) continue;
                            aggregated.push({
                                size: parseNumber(parts[0]),
                                mtime: parseFloat(parts[1]) || 0,
                                path: filePath
                            });
                        }
                        next();
                    });
                });
            })(paths[i]);
        }

        runSequence(steps, function() {
            aggregated.sort(function(a, b) { return b.size - a.size; });
            largeFiles = aggregated.slice(0, 300);
            if (done) done();
        });
    }

    function summarizeCategoryForPath(pathValue) {
        var p = String(pathValue || "").toLowerCase();
        if (p.indexOf("/videos") >= 0 || p.indexOf("/video") >= 0
            || p.indexOf("/music") >= 0 || p.indexOf("/pictures") >= 0
            || p.indexOf("/photos") >= 0 || p.indexOf("/images") >= 0) {
            return "Media";
        }
        if (p.indexOf("/documents") >= 0 || p.indexOf("/document") >= 0
            || p.indexOf("/books") >= 0 || p.indexOf("/notes") >= 0) {
            return "Documents";
        }
        if (p.indexOf("/downloads") >= 0 || p.indexOf("/archive") >= 0
            || p.indexOf("/backup") >= 0) {
            return "Archives";
        }
        if (p.indexOf("/projects") >= 0 || p.indexOf("/code") >= 0
            || p.indexOf("/src") >= 0 || p.indexOf("/dev") >= 0) {
            return "Code";
        }
        return "Other";
    }

    function scanDiskUsage(done) {
        var paths = normalizePaths(root.diskAnalyzerPaths, [root.homeDir + "/Downloads", root.homeDir + "/Documents", root.homeDir + "/Videos", root.homeDir + "/Pictures"]);
        var rows = [];
        var steps = [];
        var bucketMap = {};

        for (var i = 0; i < paths.length; i++) {
            (function(searchPath) {
                steps.push(function(next) {
                    if (!safeHomePath(searchPath)) {
                        next();
                        return;
                    }
                    var cmd = "find " + shellQuote(searchPath) + " -mindepth 1 -maxdepth 1 -print0 2>/dev/null | du --files0-from=- -sb 2>/dev/null";
                    run(cmd, function(out) {
                        var lines = String(out).split("\n");
                        var hasRows = false;
                        for (var j = 0; j < lines.length; j++) {
                            var line = lines[j].trim();
                            if (!line) continue;
                            var parts = line.split(/\t+/);
                            if (parts.length < 2) continue;
                            var itemPath = parts.slice(1).join("\t");
                            var itemSize = parseNumber(parts[0]);
                            if (!safeHomePath(itemPath) || itemSize <= 0) continue;
                            hasRows = true;
                            rows.push({
                                path: itemPath,
                                size: itemSize,
                                label: itemPath.split("/").pop()
                            });
                            var key = summarizeCategoryForPath(itemPath);
                            bucketMap[key] = (bucketMap[key] || 0) + itemSize;
                        }

                        if (!hasRows) {
                            run("du -sb " + shellQuote(searchPath) + " 2>/dev/null | awk '{print $1\"\\t\"$2}'", function(singleOut) {
                                var singleParts = String(singleOut).trim().split(/\t+/);
                                if (singleParts.length >= 2) {
                                    var onePath = singleParts.slice(1).join("\t");
                                    var oneSize = parseNumber(singleParts[0]);
                                    if (safeHomePath(onePath) && oneSize > 0) {
                                        rows.push({
                                            path: onePath,
                                            size: oneSize,
                                            label: onePath.split("/").pop()
                                        });
                                        var oneKey = summarizeCategoryForPath(onePath);
                                        bucketMap[oneKey] = (bucketMap[oneKey] || 0) + oneSize;
                                    }
                                }
                                next();
                            });
                            return;
                        }
                        next();
                    });
                });
            })(paths[i]);
        }

        runSequence(steps, function() {
            rows.sort(function(a, b) { return b.size - a.size; });
            diskTopDirs = rows.slice(0, 20);
            diskTotalBytes = 0;
            for (var k = 0; k < rows.length; k++) {
                diskTotalBytes += rows[k].size;
            }
            var bucketRows = [];
            for (var name in bucketMap) {
                bucketRows.push({ name: name, size: bucketMap[name] });
            }
            bucketRows.sort(function(a, b) { return b.size - a.size; });
            diskCategoryBuckets = bucketRows;
            if (done) done();
        });
    }

    function cleanNow() {
        if (running) return;
        running = true;
        statusText = "Running cleanup";
        var before = totalCleanupBytes;
        var steps = [];

        if (cleanupCache) {
            steps.push(function(next) {
                // Keep browser caches separate under cleanupBrowserCache toggle.
                var cmd = "if [ -d \"$HOME/.cache\" ]; then find \"$HOME/.cache\" -mindepth 1 -maxdepth 1 ! -name 'mozilla' ! -name 'google-chrome' ! -name 'chromium' -exec rm -rf -- {} + 2>/dev/null; fi";
                run(cmd, function() { next(); });
            });
        }

        if (cleanupTrash) {
            steps.push(function(next) {
                var cmd = "rm -rf \"$HOME/.local/share/Trash/files\"/* \"$HOME/.local/share/Trash/info\"/* 2>/dev/null || true";
                run(cmd, function() { next(); });
            });
        }

        if (cleanupBrowserCache) {
            steps.push(function(next) {
                var cmd = "rm -rf \"$HOME/.cache/mozilla\" \"$HOME/.cache/google-chrome\" \"$HOME/.cache/chromium\" 2>/dev/null || true";
                run(cmd, function() { next(); });
            });
        }

        if (cleanupTmp) {
            steps.push(function(next) {
                var age = Math.max(1, parseInt(tmpAgeDays) || 3);
                var cmd = "find /tmp -maxdepth 1 -user \"$USER\" -mtime +" + age + " -exec rm -rf -- {} + 2>/dev/null || true";
                run(cmd, function() { next(); });
            });
        }

        runSequence(steps, function() {
            estimateCleanup(function() {
                var reclaimed = Math.max(0, before - totalCleanupBytes);
                lastCleanupBytes = reclaimed;
                lastCleanupLabel = formatBytes(reclaimed);
                scanLargeFiles(function() {
                    scanDiskUsage(function() {
                        running = false;
                        statusText = "Cleanup completed";
                    });
                });
            });
        });
    }

    function removeLargeFile(pathValue) {
        if (!safeHomePath(pathValue)) return;
        if (running) return;
        running = true;
        statusText = "Deleting selected file";
        var cmd = "rm -f -- " + shellQuote(pathValue) + " 2>/dev/null";
        run(cmd, function() {
            refreshAll();
        });
    }
}
