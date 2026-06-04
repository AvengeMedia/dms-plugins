import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string iconName: ""
    property int iconSize: Theme.iconSize - 4
    property color iconColor: Theme.primary
    property color backgroundColor: "transparent"
    property bool circular: true
    property bool enabled: true
    property int buttonSize: 32
    property var tooltipText: null
    property string tooltipSide: "bottom"

    signal clicked

    width: buttonSize
    height: buttonSize

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.circular ? height / 2 : Theme.cornerRadius
        color: root.backgroundColor
    }

    DankIcon {
        anchors.centerIn: parent
        name: root.iconName
        size: root.iconSize
        color: root.iconColor
        opacity: root.enabled ? 1.0 : 0.4
    }

    DankRipple {
        id: ripple
        anchors.fill: parent
        cornerRadius: bgRect.radius
        rippleColor: root.iconColor
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        enabled: root.enabled

        onPressed: function(mouse) {
            ripple.trigger(mouse.x, mouse.y);
        }
        onClicked: {
            root.clicked();
        }
        onEntered: {
            if (root.tooltipText) {
                hoverDelay.restart();
            }
        }
        onExited: {
            if (root.tooltipText) {
                hoverDelay.stop();
                tooltip.hide();
            }
        }
    }

    Timer {
        id: hoverDelay
        interval: 400
        repeat: false
        onTriggered: {
            tooltip.show(root.tooltipText, root, 0, 0, root.tooltipSide);
        }
    }

    DankTooltipV2 {
        id: tooltip
    }
}
