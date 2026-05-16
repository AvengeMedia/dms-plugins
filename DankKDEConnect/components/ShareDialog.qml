import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets
import Qt5Compat.GraphicalEffects

StyledRect {
    id: root

    property string deviceId: ""
    property var parentPopout: null

    signal close
    signal share(string content, bool isUrl)
    signal shareFile(string path)

    function isUrl(text) {
        return text.startsWith("http://") || text.startsWith("https://");
    }

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
            id: shareInput
            width: parent.width
            placeholderText: I18n.tr("Enter URL or text to share", "KDE Connect share input placeholder") + "..."
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankButton {
                text: root.isUrl(shareInput.text) ? I18n.tr("Share URL", "KDE Connect share URL button") : I18n.tr("Share Text", "KDE Connect share button")
                iconName: root.isUrl(shareInput.text) ? "link" : "share"
                enabled: shareInput.text.length > 0
                onClicked: {
                    root.share(shareInput.text, root.isUrl(shareInput.text));
                    shareInput.text = "";
                }
            }

            DankButton {
                text: I18n.tr("Send File", "KDE Connect send file button")
                iconName: "upload_file"
                onClicked: fileBrowser.open()
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

        onFileSelected: path => {
            root.shareFile(path);
            close();
        }
    }
}
