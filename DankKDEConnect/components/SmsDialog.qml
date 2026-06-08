import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    focus: true
    Keys.onEscapePressed: (event) => {
        root.close();
        event.accepted = true;
    }

    property string deviceId: ""

    signal close
    signal sendSms(string phoneNumber, string message)
    signal launchApp

    property bool isOpen: false
    onIsOpenChanged: {
        if (isOpen) {
            phoneInput.forceActiveFocus();
        }
    }

    height: 0
    visible: false

    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
    border.width: 1
    border.color: Theme.withAlpha(Theme.primary, 0.15)

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.4
        shadowVerticalOffset: 3
        shadowColor: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
    }

    states: [
        State {
            name: "open"
            when: root.isOpen
            PropertyChanges {
                target: root
                height: contentColumn.implicitHeight + Theme.spacingM * 2
                visible: true
            }
            PropertyChanges {
                target: clipContainer
                opacity: 1.0
            }
        },
        State {
            name: "closed"
            when: !root.isOpen
            PropertyChanges {
                target: root
                height: 0
                visible: false
            }
            PropertyChanges {
                target: clipContainer
                opacity: 0.0
            }
        }
    ]

    transitions: [
        Transition {
            from: "closed"; to: "open"
            ParallelAnimation {
                PropertyAction { target: root; property: "visible"; value: true }
                NumberAnimation {
                    target: root
                    property: "height"
                    duration: Theme.shorterDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: clipContainer
                    property: "opacity"
                    duration: Theme.shorterDuration
                    easing.type: Easing.OutCubic
                }
            }
        },
        Transition {
            from: "open"; to: "closed"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: clipContainer
                        property: "opacity"
                        duration: Theme.shorterDuration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: root
                        property: "height"
                        duration: Theme.shorterDuration
                        easing.type: Easing.OutCubic
                    }
                }
                PropertyAction { target: root; property: "visible"; value: false }
            }
        }
    ]

    Item {
        id: clipContainer
        anchors.fill: parent
        clip: true
        opacity: 0.0

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

        RowLayout {
            width: parent.width
            spacing: Theme.spacingXS
            anchors.left: parent.left
            anchors.leftMargin: 4

            DankIcon {
                name: "sms"
                size: 14
                color: Theme.surfaceText
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: I18n.tr("Send SMS", "KDE Connect SMS dialog title")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: Theme.surfaceText
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: closeBtn
                width: 32
                height: 32
                radius: Theme.cornerRadius
                Layout.alignment: Qt.AlignVCenter
                color: closeArea.containsMouse ? Theme.withAlpha(Theme.error, 0.4) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                border.width: 1
                border.color: Theme.withAlpha(Theme.error, closeArea.containsMouse ? 0.4 : 0.15)
                scale: closeArea.containsMouse ? 1.08 : 1.0
                activeFocusOnTab: true

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 16
                    color: closeArea.containsMouse ? (Theme.isLightMode ? "#000000" : Theme.error) : Theme.surfaceVariantText
                    rotation: closeArea.containsMouse ? 90 : 0

                    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                }

                DankRipple {
                    id: smsCloseRipple
                    anchors.fill: parent
                    cornerRadius: parent.radius
                    rippleColor: Theme.error
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(m) { smsCloseRipple.trigger(m.x, m.y) }
                    onClicked: root.close()
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: Theme.primary
                    border.width: 2
                    radius: Theme.cornerRadius
                    visible: parent.activeFocus
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                        root.close();
                        event.accepted = true;
                    }
                }
            }
        }

        DankTextField {
            id: phoneInput
            width: parent.width
            placeholderText: I18n.tr("Phone number", "KDE Connect SMS phone input placeholder") + "..."
            activeFocusOnTab: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    messageInput.forceActiveFocus();
                    event.accepted = true;
                }
            }
        }

        DankTextField {
            id: messageInput
            width: parent.width
            placeholderText: I18n.tr("Message", "KDE Connect SMS message input placeholder") + "..."
            activeFocusOnTab: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    if (phoneInput.text.length > 0 && text.length > 0) {
                        root.sendSms(phoneInput.text, text);
                        phoneInput.text = "";
                        text = "";
                        event.accepted = true;
                    }
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                id: sendSmsBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                height: 36
                color: "transparent"
                border.width: 0
                activeFocusOnTab: isEnabled
                
                readonly property bool isEnabled: phoneInput.text.length > 0 && messageInput.text.length > 0
                opacity: isEnabled ? 1.0 : 0.4

                Canvas {
                    id: sendSmsBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: Theme.cornerRadius
                    readonly property real bottomLeftRadius: Theme.cornerRadius
                    readonly property real topRightRadius: 4
                    readonly property real bottomRightRadius: 4
                    
                    property color fillColor: (sendSmsBtn.isEnabled && (sendSmsArea.containsMouse || sendSmsBtn.activeFocus)) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: (sendSmsBtn.isEnabled && (sendSmsArea.containsMouse || sendSmsBtn.activeFocus)) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
                    readonly property real borderWidth: 1

                    Behavior on fillColor { ColorAnimation { duration: 200 } }
                    Behavior on borderColor { ColorAnimation { duration: 200 } }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        
                        var w = width;
                        var h = height;
                        var r = borderWidth / 2;
                        var x = r;
                        var y = r;
                        w -= borderWidth;
                        h -= borderWidth;
                        
                        ctx.beginPath();
                        ctx.moveTo(x + topLeftRadius, y);
                        ctx.lineTo(x + w - topRightRadius, y);
                        ctx.arcTo(x + w, y, x + w, y + topRightRadius, topRightRadius);
                        ctx.lineTo(x + w, y + h - bottomRightRadius);
                        ctx.arcTo(x + w, y + h, x + w - bottomRightRadius, y + h, bottomRightRadius);
                        ctx.lineTo(x + bottomLeftRadius, y + h);
                        ctx.arcTo(x, y + h, x, y + h - bottomLeftRadius, bottomLeftRadius);
                        ctx.lineTo(x, y + h - bottomLeftRadius);
                        ctx.lineTo(x, y + topLeftRadius);
                        ctx.arcTo(x, y, x + topLeftRadius, y, topLeftRadius);
                        ctx.closePath();
                        
                        ctx.fillStyle = fillColor;
                        ctx.fill();
                        
                        ctx.lineWidth = borderWidth;
                        ctx.strokeStyle = borderColor;
                        ctx.stroke();
                    }
                    
                    onFillColorChanged: requestPaint()
                    onBorderColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "send"
                        size: 16
                        color: (sendSmsBtn.isEnabled && (sendSmsArea.containsMouse || sendSmsBtn.activeFocus)) ? Theme.primary : Theme.surfaceVariantText
                        scale: (sendSmsBtn.isEnabled && (sendSmsArea.containsMouse || sendSmsBtn.activeFocus)) ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: I18n.tr("Send", "KDE Connect SMS send button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: (sendSmsBtn.isEnabled && (sendSmsArea.containsMouse || sendSmsBtn.activeFocus)) ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                DankRipple {
                    id: sendSmsRipple
                    anchors.fill: parent
                    cornerRadius: Theme.cornerRadius
                    rippleColor: Theme.primary
                    enabled: sendSmsBtn.isEnabled
                }

                MouseArea {
                    id: sendSmsArea
                    anchors.fill: parent
                    hoverEnabled: sendSmsBtn.isEnabled
                    cursorShape: sendSmsBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: function(m) { if (sendSmsBtn.isEnabled) sendSmsRipple.trigger(m.x, m.y) }
                    onClicked: {
                        if (sendSmsBtn.isEnabled) {
                            root.sendSms(phoneInput.text, messageInput.text);
                            phoneInput.text = "";
                            messageInput.text = "";
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: Theme.primary
                    border.width: 2
                    radius: Theme.cornerRadius
                    visible: parent.activeFocus
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                        if (sendSmsBtn.isEnabled) {
                            root.sendSms(phoneInput.text, messageInput.text);
                            phoneInput.text = "";
                            messageInput.text = "";
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                id: openAppBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                height: 36
                color: "transparent"
                border.width: 0
                activeFocusOnTab: true

                Canvas {
                    id: openAppBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: 4
                    readonly property real bottomLeftRadius: 4
                    readonly property real topRightRadius: Theme.cornerRadius
                    readonly property real bottomRightRadius: Theme.cornerRadius
                    
                    property color fillColor: (openAppArea.containsMouse || openAppBtn.activeFocus) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: (openAppArea.containsMouse || openAppBtn.activeFocus) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
                    readonly property real borderWidth: 1

                    Behavior on fillColor { ColorAnimation { duration: 200 } }
                    Behavior on borderColor { ColorAnimation { duration: 200 } }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        
                        var w = width;
                        var h = height;
                        var r = borderWidth / 2;
                        var x = r;
                        var y = r;
                        w -= borderWidth;
                        h -= borderWidth;
                        
                        ctx.beginPath();
                        ctx.moveTo(x + topLeftRadius, y);
                        ctx.lineTo(x + w - topRightRadius, y);
                        ctx.arcTo(x + w, y, x + w, y + topRightRadius, topRightRadius);
                        ctx.lineTo(x + w, y + h - bottomRightRadius);
                        ctx.arcTo(x + w, y + h, x + w - bottomRightRadius, y + h, bottomRightRadius);
                        ctx.lineTo(x + bottomLeftRadius, y + h);
                        ctx.arcTo(x, y + h, x, y + h - bottomLeftRadius, bottomLeftRadius);
                        ctx.lineTo(x, y + h - bottomLeftRadius);
                        ctx.lineTo(x, y + topLeftRadius);
                        ctx.arcTo(x, y, x + topLeftRadius, y, topLeftRadius);
                        ctx.closePath();
                        
                        ctx.fillStyle = fillColor;
                        ctx.fill();
                        
                        ctx.lineWidth = borderWidth;
                        ctx.strokeStyle = borderColor;
                        ctx.stroke();
                    }
                    
                    onFillColorChanged: requestPaint()
                    onBorderColorChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "open_in_new"
                        size: 16
                        color: (openAppArea.containsMouse || openAppBtn.activeFocus) ? Theme.primary : Theme.surfaceVariantText
                        scale: (openAppArea.containsMouse || openAppBtn.activeFocus) ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: I18n.tr("Open App", "KDE Connect open SMS app button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: (openAppArea.containsMouse || openAppBtn.activeFocus) ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                DankRipple {
                    id: openAppRipple
                    anchors.fill: parent
                    cornerRadius: Theme.cornerRadius
                    rippleColor: Theme.primary
                }

                MouseArea {
                    id: openAppArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(m) { openAppRipple.trigger(m.x, m.y) }
                    onClicked: root.launchApp()
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    color: "transparent"
                    border.color: Theme.primary
                    border.width: 2
                    radius: Theme.cornerRadius
                    visible: parent.activeFocus
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                        root.launchApp();
                        event.accepted = true;
                    }
                }
            }
        }
    }
    }
}
