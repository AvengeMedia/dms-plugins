import QtQuick
import Quickshell
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "dankGifSearch"
    property string trigger: "gif"
    property bool pasteUrlOnly: false
    property string preferredFormat: "webp"
    property string lastSentQuery: "\x00"
    property string pendingQuery: "\x00"

    signal itemsChanged

    property Timer searchDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: {
            if (root.pendingQuery !== root.lastSentQuery) {
                root.lastSentQuery = root.pendingQuery;
                if (!root.pendingQuery) {
                    GifSearchService.trending();
                } else {
                    GifSearchService.search(root.pendingQuery);
                }
            }
        }
    }

    property Connections gifConn: Connections {
        target: GifSearchService

        function onResultsReady() {
            if (!pluginService || !pluginId)
                return;
            if (typeof pluginService.requestLauncherUpdate === "function") {
                pluginService.requestLauncherUpdate(pluginId);
            }
        }
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("dankGifSearch", "trigger", "gif");
        pasteUrlOnly = pluginService.loadPluginData("dankGifSearch", "pasteUrlOnly", false);
        preferredFormat = pluginService.loadPluginData("dankGifSearch", "preferredFormat", "webp");
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankGifSearch", "trigger", trigger);
    }

    onPasteUrlOnlyChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankGifSearch", "pasteUrlOnly", pasteUrlOnly);
    }

    onPreferredFormatChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankGifSearch", "preferredFormat", preferredFormat);
    }

    function getItems(query) {
        const q = (query || "").trim();

        if (q !== pendingQuery) {
            pendingQuery = q;
            searchDebounce.restart();
        }

        if (GifSearchService.loading || q !== lastSentQuery) {
            return [
                {
                    name: I18n.trFor("dankGifSearch", "Searching..."),
                    icon: "material:hourglass_empty",
                    comment: q || I18n.trFor("dankGifSearch", "Trending GIFs"),
                    action: "none",
                    categories: ["GIF Search"]
                }
            ];
        }

        const results = GifSearchService.results;
        if (!results || results.length === 0) {
            return [
                {
                    name: q ? I18n.trFor("dankGifSearch", "No results found") : I18n.trFor("dankGifSearch", "Loading trending..."),
                    icon: "material:gif_box",
                    comment: I18n.trFor("dankGifSearch", "Try a different search"),
                    action: "none",
                    categories: ["GIF Search"]
                }
            ];
        }

        const pluginDir = pluginService?.getPluginPath?.("dankGifSearch") || "";
        const attributionSvg = pluginDir ? pluginDir + "/klippy.svg" : "";

        const items = [];
        for (let i = 0; i < results.length; i++) {
            const gif = results[i];
            const urls = {
                webp: gif.webpUrl || "",
                gif: gif.gifUrl || "",
                mp4: gif.mp4Url || ""
            };
            items.push({
                name: gif.title || "GIF",
                icon: "material:gif",
                comment: I18n.trFor("dankGifSearch", "Shift+Enter to paste"),
                action: "copy:" + JSON.stringify(urls),
                categories: ["GIF Search"],
                imageUrl: gif.previewUrl,
                animated: true,
                attribution: attributionSvg
            });
        }
        return items;
    }

    function parseUrls(item) {
        if (!item?.action || !item.action.startsWith("copy:"))
            return null;
        try {
            return JSON.parse(item.action.substring(5));
        } catch (e) {
            return null;
        }
    }

    function getPreferredUrl(urls) {
        if (!urls)
            return "";
        if (preferredFormat === "gif" && urls.gif)
            return urls.gif;
        if (preferredFormat === "mp4" && urls.mp4)
            return urls.mp4;
        if (preferredFormat === "webp" && urls.webp)
            return urls.webp;
        return urls.webp || urls.gif || urls.mp4 || "";
    }

    function getPasteText(item) {
        const urls = parseUrls(item);
        return getPreferredUrl(urls) || null;
    }

    function getPasteArgs(item) {
        const url = getPasteText(item);
        if (!url)
            return null;
        if (pasteUrlOnly)
            return ["dms", "cl", "copy", url];
        return ["dms", "cl", "copy", "--download", url];
    }

    function executeItem(item) {
        const urls = parseUrls(item);
        const url = getPreferredUrl(urls);
        if (!url)
            return;
        if (pasteUrlOnly)
            Quickshell.execDetached(["dms", "cl", "copy", url]);
        else
            Quickshell.execDetached(["dms", "cl", "copy", "--download", url]);
        ToastService.showInfo(I18n.trFor("dankGifSearch", "Copied to clipboard"));
    }

    function getContextMenuActions(item) {
        if (!item)
            return [];

        const urls = parseUrls(item);
        if (!urls)
            return [];

        const actions = [];
        const preferredUrl = getPreferredUrl(urls);

        if (SessionService.wtypeAvailable && preferredUrl) {
            const copyCmd = pasteUrlOnly ? "dms cl copy '" + preferredUrl + "'" : "dms cl copy --download '" + preferredUrl + "'";
            actions.push({
                icon: "content_paste",
                text: I18n.trFor("dankGifSearch", "Paste"),
                closeLauncher: true,
                action: () => {
                    Quickshell.execDetached(["sh", "-c", copyCmd + " && sleep 0.3 && wtype -M ctrl -P v -p v -m ctrl"]);
                }
            });
        }

        if (preferredUrl) {
            actions.push({
                icon: "download",
                text: I18n.trFor("dankGifSearch", "Copy Content"),
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", "--download", preferredUrl]);
                    ToastService.showInfo(I18n.trFor("dankGifSearch", "Content copied"));
                }
            });
        }

        if (urls.webp) {
            actions.push({
                icon: "image",
                text: "WebP",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.webp]);
                    ToastService.showInfo(I18n.trFor("dankGifSearch", "Copied WebP"));
                }
            });
        }
        if (urls.gif) {
            actions.push({
                icon: "gif_box",
                text: "GIF",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.gif]);
                    ToastService.showInfo(I18n.trFor("dankGifSearch", "Copied GIF"));
                }
            });
        }
        if (urls.mp4) {
            actions.push({
                icon: "movie",
                text: "MP4",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.mp4]);
                    ToastService.showInfo(I18n.trFor("dankGifSearch", "Copied MP4"));
                }
            });
        }

        if (preferredUrl) {
            actions.push({
                icon: "open_in_new",
                text: I18n.trFor("dankGifSearch", "Open in Browser"),
                action: () => {
                    Qt.openUrlExternally(preferredUrl);
                }
            });
        }
        return actions;
    }
}
