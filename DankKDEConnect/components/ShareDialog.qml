import QtQuick
import qs.Common
import qs.Modals.FileBrowser
import qs.Widgets

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

    height: contentColumn.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest

    Column {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        Row {
            width: parent.width

            StyledText {
                text: I18n.tr("Share", "KDE Connect share dialog title")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeBtn.width - 40
                height: 1
            }

            Rectangle {
                id: closeBtn
                width: 28
                height: 28
                radius: 14
                color: closeArea.containsMouse ? Theme.errorHover : "transparent"

                DankIcon {
                    anchors.centerIn: parent
                    name: "close"
                    size: Theme.iconSize - 6
                    color: closeArea.containsMouse ? Theme.error : Theme.surfaceVariantText
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
