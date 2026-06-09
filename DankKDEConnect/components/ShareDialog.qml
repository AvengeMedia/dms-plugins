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
    signal share(string content, bool isUri)
    signal shareFile(string path)

    function isUri(text) {
        const value = text.trim();
        if (!/^[A-Za-z][A-Za-z0-9+.-]*:/.test(value))
            return false;

        return /^(([^:/?#]+):)?(\/\/([^/?#]*))?([^?#]*)(\?([^#]*))?(#(.*))?$/.test(value);
    }

    function shareInputContent(asUri) {
        const content = shareInput.text;
        const value = content.trim();
        if (value.length === 0 || (asUri && !root.isUri(value)))
            return;

        root.share(asUri ? value : content, asUri);
        shareInput.text = "";
    }

    component ShareActionButton: StyledRect {
        id: actionRoot

        property string label: ""
        property string iconName: ""
        property bool isEnabled: true

        signal clicked

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        height: 36
        radius: Theme.cornerRadius
        color: (isEnabled && actionArea.containsMouse) ? Theme.withAlpha(Theme.primary, 0.15) : Theme.withAlpha(Theme.surfaceContainer, 0.4)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, (isEnabled && actionArea.containsMouse) ? 0.3 : 0.15)
        opacity: isEnabled ? 1.0 : 0.4
        activeFocusOnTab: isEnabled

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: actionRoot.iconName
                size: 16
                color: (actionRoot.isEnabled && actionArea.containsMouse) ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: actionRoot.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: (actionRoot.isEnabled && actionArea.containsMouse) ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        DankRipple {
            id: actionRipple
            anchors.fill: parent
            cornerRadius: parent.radius
            rippleColor: Theme.primary
            enabled: actionRoot.isEnabled
        }

        MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: actionRoot.isEnabled
            cursorShape: actionRoot.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: function(m) { if (actionRoot.isEnabled) actionRipple.trigger(m.x, m.y) }
            onClicked: {
                if (actionRoot.isEnabled)
                    actionRoot.clicked();
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
                if (actionRoot.isEnabled) {
                    actionRoot.clicked();
                    event.accepted = true;
                }
            }
        }
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
                placeholderText: I18n.tr("Enter URI or text to share", "KDE Connect share input placeholder") + "..."
                activeFocusOnTab: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (text.trim().length > 0) {
                            root.shareInputContent(root.isUri(text));
                            event.accepted = true;
                        }
                    }
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: Theme.spacingS

            ShareActionButton {
                label: I18n.tr("URI", "KDE Connect share URI button")
                iconName: "link"
                isEnabled: root.isUri(shareInput.text)
                onClicked: root.shareInputContent(true)
            }

            ShareActionButton {
                label: I18n.tr("Text", "KDE Connect share text button")
                iconName: "notes"
                isEnabled: shareInput.text.trim().length > 0
                onClicked: root.shareInputContent(false)
            }

            ShareActionButton {
                label: I18n.tr("File", "KDE Connect send file button")
                iconName: "upload_file"
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
