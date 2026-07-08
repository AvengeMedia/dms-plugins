import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string backgroundImage: ""
    property bool isReachable: true
    property string deviceType: "phone"
    property string deviceName: ""
    readonly property string backgroundImageSource: resolveBackgroundImage(backgroundImage)
    readonly property bool hasBackgroundImage: backgroundImageSource !== ""
    readonly property string phoneStyle: phoneStyleFor(deviceName)

    function phoneStyleFor(name) {
        const n = (name || "").toLowerCase();
        switch (true) {
        case /iphone|ipad|apple|\bios\b/.test(n):
            return "ios";
        case /pixel/.test(n):
            return "pixel";
        case /galaxy|samsung|\bsm-/.test(n):
            return "samsung";
        case /oneplus|one plus/.test(n):
            return "oneplus";
        case /nothing/.test(n):
            return "nothing";
        case /xiaomi|redmi|poco/.test(n):
            return "xiaomi";
        case /motorola|moto\b/.test(n):
            return "motorola";
        case /huawei/.test(n):
            return "huawei";
        case /honor/.test(n):
            return "honor";
        case /\boppo/.test(n):
            return "oppo";
        case /\bvivo/.test(n):
            return "vivo";
        case /realme/.test(n):
            return "realme";
        case /asus|zenfone|\brog\b/.test(n):
            return "asus";
        default:
            return "android";
        }
    }

    function resolveBackgroundImage(path) {
        if (typeof path !== "string")
            return "";

        const value = path.trim();
        if (value === "")
            return "";
        if (value.startsWith(":/") || value.startsWith("qrc:/") || value.startsWith("image://"))
            return value;
        if (value.startsWith("/"))
            return "file://" + value;
        if (/^(file|https?):\/\//i.test(value))
            return value;

        return "";
    }

    height: 235
    width: {
        if (hasBackgroundImage)
            return 115;
        switch (deviceType) {
        case "desktop":
        case "computer":
            return Math.ceil((height - 30) * (16 / 9));
        case "laptop":
            return Math.ceil((height - 12) * (16 / 10));
        case "tv":
            return Math.ceil((height - 12) * (16 / 9));
        case "tablet":
            return Math.ceil(height * (3 / 4));
        default:
            return 115;
        }
    }

    signal clicked

    // Render the custom image directly with clean card-matching styling if a custom image is provided
    Rectangle {
        id: customImageContainer
        anchors.fill: parent
        visible: root.hasBackgroundImage
        radius: Theme.cornerRadius // matches the container's rounded corner
        color: "transparent"
        clip: true

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: customImageMa
            anchors.fill: parent
            hoverEnabled: true

            onEntered: customImageContainer.scale = 1.02
            onExited: customImageContainer.scale = 1.0
            onPressed: function (m) {
                customImageContainer.scale = 0.99;
                customRipple.trigger(m.x, m.y);
            }
            onReleased: customImageContainer.scale = containsMouse ? 1.02 : 1.0
            onClicked: root.clicked()
        }

        DankRipple {
            id: customRipple
            anchors.fill: parent
            cornerRadius: customImageContainer.radius
            rippleColor: Theme.primary
        }

        Image {
            id: bgImage
            anchors.fill: parent
            source: root.backgroundImageSource
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

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }

    // Main scaling container for generic rendering (ONLY when no custom image is provided)
    Item {
        id: container
        anchors.fill: parent
        visible: !root.hasBackgroundImage

        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: genericMa
            anchors.fill: parent
            hoverEnabled: true

            onEntered: container.scale = 1.02
            onExited: container.scale = 1.0
            onPressed: function (m) {
                container.scale = 0.99;
                genericRipple.trigger(m.x, m.y);
            }
            onReleased: container.scale = containsMouse ? 1.02 : 1.0
            onClicked: root.clicked()
        }

        DankRipple {
            id: genericRipple
            anchors.fill: parent
            cornerRadius: {
                if (deviceType === "tv")
                    return 4;
                if (deviceType === "desktop" || deviceType === "computer" || deviceType === "laptop")
                    return 8;
                if (deviceType === "tablet")
                    return 12;
                return Theme.cornerRadius;
            }
            rippleColor: Theme.primary
        }

        // --- PHONE / SMARTPHONE / UNKNOWN RENDERER ---
        Item {
            anchors.fill: parent
            visible: deviceType !== "desktop" && deviceType !== "computer" && deviceType !== "laptop" && deviceType !== "tv" && deviceType !== "tablet"

            GenericPhoneImage {
                anchors.fill: parent
                backgroundImage: ""
                style: root.phoneStyle
                onClicked: root.clicked()
            }
        }

        // --- TABLET RENDERER ---
        Item {
            anchors.fill: parent
            visible: deviceType === "tablet"

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: "black"

                Rectangle {
                    id: tabletScreen
                    anchors.fill: parent
                    anchors.margins: 8
                    radius: 8
                    color: "black"
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: tabletScreen.radius
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
                }
            }
        }

        // --- LAPTOP RENDERER ---
        Item {
            anchors.centerIn: parent
            width: parent.width
            height: parent.width * (10 / 16) + 12 // 16:10 aspect ratio screen + laptop base
            visible: deviceType === "laptop"

            Rectangle {
                id: laptopBase
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 12
                radius: 4
                color: "#333333"
                border.width: 1
                border.color: "#555555"
                z: 2

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    width: 30
                    height: 3
                    radius: 1
                    color: "#222222"
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: laptopBase.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                radius: 8
                color: "black"

                Rectangle {
                    id: laptopInnerScreen
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 4
                    color: "black"
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: laptopInnerScreen.radius
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
                }
            }
        }

        // --- DESKTOP COMPUTER RENDERER ---
        Item {
            anchors.centerIn: parent
            width: parent.width
            height: parent.width * (9 / 16) + 30 // 16:9 aspect ratio screen + stand height
            visible: deviceType === "desktop" || deviceType === "computer"

            Item {
                id: monitorStand
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 30
                z: 2

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16
                    height: 26
                    color: "#444444"
                    border.width: 1
                    border.color: "#666666"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.4
                    height: 6
                    radius: 2
                    color: "#333333"
                    border.width: 1
                    border.color: "#555555"
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: monitorStand.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                radius: 8
                color: "black"

                Rectangle {
                    id: desktopInnerScreen
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 4
                    color: "black"
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: desktopInnerScreen.radius
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
                }
            }
        }

        // --- TV RENDERER ---
        Item {
            anchors.centerIn: parent
            width: parent.width
            height: parent.width * (9 / 16) + 12 // 16:9 aspect ratio screen + feet height
            visible: deviceType === "tv"

            Item {
                id: tvBase
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 12
                z: 2

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    width: 6
                    height: 12
                    color: "#333333"
                    rotation: 20
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    width: 6
                    height: 12
                    color: "#333333"
                    rotation: -20
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: tvBase.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                radius: 4
                color: "black"

                Rectangle {
                    id: tvInnerScreen
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: 2
                    color: "black"
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: tvInnerScreen.radius
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
                }
            }
        }

        // Screen overlay for offline state
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: root.isReachable ? 0 : 0.6
            visible: !root.isReachable
            radius: {
                if (deviceType === "tv")
                    return 4;
                if (deviceType === "desktop" || deviceType === "computer" || deviceType === "laptop")
                    return 8;
                if (deviceType === "tablet")
                    return 12;
                return Theme.cornerRadius;
            }
            clip: true

            DankIcon {
                name: "phonelink_off"
                size: 32
                color: "white"
                anchors.centerIn: parent
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
        }
    }
}
