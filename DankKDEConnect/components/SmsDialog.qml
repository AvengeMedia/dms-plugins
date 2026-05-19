import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import Qt5Compat.GraphicalEffects

StyledRect {
    id: root

    property string deviceId: ""

    signal close
    signal sendSms(string phoneNumber, string message)
    signal launchApp

    property bool isOpen: false

    height: isOpen ? (contentColumn.implicitHeight + Theme.spacingM * 2) : 0
    opacity: isOpen ? 1.0 : 0.0
    visible: isOpen || opacity > 0
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
    border.width: 1
    border.color: Theme.withAlpha(Theme.primary, 0.15)
    clip: true

    layer.enabled: true
    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 3
        radius: 12.0
        samples: 24
        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
    }

    Behavior on opacity { NumberAnimation { duration: 200 } }

    Column {
        id: contentColumn
        anchors.fill: parent
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
                color: closeArea.containsMouse ? Theme.withAlpha(Theme.error, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                border.width: 1
                border.color: Theme.withAlpha(Theme.error, closeArea.containsMouse ? 0.3 : 0.15)

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 16
                    color: closeArea.containsMouse ? Theme.error : Theme.surfaceVariantText
                    scale: closeArea.containsMouse ? 1.15 : 1.0
                    rotation: closeArea.containsMouse ? 90 : 0
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        DankTextField {
            id: phoneInput
            width: parent.width
            placeholderText: I18n.tr("Phone number", "KDE Connect SMS phone input placeholder") + "..."
        }

        DankTextField {
            id: messageInput
            width: parent.width
            placeholderText: I18n.tr("Message", "KDE Connect SMS message input placeholder") + "..."
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
                
                readonly property bool isEnabled: phoneInput.text.length > 0 && messageInput.text.length > 0
                opacity: isEnabled ? 1.0 : 0.4

                Canvas {
                    id: sendSmsBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: Theme.cornerRadius
                    readonly property real bottomLeftRadius: Theme.cornerRadius
                    readonly property real topRightRadius: 4
                    readonly property real bottomRightRadius: 4
                    
                    property color fillColor: (sendSmsBtn.isEnabled && sendSmsArea.containsMouse) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: (sendSmsBtn.isEnabled && sendSmsArea.containsMouse) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
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
                        color: (sendSmsBtn.isEnabled && sendSmsArea.containsMouse) ? Theme.primary : Theme.surfaceVariantText
                        scale: (sendSmsBtn.isEnabled && sendSmsArea.containsMouse) ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: I18n.tr("Send", "KDE Connect SMS send button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: (sendSmsBtn.isEnabled && sendSmsArea.containsMouse) ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                MouseArea {
                    id: sendSmsArea
                    anchors.fill: parent
                    hoverEnabled: sendSmsBtn.isEnabled
                    cursorShape: sendSmsBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (sendSmsBtn.isEnabled) {
                            root.sendSms(phoneInput.text, messageInput.text);
                            phoneInput.text = "";
                            messageInput.text = "";
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

                Canvas {
                    id: openAppBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: 4
                    readonly property real bottomLeftRadius: 4
                    readonly property real topRightRadius: Theme.cornerRadius
                    readonly property real bottomRightRadius: Theme.cornerRadius
                    
                    property color fillColor: openAppArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: openAppArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
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
                        color: openAppArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        scale: openAppArea.containsMouse ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: I18n.tr("Open App", "KDE Connect open SMS app button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: openAppArea.containsMouse ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                MouseArea {
                    id: openAppArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchApp()
                }
            }
        }
    }
}
