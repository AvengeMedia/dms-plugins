import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets
import Qt5Compat.GraphicalEffects

StyledRect {
    id: root

    property string deviceId: ""
    property var parentPopout: null
    property alias shareText: shareInput.text

    signal close
    signal share(string content, bool isUrl)
    signal shareFile(string path)

    function isUrl(text) {
        return text.startsWith("http://") || text.startsWith("https://");
    }

    property bool isOpen: false

    height: isOpen ? (contentColumn.implicitHeight + Theme.spacingM * 2) : 0
    opacity: isOpen ? 1.0 : 0.0
    visible: isOpen || opacity > 0 || height > 0
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutQuad
        }
    }

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
                name: "share"
                size: 14
                color: Theme.surfaceText
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: I18n.tr("Share", "KDE Connect share dialog title")
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

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: 16
                    color: closeArea.containsMouse ? (Theme.isLightMode ? "#000000" : Theme.error) : Theme.surfaceVariantText
                    rotation: closeArea.containsMouse ? 90 : 0
                    
                    Behavior on color { ColorAnimation { duration: 200 } }
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
            id: shareInput
            width: parent.width
            placeholderText: I18n.tr("Enter URL or text to share", "KDE Connect share input placeholder") + "..."
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                id: shareTextBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                height: 36
                color: "transparent"
                border.width: 0
                
                readonly property bool isEnabled: shareInput.text.length > 0
                opacity: isEnabled ? 1.0 : 0.4

                Canvas {
                    id: shareTextBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: Theme.cornerRadius
                    readonly property real bottomLeftRadius: Theme.cornerRadius
                    readonly property real topRightRadius: 4
                    readonly property real bottomRightRadius: 4
                    
                    property color fillColor: (shareTextBtn.isEnabled && shareTextArea.containsMouse) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: (shareTextBtn.isEnabled && shareTextArea.containsMouse) ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
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
                        name: root.isUrl(shareInput.text) ? "link" : "share"
                        size: 16
                        color: (shareTextBtn.isEnabled && shareTextArea.containsMouse) ? Theme.primary : Theme.surfaceVariantText
                        scale: (shareTextBtn.isEnabled && shareTextArea.containsMouse) ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: root.isUrl(shareInput.text) ? I18n.tr("Share URL", "KDE Connect share URL button") : I18n.tr("Share Text", "KDE Connect share button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: (shareTextBtn.isEnabled && shareTextArea.containsMouse) ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                MouseArea {
                    id: shareTextArea
                    anchors.fill: parent
                    hoverEnabled: shareTextBtn.isEnabled
                    cursorShape: shareTextBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (shareTextBtn.isEnabled) {
                            root.share(shareInput.text, root.isUrl(shareInput.text));
                            shareInput.text = "";
                        }
                    }
                }
            }

            Rectangle {
                id: sendFileBtn
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                height: 36
                color: "transparent"
                border.width: 0

                Canvas {
                    id: sendFileBtnBg
                    anchors.fill: parent
                    
                    readonly property real topLeftRadius: 4
                    readonly property real bottomLeftRadius: 4
                    readonly property real topRightRadius: Theme.cornerRadius
                    readonly property real bottomRightRadius: Theme.cornerRadius
                    
                    property color fillColor: sendFileArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                    property color borderColor: sendFileArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.3) : Theme.withAlpha(Theme.primary, 0.15)
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
                        name: "upload_file"
                        size: 16
                        color: sendFileArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        scale: sendFileArea.containsMouse ? 1.15 : 1.0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    }

                    StyledText {
                        text: I18n.tr("Send File", "KDE Connect send file button")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: sendFileArea.containsMouse ? Theme.primary : Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                MouseArea {
                    id: sendFileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fileBrowser.open()
                }
            }
        }
    }

    FileBrowserSurfaceModal {
        id: fileBrowser

        browserTitle: I18n.tr("Select File to Send", "KDE Connect file browser title")
        browserIcon: "upload_file"
        browserType: "generic"
        showHiddenFiles: false
        fileExtensions: ["*"]
        parentPopout: root.parentPopout

        onFileSelected: function(path) {
            root.shareFile(path);
            close();
        }
    }
}
