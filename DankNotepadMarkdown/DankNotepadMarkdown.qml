import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    // Plugin settings from pluginData
    property bool enableMarkdownPreview: pluginData.enableMarkdownPreview ?? true
    property bool enableSyntaxHighlighting: pluginData.enableSyntaxHighlighting ?? true
    property string syntaxTheme: pluginData.syntaxTheme || "monokai"

    Component.onCompleted: {
        console.error("DankNotepadMarkdown: PLUGIN INITIALIZED - V2");
        updateCurrentFile();
    }

    // Internal state
    property string currentFilePath: ""
    property string currentFileExtension: ""
    property string highlightedHtml: ""
    property bool highlightingInProgress: false

    // Markdown file extensions
    readonly property var markdownExtensions: ["md", "markdown", "mdown", "mkd"]

    // Track if initialization has happened
    property bool pluginInitialized: false

    // Watch for tab changes from NotepadTextEditor
    property var lastTabChangeTime: 0

    // Sync plugin settings to builtInPluginSettings for Notepad to read
    function syncSettingsToGlobal() {
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "enabled", true);
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "markdownPreview", enableMarkdownPreview);
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "syntaxHighlighting", enableSyntaxHighlighting);
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "syntaxTheme", syntaxTheme);
    }

    // Update settings when plugin data changes
    onEnableMarkdownPreviewChanged: {
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "markdownPreview", enableMarkdownPreview);
        if (isMarkdownFile()) {
            if (enableMarkdownPreview) {
                triggerMarkdownRendering();
            } else {
                clearHighlighting();
            }
        }
    }

    onEnableSyntaxHighlightingChanged: {
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "syntaxHighlighting", enableSyntaxHighlighting);
        if (enableSyntaxHighlighting && isCodeFile()) {
            triggerCodeHighlighting();
        } else if (!enableSyntaxHighlighting && isCodeFile()) {
            clearHighlighting();
        }
    }

    onSyntaxThemeChanged: {
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "syntaxTheme", syntaxTheme);
        // Re-render with new theme
        if (isMarkdownFile() && enableMarkdownPreview) {
            triggerMarkdownRendering();
        } else if (isCodeFile() && enableSyntaxHighlighting) {
            triggerCodeHighlighting();
        }
    }

    // Watch for tab and content changes from NotepadTextEditor via SettingsData
    property double lastProcessedTabChangeTime: 0
    property string lastProcessedContent: ""

    Connections {
        target: SettingsData

        function onBuiltInPluginSettingsChanged() {
            const tabChangeTime = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "currentTabChanged", 0);
            const sourceContent = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "sourceContent", "");

            // Case 1: Tab Change Detected (Timestamp updated)
            // This is the final step of the editor's update sequence, so Path/Ext/Content are all reliable.
            if (tabChangeTime > root.lastProcessedTabChangeTime) {
                root.lastProcessedTabChangeTime = tabChangeTime;

                // Update Path and Ext
                root.currentFilePath = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "currentFilePath", "");
                root.currentFileExtension = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "currentFileExtension", "");

                console.log("DankNotepadMarkdown: Tab change detected for:", root.currentFilePath);

                // Update content cache and render
                root.lastProcessedContent = sourceContent;
                if (sourceContent !== "") {
                    root.onContentChanged(sourceContent);
                } else {
                    // Start fresh if empty
                    clearHighlighting();
                    root.highlightedHtml = "";
                }
                return;
            }

            // Case 2: Content Changed (Same tab, new content)
            // OR Intermediate step of Tab Switch where Content updated before Timestamp.
            if (sourceContent !== root.lastProcessedContent) {
                // Ensure we have the latest path/ext in case they changed (though usually timestamp handles that)
                root.currentFilePath = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "currentFilePath", "");
                root.currentFileExtension = SettingsData.getBuiltInPluginSetting("dankNotepadMarkdown", "currentFileExtension", "");

                root.lastProcessedContent = sourceContent;

                if (!root.highlightingInProgress) {
                    console.warn("DankNotepadMarkdown: Content update received via settings, length:", sourceContent.length);
                    root.onContentChanged(sourceContent);
                }
            }
        }
    }

    // New function to handle content updates
    function onContentChanged(content) {
        if (content === "") {
            console.warn("DankNotepadMarkdown: onContentChanged called with empty content");
            return;
        }

        console.warn("DankNotepadMarkdown: Checking file type for content change. MarkDown:", isMarkdownFile(), "Code:", isCodeFile());

        if (isMarkdownFile() && enableMarkdownPreview) {
            triggerMarkdownRendering(content);
        } else if (isCodeFile() && enableSyntaxHighlighting) {
            triggerCodeHighlighting(content);
        } else {
            console.warn("DankNotepadMarkdown: No rendering triggered for file type or settings disabled");
        }
    }

    function updateCurrentFile() {
        // Initialize plugin on first use
        if (!pluginInitialized) {
            pluginInitialized = true;
            syncSettingsToGlobal();
        }

        // We no longer pull from NotepadStorageService here.
        // We wait for NotepadTextEditor to push content via SettingsData.
        console.log("DankNotepadMarkdown: Initialized. Waiting for content...");
    }

    function getFileExtension(path) {
        if (!path)
            return "";
        var parts = path.split('.');
        return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : "";
    }

    function isMarkdownFile() {
        return markdownExtensions.indexOf(currentFileExtension) !== -1;
    }

    function isCodeFile() {
        if (isMarkdownFile())
            return false;
        if (currentFileExtension === "" || currentFileExtension === "txt")
            return false;
        return true;
    }

    function onTabSwitched() {
        // Deprecated logic, handled by onBuiltInPluginSettingsChanged -> onContentChanged
    }

    function triggerMarkdownRendering(content) {
        if (highlightingInProgress)
            return;
        if (!enableMarkdownPreview)
            return;
        if (!isMarkdownFile())
            return;
        console.error("DankNotepadMarkdown: Rendering Markdown, length:", content.length);
        performMarkdownRendering(content);
    }

    function triggerCodeHighlighting(content) {
        if (highlightingInProgress)
            return;
        if (!enableSyntaxHighlighting)
            return;
        if (!isCodeFile())
            return;
        console.error("DankNotepadMarkdown: Highlighting Code, length:", content.length);
        performCodeHighlighting(content);
    }

    property string tempDir: "/tmp/dms-notepad-preview"
    property var pendingProcess: null

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", tempDir]
    }

    FileView {
        id: contentSaver
        property var callback
        path: ""
        blockWrites: false
        atomicWrites: true

        onSaved: {
            console.error("DankNotepadMarkdown: Temp file saved to", path);
            if (callback) {
                callback(path);
                callback = null;
            }
        }

        onSaveFailed: {
            console.error("DankNotepadMarkdown: Failed to save temp file to", path);
            root.highlightingInProgress = false;
        }
    }

    function performMarkdownRendering(content) {
        if (highlightingInProgress)
            return;
        highlightingInProgress = true;

        var tempPath = tempDir + "/preview-" + Date.now() + ".md";
        console.error("DankNotepadMarkdown: Writing markdown to", tempPath, "length:", content.length);

        contentSaver.path = tempPath;
        contentSaver.callback = function (path) {
            markdownProcess.command = ["/usr/local/bin/dms", "chroma", "--markdown", "--inline", "--style", root.syntaxTheme, path];
            markdownProcess.running = true;
        };
        contentSaver.setText(content);
    }

    function performCodeHighlighting(content) {
        if (highlightingInProgress)
            return;
        highlightingInProgress = true;

        var tempPath = tempDir + "/code-" + Date.now() + "." + currentFileExtension;
        console.error("DankNotepadMarkdown: Writing code to", tempPath, "length:", content.length);

        contentSaver.path = tempPath;
        contentSaver.callback = function (path) {
            chromaProcess.command = ["/usr/local/bin/dms", "chroma", "--inline", "--style", root.syntaxTheme, "-l", currentFileExtension, path];
            chromaProcess.running = true;
        };
        contentSaver.setText(content);
    }

    function clearHighlighting() {
        highlightedHtml = "";
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "highlightedHtml", "");
    }

    // Test process to check if dms binary is available
    Process {
        id: testProcess
        command: ["which", "dms"]

        stdout: SplitParser {
            onRead: data => {
                if (data.trim()) {
                    console.log("DankNotepadMarkdown: dms binary found at:", data.trim());
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim()) {
                    console.warn("DankNotepadMarkdown: PATH check error:", data.trim());
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.error("DankNotepadMarkdown: dms binary not found in PATH! (exit code:", exitCode, ")");
            }
        }
    }

    // Accumulated output buffers
    property string markdownOutputBuffer: ""
    property string chromaOutputBuffer: ""

    // Process for markdown rendering
    Process {
        id: markdownProcess
        // No stdin needed
        stdinEnabled: false

        onStarted: {
            root.markdownOutputBuffer = "";
            console.error("DankNotepadMarkdown: Markdown process started");
        }

        stdout: SplitParser {
            onRead: data => {
                root.markdownOutputBuffer += data;
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim())
                    console.error("DankNotepadMarkdown: Markdown stderr:", data.trim());
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.error("DankNotepadMarkdown: Markdown process exited:", exitCode, "Buffer:", root.markdownOutputBuffer.length);
            root.highlightingInProgress = false;
            if (exitCode === 0 && root.markdownOutputBuffer.length > 0) {
                // Wrap in html tag to ensure RichText detection
                root.highlightedHtml = "<html>" + root.markdownOutputBuffer.trim() + "</html>";
                SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "highlightedHtml", root.highlightedHtml);
                console.error("DankNotepadMarkdown: Markdown rendered successfully, HTML generated");
            } else {
                root.clearHighlighting();
            }
        }
    }

    // Process for code highlighting
    Process {
        id: chromaProcess
        stdinEnabled: false

        onStarted: {
            root.chromaOutputBuffer = "";
            console.error("DankNotepadMarkdown: Chroma process started");
        }

        stdout: SplitParser {
            onRead: data => {
                root.chromaOutputBuffer += data;
            }
        }

        stderr: SplitParser {
            onRead: data => {
                if (data.trim())
                    console.error("DankNotepadMarkdown: Chroma stderr:", data.trim());
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.error("DankNotepadMarkdown: Chroma process exited:", exitCode);
            root.highlightingInProgress = false;
            if (exitCode === 0 && root.chromaOutputBuffer.length > 0) {
                // Wrap in html tag to ensure RichText detection
                root.highlightedHtml = "<html>" + root.chromaOutputBuffer.trim() + "</html>";
                SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "highlightedHtml", root.highlightedHtml);
                console.error("DankNotepadMarkdown: Success!");
            } else {
                root.clearHighlighting();
            }
        }
    }

    Component.onDestruction: {
        // Clear settings when plugin is unloaded
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "enabled", false);
        SettingsData.setBuiltInPluginSetting("dankNotepadMarkdown", "highlightedHtml", "");
        console.log("DankNotepadMarkdown: Plugin unloaded");
    }
}
