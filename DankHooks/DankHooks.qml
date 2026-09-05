import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    signal dankHooksStarted
    property bool preparingForSleep: false

    property string hookDankHooksStarted: pluginData.dankHooksStarted || ""
    property string hookWallpaperPath: pluginData.wallpaperPath || ""
    property string hookLightMode: pluginData.lightMode || ""
    property string hookTheme: pluginData.theme || ""
    property string hookMatugenCompleted: pluginData.matugenCompleted || ""
    property string hookBatteryLevel: pluginData.batteryLevel || ""
    property string hookBatteryCharging: pluginData.batteryCharging || ""
    property string hookBatteryPluggedIn: pluginData.batteryPluggedIn || ""
    property string hookPowerRequestLock: pluginData.hookPowerRequestLock || ""
    property string hookPowerMonitorOff: pluginData.hookPowerMonitorOff || ""
    property string hookPowerMonitorOn: pluginData.hookPowerMonitorOn || ""
    property string hookPowerSuspend: pluginData.hookPowerSuspend || ""
    property string hookResumeFromSleep: pluginData.hookResumeFromSleep || ""
    property string hookWifiConnected: pluginData.wifiConnected || ""
    property string hookWifiSSID: pluginData.wifiSSID || ""
    property string hookEthernetConnected: pluginData.ethernetConnected || ""
    property string hookAudioVolume: pluginData.audioVolume || ""
    property string hookAudioMute: pluginData.audioMute || ""
    property string hookMicMute: pluginData.micMute || ""
    property string hookBrightness: pluginData.brightness || ""
    property string hookNightMode: pluginData.nightMode || ""
    property string hookDoNotDisturb: pluginData.doNotDisturb || ""
    property string hookIdleInhibit: pluginData.idleInhibit || ""
    property string hookMediaPlaying: pluginData.mediaPlaying || ""
    property string hookIdleStateActive: pluginData.idleStateActive || ""
    property string hookMonitorWallpaper: pluginData.monitorWallpaper || ""
    property string hookSessionLocked: pluginData.sessionLocked || ""
    property string hookSessionUnlocked: pluginData.sessionUnlocked || ""

    Connections {
        function onDankHooksStarted() {
            if (!pluginData.dankHooksStarted)
                return;
            if (!hookDankHooksStarted)
                hookDankHooksStarted = pluginData.dankHooksStarted || "";
            if (hookDankHooksStarted) {
                const first_start = PluginService.getGlobalVar("dankHooks", "first_start", true);
                executeHook(hookDankHooksStarted, "onDankHooksStarted", first_start ? "started" : "restarted");
                if (first_start)
                    PluginService.setGlobalVar("dankHooks", "first_start", false);
            }
        }
    }

    Connections {
        target: SessionData
        function onWallpaperPathChanged() {
            if (hookWallpaperPath) {
                executeHook(hookWallpaperPath, "onWallpaperChanged", SessionData.wallpaperPath);
            }
        }

        function onMonitorWallpapersChanged() {
            if (hookMonitorWallpaper) {
                const wallpapersJson = JSON.stringify(SessionData.monitorWallpapers);
                executeHook(hookMonitorWallpaper, "onMonitorWallpapersChanged", wallpapersJson);
            }
        }

        function onIsLightModeChanged() {
            if (hookLightMode) {
                executeHook(hookLightMode, "onLightModeChanged", SessionData.isLightMode ? "light" : "dark");
            }
        }

        function onNightModeEnabledChanged() {
            if (hookNightMode) {
                executeHook(hookNightMode, "onNightModeChanged", SessionData.nightModeEnabled ? "enabled" : "disabled");
            }
        }

        function onDoNotDisturbChanged() {
            if (hookDoNotDisturb) {
                executeHook(hookDoNotDisturb, "onDoNotDisturbChanged", SessionData.doNotDisturb ? "enabled" : "disabled");
            }
        }
    }

    Connections {
        target: SessionService

        function onInhibitorChanged() {
            if (hookIdleInhibit) {
                executeHook(hookIdleInhibit, "onInhibitorChanged", SessionService.idleInhibited ? "inhibited" : "not-inhibited");
            }
        }

        function onSessionLocked() {
            if (hookSessionLocked) {
                executeHook(hookSessionLocked, "onSessionLocked", "locked");
            }
        }

        function onSessionUnlocked() {
            if (hookSessionUnlocked) {
                executeHook(hookSessionUnlocked, "onSessionUnlocked", "unlocked");
            }
        }
    }

    Connections {
        target: typeof Theme !== "undefined" ? Theme : null

        function onCurrentThemeChanged() {
            if (!hookTheme)
                return;
            executeHook(hookTheme, "onThemeChanged", Theme.currentTheme);
        }

        function onMatugenCompleted(mode, result) {
            if (!hookMatugenCompleted)
                return;
            executeHook(hookMatugenCompleted, "onMatugenCompleted", mode + ":" + result);
        }
    }

    Connections {
        target: BatteryService.batteryAvailable ? BatteryService : null
        function onBatteryLevelChanged() {
            if (hookBatteryLevel) {
                executeHook(hookBatteryLevel, "onBatteryLevelChanged", String(BatteryService.batteryLevel));
            }
        }

        function onIsChargingChanged() {
            if (hookBatteryCharging) {
                executeHook(hookBatteryCharging, "onBatteryChargingChanged", BatteryService.isCharging ? "charging" : "not-charging");
            }
        }

        function onIsPluggedInChanged() {
            if (hookBatteryPluggedIn) {
                executeHook(hookBatteryPluggedIn, "onBatteryPluggedInChanged", BatteryService.isPluggedIn ? "plugged-in" : "on-battery");
            }
        }
    }

    Connections {
        target: IdleService

        function onLockRequested() {
            if (hookPowerRequestLock) {
                executeHook(hookPowerRequestLock, "onLockRequested", "");
            }
        }

        function onRequestMonitorOff() {
            if (hookPowerMonitorOff) {
                executeHook(hookPowerMonitorOff, "onRequestMonitorOff", "");
            }
        }

        function onRequestMonitorOn() {
            if (hookPowerMonitorOn) {
                executeHook(hookPowerMonitorOn, "onRequestMonitorOn", "");
            }
        }

        function onRequestSuspend() {
            if (hookPowerSuspend) {
                executeHook(hookPowerSuspend, "onRequestSuspend", "");
            }
        }
    }

    Connections {
        target: DMSService

        function onLoginctlStateUpdate(data) {
            var lastState = root.preparingForSleep;
            root.preparingForSleep = data.preparingForSleep;
            if (lastState && !root.preparingForSleep) {
                executeHook(hookResumeFromSleep, "onResumeFromSleep", "");
            }
        }
    }

    Connections {
        target: NetworkService
        function onWifiConnectedChanged() {
            if (hookWifiConnected) {
                executeHook(hookWifiConnected, "onWifiConnectedChanged", NetworkService.wifiConnected ? "connected" : "disconnected");
            }
        }

        function onCurrentWifiSSIDChanged() {
            if (hookWifiSSID) {
                executeHook(hookWifiSSID, "onWifiSSIDChanged", NetworkService.currentWifiSSID || "none");
            }
        }

        function onEthernetConnectedChanged() {
            if (hookEthernetConnected) {
                executeHook(hookEthernetConnected, "onEthernetConnectedChanged", NetworkService.ethernetConnected ? "connected" : "disconnected");
            }
        }
    }

    Connections {
        target: AudioService.sink && AudioService.sink.audio ? AudioService.sink.audio : null

        function onVolumeChanged() {
            if (hookAudioVolume && AudioService.sink && AudioService.sink.audio) {
                executeHook(hookAudioVolume, "onAudioVolumeChanged", String(Math.round(AudioService.sink.audio.volume * 100)));
            }
        }

        function onMutedChanged() {
            if (hookAudioMute && AudioService.sink && AudioService.sink.audio) {
                executeHook(hookAudioMute, "onAudioMuteChanged", AudioService.sink.audio.muted ? "muted" : "unmuted");
            }
        }
    }

    Connections {
        target: AudioService.source && AudioService.source.audio ? AudioService.source.audio : null

        function onMutedChanged() {
            if (hookMicMute && AudioService.source && AudioService.source.audio) {
                executeHook(hookMicMute, "onMicMuteChanged", AudioService.source.audio.muted ? "muted" : "unmuted");
            }
        }
    }

    Connections {
        target: DisplayService

        function onBrightnessLevelChanged() {
            if (hookBrightness && DisplayService.brightnessAvailable) {
                executeHook(hookBrightness, "onBrightnessChanged", String(DisplayService.brightnessLevel));
            }
        }
    }

    Connections {
        target: MprisController.activePlayer

        function onIsPlayingChanged() {
            if (hookMediaPlaying && MprisController.activePlayer) {
                executeHook(hookMediaPlaying, "onMediaPlayingChanged", MprisController.activePlayer.isPlaying ? "playing" : "paused");
            }
        }
    }

    function executeHook(scriptPath, hookName, hookValue) {
        if (!scriptPath || scriptPath.trim() === "") {
            return;
        }

        const process = hookProcessComponent.createObject(root, {
            hookScript: scriptPath,
            hookName: hookName,
            hookValue: hookValue
        });

        if (!process) {
            console.error("DankHooks: Failed to create process object");
            return;
        }

        process.running = true;
    }

    Component {
        id: hookProcessComponent

        Process {
            property string hookScript: ""
            property string hookName: ""
            property string hookValue: ""

            command: ["sh", "-c", "export HOOK_SCRIPT=\"$1\" HOOK_NAME=\"$2\" HOOK_VALUE=\"$3\"; exec \"$1\" \"$2\" \"$3\"", "dankhooks", hookScript, hookName, hookValue]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim()) {
                        console.log("DankHooks output:", text.trim());
                    }
                }
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim()) {
                        ToastService.showError("Hook Script Error", text.trim());
                    }
                }
            }

            onExited: exitCode => {
                if (exitCode !== 0) {
                    ToastService.showError("Hook Script Error", `Script '${hookScript}' exited with code: ${exitCode}`);
                }
                destroy();
            }
        }
    }

    onPluginDataChanged: {
        if (pluginData)
            dankHooksStarted();
    }

    Component.onDestruction: {
        console.log("DankHooks: Stopped monitoring system events");
    }
}
