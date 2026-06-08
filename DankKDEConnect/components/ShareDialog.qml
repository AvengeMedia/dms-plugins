import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets
import qs.Services


StyledRect {
    id: root

    focus: true
    Keys.onEscapePressed: (event) => {
        root.close();
        event.accepted = true;
    }

    property string deviceId: ""
    property var parentPopout: null
    property alias shareText: shareInput.text

    signal close
    signal share(string content, bool isUrl)
    signal shareFile(string path)
    signal shareClipboard()

    function isUrl(text) {
        return text.startsWith("http://") || text.startsWith("https://");
    }

    property bool isOpen: false
    onIsOpenChanged: {
        if (isOpen) {
            shareInput.forceActiveFocus();
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
                    id: closeRipple
                    anchors.fill: parent
                    cornerRadius: parent.radius
                    rippleColor: Theme.error
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(m) { closeRipple.trigger(m.x, m.y) }
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

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            DankTextField {
                id: shareInput
                Layout.fillWidth: true
                placeholderText: I18n.tr("Enter URL or text to share", "KDE Connect share input placeholder") + "..."
                activeFocusOnTab: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (text.trim().length > 0) {
                            root.share(text, root.isUrl(text));
                            text = "";
                            event.accepted = true;
                        }
                    }
                }
            }

            Rectangle {
                id: quickClipboardBtn
                width: 36
                height: shareInput.height
                radius: Theme.cornerRadius
                color: quickClipboardBtnArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, quickClipboardBtnArea.containsMouse ? 0.3 : 0.15)
                activeFocusOnTab: true
                
                function triggerClipboardShare() {
                    Proc.runCommand(null, ["wl-paste"], function(stdout, exitCode) {
                        let content = stdout || "";
                        content = content.trim();
                        if (content.length > 0) {
                            shareInput.text = content;
                            root.share(shareInput.text, root.isUrl(shareInput.text));
                            shareInput.text = "";
                        } else {
                            if (typeof ToastService !== "undefined")
                                ToastService.showError(I18n.tr("Clipboard is empty or wl-paste failed."));
                        }
                    });
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: "content_paste"
                    size: 16
                    color: quickClipboardBtnArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                }

                DankRipple {
                    id: clipboardRipple
                    anchors.fill: parent
                    cornerRadius: parent.radius
                    rippleColor: Theme.primary
                }

                MouseArea {
                    id: quickClipboardBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(m) { clipboardRipple.trigger(m.x, m.y) }
                    onClicked: quickClipboardBtn.triggerClipboardShare()
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
                        quickClipboardBtn.triggerClipboardShare();
                        event.accepted = true;
                    }
                }
            }
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
                activeFocusOnTab: isEnabled

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

                DankRipple {
                    id: shareTextRipple
                    anchors.fill: parent
                    cornerRadius: Theme.cornerRadius
                    rippleColor: Theme.primary
                    enabled: shareTextBtn.isEnabled
                }

                MouseArea {
                    id: shareTextArea
                    anchors.fill: parent
                    hoverEnabled: shareTextBtn.isEnabled
                    cursorShape: shareTextBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: function(m) { if (shareTextBtn.isEnabled) shareTextRipple.trigger(m.x, m.y) }
                    onClicked: {
                        if (shareTextBtn.isEnabled) {
                            root.share(shareInput.text, root.isUrl(shareInput.text));
                            shareInput.text = "";
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
                        if (shareTextBtn.isEnabled) {
                            root.share(shareInput.text, root.isUrl(shareInput.text));
                            shareInput.text = "";
                            event.accepted = true;
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
                activeFocusOnTab: true

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

                DankRipple {
                    id: sendFileRipple
                    anchors.fill: parent
                    cornerRadius: Theme.cornerRadius
                    rippleColor: Theme.primary
                }

                MouseArea {
                    id: sendFileArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(m) { sendFileRipple.trigger(m.x, m.y) }
                    onClicked: fileBrowser.open()
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
                        fileBrowser.open();
                        event.accepted = true;
                    }
                }
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
