import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    minWidth: 200
    minHeight: 200

    // Settings from pluginData (0-100% sliders mapped to shader ranges)
    readonly property real sensitivity: 0.5 + (pluginData.sensitivity ?? 40) / 100.0 * 2.5      // 0% → 0.5, 100% → 3.0
    readonly property real rotationSpeed: (pluginData.rotationSpeed ?? 25) / 100.0 * 2.0         // 0% → 0.0, 100% → 2.0
    readonly property real barWidth: 0.2 + (pluginData.barWidth ?? 50) / 100.0 * 0.8             // 0% → 0.2, 100% → 1.0
    readonly property real ringOpacity: (pluginData.ringOpacity ?? 80) / 100.0                    // 0% → 0.0, 100% → 1.0
    readonly property real bloomIntensity: (pluginData.bloomIntensity ?? 50) / 100.0              // 0% → 0.0, 100% → 1.0
    readonly property string visualizationMode: pluginData.visualizationMode ?? "barsRings"
    readonly property real waveThickness: 0.3 + (pluginData.waveThickness ?? 41) / 100.0 * 1.7   // 0% → 0.3, 100% → 2.0
    readonly property real innerDiameter: (pluginData.innerDiameter ?? 70) / 100.0                // 0% → 0.0, 100% → 1.0
    readonly property bool fadeWhenIdle: pluginData.fadeWhenIdle ?? false
    readonly property bool useCustomColors: pluginData.useCustomColors ?? false
    readonly property color customPrimaryColor: pluginData.customPrimaryColor ?? "#6750A4"
    readonly property color customSecondaryColor: pluginData.customSecondaryColor ?? "#625B71"

    // Map string mode to shader int
    readonly property int visualizationModeInt: {
        switch (visualizationMode) {
        case "bars": return 0;
        case "wave": return 1;
        case "rings": return 2;
        case "barsRings": return 3;
        case "waveRings": return 4;
        case "all": return 5;
        default: return 3;
        }
    }

    // Self-contained cava audio source (32 bars, 60 FPS)
    CavaProcess {
        id: cavaProcess
    }

    // Manage cava lifecycle via reference counting
    Component.onCompleted: cavaProcess.refCount++
    Component.onDestruction: cavaProcess.refCount--

    // Animation time for shader (0 to 3600, 1 hour cycle)
    property real shaderTime: 0
    NumberAnimation on shaderTime {
        loops: Animation.Infinite
        from: 0
        to: 3600
        duration: 3600000
        running: !cavaProcess.isIdle
    }

    // Hidden canvas that encodes audio data as a 32x1 texture
    Canvas {
        id: audioCanvas
        width: 32
        height: 1
        visible: false

        onPaint: {
            var ctx = getContext("2d");
            var values = cavaProcess.values;
            if (!values || values.length === 0) {
                ctx.fillStyle = "black";
                ctx.fillRect(0, 0, 32, 1);
                return;
            }
            for (var i = 0; i < 32; i++) {
                var v = values[i] || 0;
                var c = Math.floor(v * 255);
                ctx.fillStyle = "rgb(" + c + "," + c + "," + c + ")";
                ctx.fillRect(i, 0, 1, 1);
            }
        }
    }

    // Trigger canvas repaint when audio data changes
    Connections {
        target: cavaProcess
        function onValuesChanged() {
            if (!cavaProcess.isIdle) {
                audioCanvas.requestPaint();
            }
        }
    }

    // Audio texture source
    ShaderEffectSource {
        id: audioTextureSource
        sourceItem: audioCanvas
        live: true
        hideSource: true
    }

    // The shader effect visualization
    ShaderEffect {
        id: visualizer
        anchors.fill: parent
        opacity: (root.fadeWhenIdle && cavaProcess.isIdle) ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
        }

        property var source: audioTextureSource

        // Uniforms passed to shader
        property real time: root.shaderTime
        property real itemWidth: visualizer.width
        property real itemHeight: visualizer.height
        property color primaryColor: root.useCustomColors ? root.customPrimaryColor : Theme.primary
        property color secondaryColor: root.useCustomColors ? root.customSecondaryColor : Theme.secondary
        property real sensitivity: root.sensitivity
        property real rotationSpeed: root.rotationSpeed
        property real barWidth: root.barWidth
        property real ringOpacity: root.ringOpacity
        property real cornerRadius: Theme.cornerRadius
        property real bloomIntensity: root.bloomIntensity
        property real visualizationMode: root.visualizationModeInt
        property real waveThickness: root.waveThickness
        property real innerDiameter: root.innerDiameter

        fragmentShader: Qt.resolvedUrl("shaders/visualizer.frag.qsb")
    }

    // Fallback when shader not loaded
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.cornerRadius
        visible: visualizer.fragmentShader === ""

        Text {
            anchors.centerIn: parent
            text: cavaProcess.cavaAvailable ? "Loading..." : "cava not found"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
        }
    }
}
