import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

Rectangle {
    id: phoneRoot

    property string backgroundImage: "" // Path to background image
    property string style: "android" // "ios" | "pixel" | "samsung" | "oneplus" | "android"

    height: parent ? parent.height : 235
    width: (height / 235) * 115

    readonly property real scaleFactor: Math.min(width / 115, height / 235)
    readonly property bool isIOS: style === "ios"
    readonly property bool cameraCentered: style !== "oneplus" && style !== "nothing"
    readonly property real bezelRadius: {
        switch (style) {
        case "nothing":
            return 12;
        case "oneplus":
            return 13;
        case "ios":
            return 14;
        case "pixel":
        case "motorola":
        case "oppo":
        case "vivo":
        case "asus":
            return 16;
        case "samsung":
        case "honor":
            return 17;
        case "huawei":
            return 18;
        default:
            return 15;
        }
    }
    readonly property real cameraHoleSize: {
        switch (style) {
        case "samsung":
            return 7;
        case "pixel":
        case "huawei":
            return 9;
        default:
            return 8;
        }
    }
    radius: bezelRadius * scaleFactor

    color: "#1c1c1e"

    signal clicked

    MultiEffect {
        source: phoneRect
        anchors.fill: phoneRect
        shadowEnabled: true
        shadowBlur: phoneRect.scale > 0.97 ? 0.4 : 0.2
        shadowVerticalOffset: phoneRect.scale > 0.97 ? 4 : 1
        shadowColor: "#40000000"

        Behavior on shadowBlur {
            NumberAnimation {
                duration: 100
            }
        }
        Behavior on shadowVerticalOffset {
            NumberAnimation {
                duration: 100
            }
        }
    }

    // Bezel/frame
    Rectangle {
        id: phoneRect

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: phoneRect.scale = 1.02
            onExited: phoneRect.scale = 1.0
            onPressed: phoneRect.scale = 0.99
            onReleased: phoneRect.scale = containsMouse ? 1.02 : 1.0
            onClicked: phoneRoot.clicked()
        }

        anchors {
            fill: parent
            margins: 2 * phoneRoot.scaleFactor
        }
        radius: (phoneRoot.bezelRadius - 2) * phoneRoot.scaleFactor
        color: "black"

        // Screen
        Rectangle {
            id: screen
            anchors {
                fill: parent
                margins: 1 * phoneRoot.scaleFactor
            }
            radius: (phoneRoot.bezelRadius - 3) * phoneRoot.scaleFactor
            color: "black"
            clip: true

            // Background wallpaper
            Image {
                anchors.fill: parent
                source: phoneRoot.backgroundImage
                fillMode: Image.PreserveAspectCrop
                visible: phoneRoot.backgroundImage !== ""
            }

            // Fallback gradient if no image
            Rectangle {
                anchors.fill: parent
                visible: phoneRoot.backgroundImage === ""
                radius: screen.radius
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "#1a2a6c"
                    }
                    GradientStop {
                        position: 0.5
                        color: "#b21f1f"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#fdbb2d"
                    }
                }
            }

            // Camera cutout: Dynamic Island on iOS, punch-hole on Android
            Rectangle {
                id: cameraCutout
                anchors.top: parent.top
                anchors.topMargin: 6 * phoneRoot.scaleFactor
                anchors.horizontalCenter: phoneRoot.cameraCentered ? parent.horizontalCenter : undefined
                anchors.left: phoneRoot.cameraCentered ? undefined : parent.left
                anchors.leftMargin: phoneRoot.cameraCentered ? 0 : 12 * phoneRoot.scaleFactor
                width: (phoneRoot.isIOS ? 48 : phoneRoot.cameraHoleSize) * phoneRoot.scaleFactor
                height: (phoneRoot.isIOS ? 10 : phoneRoot.cameraHoleSize) * phoneRoot.scaleFactor
                radius: (phoneRoot.isIOS ? 5 : phoneRoot.cameraHoleSize / 2) * phoneRoot.scaleFactor
                color: "black"
            }

            // Home indicator (bottom gesture bar)
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 6 * phoneRoot.scaleFactor
                }
                width: 40 * phoneRoot.scaleFactor
                height: 4 * phoneRoot.scaleFactor
                radius: 2 * phoneRoot.scaleFactor
                color: "white"
                opacity: 0.4
            }
        }
    }
}
