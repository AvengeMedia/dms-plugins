import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankDesktopWeather"

    SelectionSetting {
        settingKey: "viewMode"
        label: I18n.trFor("dankDesktopWeather", "View Mode")
        description: I18n.trFor("dankDesktopWeather", "Choose how the weather widget is displayed")
        options: [
            {
                label: I18n.trFor("dankDesktopWeather", "Compact"),
                value: "compact"
            },
            {
                label: I18n.trFor("dankDesktopWeather", "Standard"),
                value: "standard"
            },
            {
                label: I18n.trFor("dankDesktopWeather", "Detailed"),
                value: "detailed"
            },
            {
                label: I18n.trFor("dankDesktopWeather", "Forecast"),
                value: "forecast"
            }
        ]
        defaultValue: "standard"
    }

    SelectionSetting {
        settingKey: "colorMode"
        label: I18n.trFor("dankDesktopWeather", "Accent Color")
        options: [
            {
                label: I18n.trFor("dankDesktopWeather", "Primary"),
                value: "primary"
            },
            {
                label: I18n.trFor("dankDesktopWeather", "Secondary"),
                value: "secondary"
            },
            {
                label: I18n.trFor("dankDesktopWeather", "Custom"),
                value: "custom"
            }
        ]
        defaultValue: "primary"
    }

    ColorSetting {
        settingKey: "customColor"
        label: I18n.trFor("dankDesktopWeather", "Custom Color")
        description: I18n.trFor("dankDesktopWeather", "Used when accent color is set to Custom")
        defaultValue: "#4fc3f7"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.trFor("dankDesktopWeather", "Background Opacity")
        defaultValue: 80
        minimum: 0
        maximum: 100
        unit: "%"
    }

    ToggleSetting {
        settingKey: "showLocation"
        label: I18n.trFor("dankDesktopWeather", "Show Location")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showCondition"
        label: I18n.trFor("dankDesktopWeather", "Show Weather Condition")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showFeelsLike"
        label: I18n.trFor("dankDesktopWeather", "Show Feels Like Temperature")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showHumidity"
        label: I18n.trFor("dankDesktopWeather", "Show Humidity")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showWind"
        label: I18n.trFor("dankDesktopWeather", "Show Wind Speed")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showPressure"
        label: I18n.trFor("dankDesktopWeather", "Show Pressure")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showPrecipitation"
        label: I18n.trFor("dankDesktopWeather", "Show Precipitation Probability")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showSunTimes"
        label: I18n.trFor("dankDesktopWeather", "Show Sunrise/Sunset")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showForecast"
        label: I18n.trFor("dankDesktopWeather", "Show Forecast")
        description: I18n.trFor("dankDesktopWeather", "Available in Detailed and Forecast view modes")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "forecastDays"
        label: I18n.trFor("dankDesktopWeather", "Forecast Days")
        defaultValue: 5
        minimum: 1
        maximum: 7
    }

    ToggleSetting {
        settingKey: "showHourlyForecast"
        label: I18n.trFor("dankDesktopWeather", "Show Hourly Forecast")
        description: I18n.trFor("dankDesktopWeather", "Display hourly weather predictions")
        defaultValue: false
    }

    SliderSetting {
        settingKey: "hourlyCount"
        label: I18n.trFor("dankDesktopWeather", "Hourly Forecast Count")
        defaultValue: 6
        minimum: 3
        maximum: 12
    }
}
