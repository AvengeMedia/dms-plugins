import QtQuick
import qs.Common
import qs.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property string backgroundImage: ""
    property bool isReachable: true

    height: 235
    width: (height / 235) * 115

    readonly property real scaleFactor: height / 235
    property real phoneRadius: 20 * scaleFactor

    signal clicked

    StyledRect {
        id: phoneRect
        anchors.fill: parent
        radius: 18 * root.scaleFactor
        color: root.backgroundImage === "" ? "black" : "transparent"
        border.width: root.backgroundImage === "" ? 1 : 0
        border.color: Theme.withAlpha(Theme.outline, 0.2)

        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Screen
        Rectangle {
            id: screen
            anchors {
                fill: parent
                margins: root.backgroundImage === "" ? 1.5 * root.scaleFactor : 0
            }
            radius: root.backgroundImage === "" ? 16.5 * root.scaleFactor : 0
            color: "transparent"
            clip: true
            antialiasing: true

            // Fallback gradient if no image
            Rectangle {
                anchors.fill: parent
                visible: root.backgroundImage === ""
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.primary }
                    GradientStop { position: 1.0; color: Theme.secondary }
                }
            }

            // Background wallpaper
            Image {
                id: bgImage
                anchors.fill: parent
                source: root.backgroundImage
                fillMode: Image.PreserveAspectCrop
                visible: root.backgroundImage !== ""
            }

            // Screen Overlay for offline state
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.isReachable ? 0 : 0.6
                visible: !root.isReachable
                
                DankIcon {
                    name: "phonelink_off"
                    size: 32 * root.scaleFactor
                    color: "white"
                    anchors.centerIn: parent
                }

                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            // Dynamic Island
            Rectangle {
                id: dynamicIsland
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 8 * root.scaleFactor
                }
                width: 48 * root.scaleFactor
                height: 10 * root.scaleFactor
                radius: 5 * root.scaleFactor
                color: "black"
                visible: root.backgroundImage === ""
            }

            // Home indicator (bottom gesture bar)
            Rectangle {
                anchors {
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    bottomMargin: 6 * root.scaleFactor
                }
                width: 40 * root.scaleFactor
                height: 3 * root.scaleFactor
                radius: 1.5 * root.scaleFactor
                color: "white"
                opacity: 0.4
                visible: root.backgroundImage === ""
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: phoneRect.scale = 1.05
            onExited: phoneRect.scale = 1.0
            onPressed: phoneRect.scale = 0.98
            onReleased: phoneRect.scale = containsMouse ? 1.05 : 1.0
            onClicked: root.clicked()
        }
    }
}
