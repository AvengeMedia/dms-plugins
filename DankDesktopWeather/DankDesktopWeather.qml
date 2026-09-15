import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    minWidth: {
        switch (viewMode) {
        case "compact":
            return 80;
        case "standard":
            return 140;
        case "detailed":
            return 200;
        case "forecast":
            return 280;
        default:
            return 160;
        }
    }
    minHeight: {
        switch (viewMode) {
        case "compact":
            return 80;
        case "standard":
            return 100;
        case "detailed":
            return 200;
        case "forecast":
            return 320;
        default:
            return 140;
        }
    }

    property string viewMode: pluginData.viewMode ?? "standard"
    property real backgroundOpacity: (pluginData.backgroundOpacity ?? 80) / 100
    property string colorMode: pluginData.colorMode ?? "primary"
    property color customColor: pluginData.customColor ?? "#ffffff"
    property bool showLocation: pluginData.showLocation ?? true
    property bool showCondition: pluginData.showCondition ?? true
    property bool showFeelsLike: pluginData.showFeelsLike ?? true
    property bool showHumidity: pluginData.showHumidity ?? true
    property bool showWind: pluginData.showWind ?? true
    property bool showPressure: pluginData.showPressure ?? false
    property bool showPrecipitation: pluginData.showPrecipitation ?? true
    property bool showSunTimes: pluginData.showSunTimes ?? true
    property bool showForecast: pluginData.showForecast ?? true
    property int forecastDays: pluginData.forecastDays ?? 5
    property bool showHourlyForecast: pluginData.showHourlyForecast ?? false
    property int hourlyCount: pluginData.hourlyCount ?? 6

    readonly property color accentColor: {
        switch (colorMode) {
        case "secondary":
            return Theme.secondary;
        case "custom":
            return customColor;
        default:
            return Theme.primary;
        }
    }

    readonly property color bgColor: Theme.withAlpha(Theme.surface, backgroundOpacity)
    readonly property color tileBg: Theme.withAlpha(Theme.surfaceContainerHigh, backgroundOpacity)
    readonly property color textColor: Theme.surfaceText
    readonly property color dimColor: Theme.surfaceVariantText

    readonly property bool available: WeatherService.weather.available
    readonly property var weather: WeatherService.weather

    readonly property real scaleFactor: Math.min(width, height) / 200
    readonly property int scaledMargin: {
        switch (viewMode) {
        case "compact":
            return 0;
        case "standard":
            return 2;
        default:
            return Math.round(Math.max(4, Theme.spacingS * scaleFactor));
        }
    }
    readonly property int scaledSpacing: Math.round(Math.max(1, Theme.spacingXS * scaleFactor))

    Ref {
        service: WeatherService
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: root.bgColor
        border.width: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.scaledMargin
            spacing: root.scaledSpacing

            Loader {
                id: headerLoader
                Layout.fillWidth: true
                Layout.fillHeight: {
                    switch (root.viewMode) {
                    case "compact":
                    case "standard":
                        return true;
                    case "detailed":
                        return !root.showForecast;
                    case "forecast":
                        return false;
                    default:
                        return true;
                    }
                }
                Layout.preferredHeight: {
                    if (root.viewMode === "forecast")
                        return 50;
                    if (root.viewMode === "detailed" && root.showForecast)
                        return 140;
                    return -1;
                }
                sourceComponent: {
                    switch (root.viewMode) {
                    case "compact":
                        return compactView;
                    case "standard":
                        return standardView;
                    case "detailed":
                        return detailedView;
                    case "forecast":
                        return forecastHeaderView;
                    default:
                        return standardView;
                    }
                }
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.viewMode === "forecast" || (root.viewMode === "detailed" && root.showForecast)
                active: visible
                sourceComponent: forecastSection
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            visible: !root.available

            DankIcon {
                name: "cloud_off"
                size: Theme.iconSize * 1.5
                color: root.dimColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.trFor("dankDesktopWeather", "No Weather Data")
                font.pixelSize: Theme.fontSizeSmall
                color: root.dimColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Component {
        id: compactView

        Item {
            id: compactRoot
            visible: root.available

            readonly property int baseSize: Math.min(width, height)
            readonly property int iconSize: Math.round(baseSize * 0.55)
            readonly property int tempFontSize: Math.round(baseSize * 0.22)

            Column {
                anchors.centerIn: parent
                spacing: 0

                DankIcon {
                    name: WeatherService.getWeatherIcon(root.weather.wCode)
                    size: compactRoot.iconSize
                    color: root.accentColor
                    anchors.horizontalCenter: parent.horizontalCenter

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                        shadowBlur: 0.6
                        shadowColor: Theme.shadowMedium
                        shadowOpacity: 0.2
                    }
                }

                StyledText {
                    text: WeatherService.formatTemp(root.weather.temp, true, false)
                    font.pixelSize: compactRoot.tempFontSize
                    font.weight: Font.Light
                    color: root.textColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component {
        id: standardView

        Item {
            id: standardRoot
            visible: root.available

            readonly property int baseSize: Math.min(width, height)
            readonly property int iconSize: Math.round(baseSize * 0.55)
            readonly property int tempFontSize: Math.round(baseSize * 0.28)
            readonly property int labelFontSize: Math.max(9, Math.round(baseSize * 0.12))

            RowLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(baseSize * 0.04)

                DankIcon {
                    name: WeatherService.getWeatherIcon(root.weather.wCode)
                    size: standardRoot.iconSize
                    color: root.accentColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 3
                        shadowBlur: 0.7
                        shadowColor: Theme.shadowMedium
                        shadowOpacity: 0.2
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: WeatherService.formatTemp(root.weather.temp, true, false)
                        font.pixelSize: standardRoot.tempFontSize
                        font.weight: Font.Light
                        color: root.textColor
                    }

                    StyledText {
                        visible: root.showCondition
                        text: WeatherService.getWeatherCondition(root.weather.wCode)
                        font.pixelSize: standardRoot.labelFontSize
                        color: root.dimColor
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    StyledText {
                        visible: root.showLocation && root.weather.city
                        text: root.weather.city
                        font.pixelSize: standardRoot.labelFontSize
                        color: root.dimColor
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
        }
    }

    Component {
        id: detailedView

        Item {
            id: detailedRoot
            visible: root.available

            readonly property int baseSize: Math.min(width, height)
            readonly property int iconSize: Math.round(Math.max(28, Math.min(56, baseSize * 0.28)))
            readonly property int tempFontSize: Math.round(Math.max(16, Math.min(32, baseSize * 0.16)))
            readonly property int labelFontSize: Math.round(Math.max(10, Math.min(14, baseSize * 0.07)))
            readonly property int smallIconSize: Math.round(Math.max(12, Math.min(16, baseSize * 0.07)))
            readonly property int itemSpacing: Math.round(Math.max(2, Math.min(8, baseSize * 0.04)))

            ColumnLayout {
                anchors.fill: parent
                spacing: detailedRoot.itemSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: detailedRoot.itemSpacing * 2

                    DankIcon {
                        name: WeatherService.getWeatherIcon(root.weather.wCode)
                        size: detailedRoot.iconSize
                        color: root.accentColor

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 3
                            shadowBlur: 0.7
                            shadowColor: Theme.shadowMedium
                            shadowOpacity: 0.2
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: WeatherService.formatTemp(root.weather.temp, true, false)
                            font.pixelSize: detailedRoot.tempFontSize
                            font.weight: Font.Light
                            color: root.textColor
                        }

                        StyledText {
                            visible: root.showCondition
                            text: WeatherService.getWeatherCondition(root.weather.wCode)
                            font.pixelSize: detailedRoot.labelFontSize
                            color: root.dimColor
                        }

                        StyledText {
                            visible: root.showLocation && root.weather.city
                            text: root.weather.city
                            font.pixelSize: detailedRoot.labelFontSize
                            color: root.dimColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        visible: root.showSunTimes
                        spacing: 1
                        Layout.alignment: Qt.AlignRight

                        RowLayout {
                            spacing: 2
                            DankIcon {
                                name: "wb_twilight"
                                size: detailedRoot.smallIconSize
                                color: root.dimColor
                            }
                            StyledText {
                                text: root.weather.sunrise || "--"
                                font.pixelSize: detailedRoot.labelFontSize
                                color: root.dimColor
                            }
                        }

                        RowLayout {
                            spacing: 2
                            DankIcon {
                                name: "bedtime"
                                size: detailedRoot.smallIconSize
                                color: root.dimColor
                            }
                            StyledText {
                                text: root.weather.sunset || "--"
                                font.pixelSize: detailedRoot.labelFontSize
                                color: root.dimColor
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.15)
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: detailedRoot.itemSpacing

                    WeatherMetric {
                        visible: root.showFeelsLike
                        icon: "device_thermostat"
                        label: I18n.trFor("dankDesktopWeather", "Feels")
                        value: WeatherService.formatTemp(root.weather.feelsLike, true, true)
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        iconSize: detailedRoot.smallIconSize
                        fontSize: detailedRoot.labelFontSize
                    }

                    WeatherMetric {
                        visible: root.showHumidity
                        icon: "humidity_percentage"
                        label: I18n.trFor("dankDesktopWeather", "Humidity")
                        value: WeatherService.formatPercent(root.weather.humidity)
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        iconSize: detailedRoot.smallIconSize
                        fontSize: detailedRoot.labelFontSize
                    }

                    WeatherMetric {
                        visible: root.showWind
                        icon: "air"
                        label: I18n.trFor("dankDesktopWeather", "Wind")
                        value: {
                            SettingsData.windSpeedUnit;
                            SettingsData.useFahrenheit;
                            return WeatherService.formatSpeed(root.weather.wind) || "--";
                        }
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        iconSize: detailedRoot.smallIconSize
                        fontSize: detailedRoot.labelFontSize
                    }

                    WeatherMetric {
                        visible: root.showPrecipitation
                        icon: "rainy"
                        label: I18n.trFor("dankDesktopWeather", "Precip")
                        value: WeatherService.formatPercent(root.weather.precipitationProbability)
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        iconSize: detailedRoot.smallIconSize
                        fontSize: detailedRoot.labelFontSize
                    }

                    WeatherMetric {
                        visible: root.showPressure
                        icon: "speed"
                        label: I18n.trFor("dankDesktopWeather", "Pressure")
                        value: WeatherService.formatPressure(root.weather.pressure)
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        iconSize: detailedRoot.smallIconSize
                        fontSize: detailedRoot.labelFontSize
                    }
                }

                Item {
                    Layout.fillHeight: true
                    visible: !root.showForecast
                }
            }
        }
    }

    Component {
        id: forecastHeaderView

        Item {
            id: forecastHeaderRoot
            visible: root.available

            readonly property int baseSize: Math.min(width, height)
            readonly property int iconSize: Math.round(Math.max(20, baseSize * 0.7))
            readonly property int tempFontSize: Math.round(Math.max(12, baseSize * 0.4))
            readonly property int labelFontSize: Math.round(Math.max(9, baseSize * 0.22))

            RowLayout {
                anchors.fill: parent
                spacing: Math.round(baseSize * 0.15)

                DankIcon {
                    name: WeatherService.getWeatherIcon(root.weather.wCode)
                    size: forecastHeaderRoot.iconSize
                    color: root.accentColor

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                        shadowBlur: 0.6
                        shadowColor: Theme.shadowMedium
                        shadowOpacity: 0.2
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: WeatherService.formatTemp(root.weather.temp, true, false)
                        font.pixelSize: forecastHeaderRoot.tempFontSize
                        font.weight: Font.Light
                        color: root.textColor
                    }

                    StyledText {
                        visible: root.showLocation && root.weather.city
                        text: root.weather.city
                        font.pixelSize: forecastHeaderRoot.labelFontSize
                        color: root.dimColor
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                GridLayout {
                    columns: 2
                    rowSpacing: 1
                    columnSpacing: Math.round(forecastHeaderRoot.baseSize * 0.1)
                    visible: root.width > 300

                    WeatherMetric {
                        visible: root.showHumidity
                        icon: "humidity_percentage"
                        value: WeatherService.formatPercent(root.weather.humidity)
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        compact: true
                        iconSize: forecastHeaderRoot.labelFontSize
                        fontSize: forecastHeaderRoot.labelFontSize
                    }

                    WeatherMetric {
                        visible: root.showWind
                        icon: "air"
                        value: {
                            SettingsData.windSpeedUnit;
                            SettingsData.useFahrenheit;
                            return WeatherService.formatSpeed(root.weather.wind) || "--";
                        }
                        accentColor: root.accentColor
                        textColor: root.textColor
                        dimColor: root.dimColor
                        compact: true
                        iconSize: forecastHeaderRoot.labelFontSize
                        fontSize: forecastHeaderRoot.labelFontSize
                    }
                }
            }
        }
    }

    Component {
        id: forecastSection

        ColumnLayout {
            id: forecastRoot
            spacing: root.scaledSpacing
            visible: root.available && root.showForecast

            readonly property int itemFontSize: Math.round(Math.max(10, Math.min(14, root.height * 0.035)))
            readonly property int itemIconSize: Math.round(Math.max(12, Math.min(18, root.height * 0.04)))

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.15)
                visible: root.viewMode === "forecast"
            }

            DankListView {
                id: hourlyList
                Layout.fillWidth: true
                Layout.preferredHeight: root.showHourlyForecast ? Math.round(Math.max(50, Math.min(80, root.height * 0.18))) : 0
                visible: root.showHourlyForecast && root.weather.hourlyForecast?.length > 0
                orientation: ListView.Horizontal
                flickableDirection: Flickable.HorizontalFlick
                spacing: root.scaledSpacing
                clip: true

                model: Math.min(root.hourlyCount, root.weather.hourlyForecast?.length ?? 0)

                delegate: Rectangle {
                    required property int index
                    width: Math.round(Math.max(36, hourlyList.height * 0.8))
                    height: hourlyList.height
                    radius: Theme.cornerRadius - 2
                    color: root.tileBg

                    property var forecast: root.weather.hourlyForecast?.[index] ?? {}

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 0

                        Item {
                            Layout.fillHeight: true
                        }

                        StyledText {
                            text: forecast.time || "--"
                            font.pixelSize: forecastRoot.itemFontSize
                            color: root.dimColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        DankIcon {
                            name: WeatherService.getWeatherIcon(forecast.wCode, forecast.isDay)
                            size: forecastRoot.itemIconSize
                            color: root.accentColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        StyledText {
                            text: WeatherService.formatTemp(forecast.temp, false)
                            font.pixelSize: forecastRoot.itemFontSize
                            font.weight: Font.Medium
                            color: root.textColor
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.withAlpha(Theme.outline, 0.1)
                visible: root.showHourlyForecast && root.weather.hourlyForecast?.length > 0
            }

            DankListView {
                id: dailyList
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.scaledSpacing
                clip: true

                readonly property int itemCount: Math.min(root.forecastDays, root.weather.forecast?.length ?? 0)
                readonly property int dynamicItemHeight: itemCount > 0 ? Math.round((height - (itemCount - 1) * spacing) / itemCount) : 24

                model: itemCount

                delegate: Rectangle {
                    required property int index
                    width: dailyList.width
                    height: dailyList.dynamicItemHeight
                    radius: Theme.cornerRadius - 2
                    color: index === 0 ? Theme.withAlpha(root.accentColor, 0.1) : root.tileBg

                    property var forecast: root.weather.forecast?.[index] ?? {}

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.scaledMargin
                        anchors.rightMargin: root.scaledMargin
                        spacing: root.scaledSpacing

                        StyledText {
                            text: forecast.day || "--"
                            font.pixelSize: forecastRoot.itemFontSize
                            font.weight: index === 0 ? Font.Medium : Font.Normal
                            color: root.textColor
                            Layout.preferredWidth: forecastRoot.itemFontSize * 5
                        }

                        DankIcon {
                            name: WeatherService.getWeatherIcon(forecast.wCode, true)
                            size: forecastRoot.itemIconSize + 2
                            color: root.accentColor
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            spacing: 1
                            visible: forecast.precipitationProbability > 0

                            DankIcon {
                                name: "water_drop"
                                size: forecastRoot.itemIconSize - 2
                                color: Theme.primary
                            }

                            StyledText {
                                text: forecast.precipitationProbability + "%"
                                font.pixelSize: forecastRoot.itemFontSize - 1
                                color: Theme.primary
                            }
                        }

                        StyledText {
                            text: WeatherService.formatTemp(forecast.tempMax, false)
                            font.pixelSize: forecastRoot.itemFontSize
                            font.weight: Font.Medium
                            color: root.textColor
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: forecastRoot.itemFontSize * 2.5
                        }

                        StyledText {
                            text: WeatherService.formatTemp(forecast.tempMin, false)
                            font.pixelSize: forecastRoot.itemFontSize
                            color: root.dimColor
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: forecastRoot.itemFontSize * 2.5
                        }
                    }
                }
            }
        }
    }
}
