import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankAudioVisualizer"

    SelectionSetting {
        settingKey: "visualizationMode"
        label: "Visualization Mode"
        description: "Choose visualization style"
        options: [
            { label: "Bars", value: "bars" },
            { label: "Wave", value: "wave" },
            { label: "Rings", value: "rings" },
            { label: "Bars + Rings", value: "barsRings" },
            { label: "Wave + Rings", value: "waveRings" },
            { label: "All", value: "all" }
        ]
        defaultValue: "barsRings"
    }

    SliderSetting {
        settingKey: "sensitivity"
        label: "Sensitivity"
        minimum: 0
        maximum: 100
        defaultValue: 40
        unit: "%"
    }

    SliderSetting {
        settingKey: "rotationSpeed"
        label: "Rotation Speed"
        minimum: 0
        maximum: 100
        defaultValue: 25
        unit: "%"
    }

    SliderSetting {
        settingKey: "barWidth"
        label: "Bar Width"
        minimum: 0
        maximum: 100
        defaultValue: 50
        unit: "%"
    }

    SliderSetting {
        settingKey: "ringOpacity"
        label: "Ring Opacity"
        minimum: 0
        maximum: 100
        defaultValue: 80
        unit: "%"
    }

    SliderSetting {
        settingKey: "bloomIntensity"
        label: "Bloom Intensity"
        minimum: 0
        maximum: 100
        defaultValue: 50
        unit: "%"
    }

    SliderSetting {
        settingKey: "waveThickness"
        label: "Wave Thickness"
        minimum: 0
        maximum: 100
        defaultValue: 41
        unit: "%"
    }

    SliderSetting {
        settingKey: "innerDiameter"
        label: "Inner Diameter"
        minimum: 0
        maximum: 100
        defaultValue: 70
        unit: "%"
    }

    ToggleSetting {
        settingKey: "fadeWhenIdle"
        label: "Fade When Idle"
        description: "Fade out visualizer when no audio is playing"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "useCustomColors"
        label: "Use Custom Colors"
        description: "Override theme colors with custom colors"
        defaultValue: false
    }

    ColorSetting {
        settingKey: "customPrimaryColor"
        label: "Primary Color"
        defaultValue: "#6750A4"
    }

    ColorSetting {
        settingKey: "customSecondaryColor"
        label: "Secondary Color"
        defaultValue: "#625B71"
    }
}
