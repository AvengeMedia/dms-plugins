import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string backgroundImage: ""
    property bool isReachable: true

    height: 235
    width: (height / 235) * 115

    signal clicked

    // Render the Generic Phone Image ONLY when no custom image is provided
    GenericPhoneImage {
        id: genericPhone
        anchors.fill: parent
        visible: root.backgroundImage === ""
        backgroundImage: ""
        onClicked: root.clicked()
    }

    // Render the custom image directly with clean card-matching styling if a custom image is provided
    Rectangle {
        id: customImageContainer
        anchors.fill: parent
        visible: root.backgroundImage !== ""
        radius: Theme.cornerRadius // matches the container's rounded corner
        color: "transparent"
        clip: true

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onEntered: customImageContainer.scale = 1.02
            onExited:  customImageContainer.scale = 1.0
            onPressed: customImageContainer.scale = 0.99
            onReleased: customImageContainer.scale = containsMouse ? 1.02 : 1.0
            onClicked: root.clicked();
        }

        Image {
            id: bgImage
            anchors.fill: parent
            source: {
                if (root.backgroundImage === "") return "";
                if (root.backgroundImage.indexOf(":/") !== -1) {
                    return root.backgroundImage;
                }
                if (root.backgroundImage.startsWith("/")) {
                    return "file://" + root.backgroundImage;
                }
                return root.backgroundImage;
            }
            fillMode: Image.PreserveAspectCrop
        }

        // Screen Overlay for offline state
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.isReachable ? 0 : 0.6
            visible: !root.isReachable
            radius: parent.radius
            
            DankIcon {
                name: "phonelink_off"
                size: 32
                color: "white"
                anchors.centerIn: parent
            }

            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }
}
