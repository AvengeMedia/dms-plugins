import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Common
import qs.Services

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "dankHyprlandWindows"
    property string trigger: "!"
    property var toplevelRegistry: ({})
    property int _updateTrigger: 0

    signal itemsChanged

    property Connections compositorConn: Connections {
        target: CompositorService

        function onToplevelsChanged() {
            _updateTrigger++;
            requestUpdate();
        }
    }

    function requestUpdate() {
        if (!pluginService || !pluginId)
            return;
        if (typeof pluginService.requestLauncherUpdate === "function")
            pluginService.requestLauncherUpdate(pluginId);
    }

    Component.onCompleted: {
        if (pluginService)
            trigger = pluginService.loadPluginData(pluginId, "trigger", "!");
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "trigger", trigger);
    }

    function getToplevelById(id) {
        return toplevelRegistry[id] || null;
    }

    function windowSelector(address) {
        if (!address)
            return "";
        const normalized = address.toString().startsWith("0x") ? address.toString() : `0x${address}`;
        return `address:${normalized}`;
    }

    function focusWindow(address) {
        const selector = windowSelector(address);
        if (!selector)
            return;

        if (Hyprland.usingLua === false)
            Hyprland.dispatch(`focuswindow ${selector}`);
        else
            Hyprland.dispatch(`hl.dsp.focus({ window = "${selector}" })`);
    }

    function closeWindow(address) {
        const selector = windowSelector(address);
        if (!selector)
            return;

        if (Hyprland.usingLua === false)
            Hyprland.dispatch(`closewindow ${selector}`);
        else
            Hyprland.dispatch(`hl.dsp.window.close({window = "${selector}"})`);
    }

    function getItems(query) {
        if (!CompositorService.isHyprland)
            return [];

        const sortedToplevels = CompositorService.sortedToplevels;
        if (!sortedToplevels || sortedToplevels.length === 0)
            return [];

        const hyprToplevels = Hyprland.toplevels?.values;
        if (!hyprToplevels)
            return [];

        const hyprMap = new Map();
        for (const ht of hyprToplevels) {
            if (ht?.wayland)
                hyprMap.set(ht.wayland, ht);
        }

        const lowerQuery = (query || "").toLowerCase().trim();
        const newRegistry = {};
        const items = [];

        for (let i = 0; i < sortedToplevels.length; i++) {
            const toplevel = sortedToplevels[i];
            if (!toplevel)
                continue;

            const hyprToplevel = hyprMap.get(toplevel);
            const ipc = hyprToplevel?.lastIpcObject;
            const address = ipc?.address || "";

            if (!address)
                continue;

            const appId = toplevel.appId || ipc?.class || "";
            const title = toplevel.title || ipc?.title || "";

            if (lowerQuery.length > 0) {
                const searchText = `${appId} ${title}`.toLowerCase();
                if (!searchText.includes(lowerQuery))
                    continue;
            }

            const wsId = ipc?.workspace?.id ?? hyprToplevel?.workspace?.id;
            const wsName = ipc?.workspace?.name || hyprToplevel?.workspace?.name || (wsId ? `Workspace ${wsId}` : "");

            const desktopEntry = DesktopEntries.heuristicLookup(Paths.moddedAppId(appId));
            const iconPath = Paths.getAppIcon(appId, desktopEntry) || Quickshell.iconPath("application-x-executable", "image-missing");

            const toplevelId = `hypr_${address}`;
            newRegistry[toplevelId] = toplevel;

            items.push({
                id: address,
                name: title || appId,
                icon: iconPath,
                comment: wsName ? `${appId} • ${wsName}` : appId,
                action: `focus:${address}`,
                categories: ["Hyprland Window Switcher"],
                toplevelId: toplevelId,
                attribution: iconPath,
                hyprAddress: address,
                _isFocused: toplevel.activated || false
            });
        }

        toplevelRegistry = newRegistry;
        return items;
    }

    function executeItem(item) {
        if (!item?.action)
            return;
        if (!item.action.startsWith("focus:"))
            return;

        const address = item.action.substring(6);
        if (!address)
            return;

        focusWindow(address);
    }

    function getContextMenuActions(item) {
        if (!item?.hyprAddress)
            return [];

        const address = item.hyprAddress;
        return [
            {
                icon: "close",
                text: I18n.tr("Close Window"),
                action: () => {
                    closeWindow(address);
                }
            }
        ];
    }
}
