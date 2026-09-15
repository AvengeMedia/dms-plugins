import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string trigger: "\\"
    property var _keybinds: []
    property var _pinnedKeys: []
    property var _providers: []
    property bool _loading: false
    property int _pendingLoads: 0

    signal itemsChanged

    Component.onCompleted: {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData("dankLauncherKeys", "trigger", "\\");
        _pinnedKeys = pluginService.loadPluginData("dankLauncherKeys", "pinnedKeys", []);
        _providers = pluginService.loadPluginData("dankLauncherKeys", "providers", []);
        if (_providers.length === 0)
            _providers = detectDefaultProviders();
        Qt.callLater(loadAllKeybinds);
    }

    function detectDefaultProviders() {
        if (CompositorService.isNiri)
            return ["niri"];
        if (CompositorService.isHyprland)
            return ["hyprland"];
        if (CompositorService.isSway)
            return ["sway"];
        if (CompositorService.isMango)
            return ["mangowc"];
        return ["niri"];
    }

    function loadAllKeybinds() {
        if (_providers.length === 0)
            return;
        _keybinds = [];
        _loading = true;
        _pendingLoads = _providers.length;
        for (let i = 0; i < _providers.length; i++) {
            loadProviderKeybinds(_providers[i]);
        }
    }

    function loadProviderKeybinds(provider) {
        const process = processComponent.createObject(root, {
            provider: provider
        });
        process.running = true;
    }

    function onProviderLoaded(provider, data) {
        if (!data?.binds)
            return;
        const binds = data.binds;
        for (const category in binds) {
            const catBinds = binds[category];
            for (let i = 0; i < catBinds.length; i++) {
                const bind = catBinds[i];
                if (bind.hideOnOverlay)
                    continue;
                _keybinds.push({
                    key: bind.key || "",
                    desc: bind.desc || "",
                    action: bind.action || "",
                    category: category,
                    provider: provider,
                    subcat: bind.subcat || "",
                    id: provider + ":" + (bind.key || "")
                });
            }
        }
        _pendingLoads--;
        if (_pendingLoads <= 0) {
            _loading = false;
            itemsChanged();
        }
    }

    function isPinned(keybindId) {
        return _pinnedKeys.indexOf(keybindId) !== -1;
    }

    function togglePin(keybindId) {
        const idx = _pinnedKeys.indexOf(keybindId);
        if (idx === -1) {
            _pinnedKeys = _pinnedKeys.concat([keybindId]);
        } else {
            const arr = _pinnedKeys.slice();
            arr.splice(idx, 1);
            _pinnedKeys = arr;
        }
        if (pluginService)
            pluginService.savePluginData("dankLauncherKeys", "pinnedKeys", _pinnedKeys);
        itemsChanged();
    }

    function getItems(query) {
        const lowerQuery = query ? query.toLowerCase().trim() : "";
        let results = [];

        for (let i = 0; i < _keybinds.length; i++) {
            const kb = _keybinds[i];
            const keyLower = kb.key.toLowerCase();
            const descLower = kb.desc.toLowerCase();
            const catLower = kb.category.toLowerCase();
            const actionLower = kb.action.toLowerCase();

            if (lowerQuery.length === 0 || keyLower.includes(lowerQuery) || descLower.includes(lowerQuery) || catLower.includes(lowerQuery) || actionLower.includes(lowerQuery)) {
                const pinned = isPinned(kb.id);
                results.push({
                    name: kb.key,
                    icon: "material:keyboard",
                    comment: kb.desc || kb.action,
                    action: "copy:" + kb.key,
                    categories: ["Keybinds Search"],
                    _keybindId: kb.id,
                    _category: kb.category,
                    _provider: kb.provider,
                    _pinned: pinned,
                    _sortKey: pinned ? 0 : 1
                });
            }
        }

        results.sort((a, b) => {
            if (a._sortKey !== b._sortKey)
                return a._sortKey - b._sortKey;
            return a.name.localeCompare(b.name);
        });

        return results.slice(0, 50);
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        const actionParts = item.action.split(":");
        const actionType = actionParts[0];
        const actionData = actionParts.slice(1).join(":");

        if (actionType === "copy") {
            Quickshell.execDetached(["sh", "-c", "echo -n '" + actionData + "' | dms cl copy"]);
            if (typeof ToastService !== "undefined")
                ToastService.showInfo(I18n.tr("Copied to clipboard"), actionData);
        }
    }

    function getContextMenuActions(item) {
        if (!item || !item._keybindId)
            return [];
        const pinned = isPinned(item._keybindId);
        return [
            {
                icon: pinned ? "keep_off" : "push_pin",
                text: pinned ? I18n.tr("Unpin") : I18n.tr("Pin"),
                action: () => togglePin(item._keybindId)
            },
            {
                icon: "content_copy",
                text: I18n.tr("Copy"),
                action: () => executeItem(item)
            }
        ];
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData("dankLauncherKeys", "trigger", trigger);
    }

    property Component processComponent: Component {
        Process {
            id: loadProcess

            property string provider: ""

            running: false
            command: ["dms", "keybinds", "show", provider]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const data = JSON.parse(text);
                        root.onProviderLoaded(loadProcess.provider, data);
                    } catch (e) {
                        console.error("[DankLauncherKeys] Failed to parse keybinds:", e);
                    }
                    loadProcess.destroy();
                }
            }

            onExited: exitCode => {
                if (exitCode !== 0) {
                    console.warn("[DankLauncherKeys] Load failed for provider:", provider, "exit:", exitCode);
                    root._pendingLoads--;
                    if (root._pendingLoads <= 0)
                        root._loading = false;
                    loadProcess.destroy();
                }
            }
        }
    }
}
