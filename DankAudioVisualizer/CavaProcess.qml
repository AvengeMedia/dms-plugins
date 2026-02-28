import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property list<real> values: Array(32).fill(0.0)
    property int refCount: 0
    property bool cavaAvailable: false
    property bool isIdle: true

    // Idle detection: consider idle when all values near zero for idleTimeout ms
    property int idleTimeout: 2000
    property real _idleThreshold: 0.01

    property var _idleTimer: Timer {
        interval: root.idleTimeout
        onTriggered: root.isIdle = true
    }

    property var _cavaCheck: Process {
        command: ["which", "cava"]
        running: false
        onExited: exitCode => {
            root.cavaAvailable = exitCode === 0;
        }
    }

    property var _cavaProcess: Process {
        running: root.cavaAvailable && root.refCount > 0

        command: ["sh", "-c", `cat <<'CAVACONF' | cava -p /dev/stdin
[general]
framerate=60
bars=32
autosens=0
sensitivity=80
lower_cutoff_freq=50
higher_cutoff_freq=12000

[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
channels=mono
mono_option=average

[smoothing]
noise_reduction=35
integral=90
gravity=95
ignore=2
monstercat=1.5
CAVACONF`]

        onRunningChanged: {
            if (!running) {
                root.values = Array(32).fill(0.0);
                root.isIdle = true;
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (root.refCount <= 0 || data.length === 0)
                    return;

                const parts = data.split(";");
                if (parts.length < 32)
                    return;

                const newValues = [];
                let anyActive = false;
                for (let i = 0; i < 32; i++) {
                    const v = parseInt(parts[i], 10) / 100.0;
                    newValues.push(v);
                    if (v > root._idleThreshold)
                        anyActive = true;
                }
                root.values = newValues;

                if (anyActive) {
                    root.isIdle = false;
                    root._idleTimer.restart();
                }
            }
        }
    }

    Component.onCompleted: {
        _cavaCheck.running = true;
    }
}
