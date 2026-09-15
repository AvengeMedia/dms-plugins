import QtQuick
import Quickshell
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "dankStickerSearch"
    property string trigger: ":s"
    property bool pasteUrlOnly: false
    property string preferredFormat: "webp"
    property string lastSentQuery: "\x00"
    property string lastSentCategory: ""
    property string pendingQuery: "\x00"
    property string pendingCategory: ""
    property string currentCategory: ""

    signal itemsChanged
    signal categoriesChanged

    function getCategorySearchTerm(catId) {
        if (!catId)
            return "";
        const cats = StickerSearchService.categories;
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === catId)
                return cats[i].searchTerm || "";
        }
        return "";
    }

    property Timer searchDebounce: Timer {
        interval: 300
        repeat: false
        onTriggered: {
            if (root.pendingQuery === root.lastSentQuery && root.pendingCategory === root.lastSentCategory)
                return;
            root.lastSentQuery = root.pendingQuery;
            root.lastSentCategory = root.pendingCategory;
            const catSearch = root.getCategorySearchTerm(root.pendingCategory);
            if (!root.pendingQuery && !catSearch) {
                StickerSearchService.trending("");
            } else {
                StickerSearchService.search(root.pendingQuery, catSearch);
            }
        }
    }

    property Connections stickerConn: Connections {
        target: StickerSearchService

        function onResultsReady() {
            if (!pluginService || !pluginId)
                return;
            if (typeof pluginService.requestLauncherUpdate === "function")
                pluginService.requestLauncherUpdate(pluginId);
        }

        function onCategoriesReady() {
            root.categoriesChanged();
        }
    }

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("dankStickerSearch", "trigger", ":s");
        pasteUrlOnly = pluginService.loadPluginData("dankStickerSearch", "pasteUrlOnly", false);
        preferredFormat = pluginService.loadPluginData("dankStickerSearch", "preferredFormat", "webp");
        StickerSearchService.fetchCategories();
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankStickerSearch", "trigger", trigger);
    }

    onPasteUrlOnlyChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankStickerSearch", "pasteUrlOnly", pasteUrlOnly);
    }

    onPreferredFormatChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankStickerSearch", "preferredFormat", preferredFormat);
    }

    function getCategories() {
        if (StickerSearchService.categories.length === 0 && !StickerSearchService.loadingCategories)
            StickerSearchService.fetchCategories();

        const cats = StickerSearchService.categories;
        const result = [
            {
                id: "",
                name: I18n.trFor("dankStickerSearch", "All"),
                searchTerm: ""
            }
        ];
        for (let i = 0; i < cats.length; i++)
            result.push(cats[i]);
        return result;
    }

    function setCategory(categoryId) {
        if (currentCategory === categoryId)
            return;
        currentCategory = categoryId;
    }

    function buildExpectedQuery(q, catId) {
        const catSearch = getCategorySearchTerm(catId);
        if (catSearch && !q)
            return catSearch;
        if (catSearch && q)
            return catSearch + " " + q;
        return q;
    }

    function getItems(query) {
        const q = (query || "").trim();
        const cat = currentCategory;
        const needsSearch = q !== pendingQuery || cat !== pendingCategory;

        if (needsSearch) {
            pendingQuery = q;
            pendingCategory = cat;
            searchDebounce.restart();
        }

        const expectedQuery = buildExpectedQuery(q, cat);
        if (StickerSearchService.loading || StickerSearchService.resultsForQuery !== expectedQuery) {
            return [
                {
                    name: I18n.trFor("dankStickerSearch", "Searching..."),
                    icon: "material:hourglass_empty",
                    comment: q || I18n.trFor("dankStickerSearch", "Trending Stickers"),
                    action: "none",
                    categories: ["Sticker Search"]
                }
            ];
        }

        const results = StickerSearchService.results;
        if (!results || results.length === 0) {
            return [
                {
                    name: q ? I18n.trFor("dankStickerSearch", "No results found") : I18n.trFor("dankStickerSearch", "Loading trending..."),
                    icon: "material:sentiment_satisfied",
                    comment: I18n.trFor("dankStickerSearch", "Try a different search"),
                    action: "none",
                    categories: ["Sticker Search"]
                }
            ];
        }

        const pluginDir = pluginService?.getPluginPath?.("dankStickerSearch") || "";
        const attributionSvg = pluginDir ? pluginDir + "/klippy.svg" : "";

        const items = [];
        for (let i = 0; i < results.length; i++) {
            const sticker = results[i];
            const urls = {
                webp: sticker.webpUrl || "",
                gif: sticker.gifUrl || "",
                mp4: sticker.mp4Url || ""
            };
            items.push({
                name: sticker.title || "Sticker",
                icon: "material:sentiment_satisfied",
                comment: I18n.trFor("dankStickerSearch", "Shift+Enter to paste"),
                action: "copy:" + JSON.stringify(urls),
                categories: ["Sticker Search"],
                imageUrl: sticker.previewUrl,
                animated: false,
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
        if (preferredFormat === "webp" && urls.webp)
            return urls.webp;
        return urls.webp || urls.gif || "";
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
        ToastService.showInfo(I18n.trFor("dankStickerSearch", "Copied to clipboard"));
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
                text: I18n.trFor("dankStickerSearch", "Paste"),
                closeLauncher: true,
                action: () => {
                    Quickshell.execDetached(["sh", "-c", copyCmd + " && sleep 0.3 && wtype -M ctrl -P v -p v -m ctrl"]);
                }
            });
        }

        if (preferredUrl) {
            actions.push({
                icon: "download",
                text: I18n.trFor("dankStickerSearch", "Copy Content"),
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", "--download", preferredUrl]);
                    ToastService.showInfo(I18n.trFor("dankStickerSearch", "Content copied"));
                }
            });
        }

        if (urls.webp) {
            actions.push({
                icon: "image",
                text: "WebP",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.webp]);
                    ToastService.showInfo(I18n.trFor("dankStickerSearch", "Copied WebP"));
                }
            });
        }
        if (urls.gif) {
            actions.push({
                icon: "gif_box",
                text: "GIF",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.gif]);
                    ToastService.showInfo(I18n.trFor("dankStickerSearch", "Copied GIF"));
                }
            });
        }
        if (urls.mp4) {
            actions.push({
                icon: "movie",
                text: "MP4",
                action: () => {
                    Quickshell.execDetached(["dms", "cl", "copy", urls.mp4]);
                    ToastService.showInfo(I18n.trFor("dankStickerSearch", "Copied MP4"));
                }
            });
        }

        if (preferredUrl) {
            actions.push({
                icon: "open_in_new",
                text: I18n.trFor("dankStickerSearch", "Open in Browser"),
                action: () => {
                    Qt.openUrlExternally(preferredUrl);
                }
            });
        }
        return actions;
    }
}
