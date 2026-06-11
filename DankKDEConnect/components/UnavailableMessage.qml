import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    height: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)

    Column {
        id: contentColumn
        anchors.centerIn: parent
        width: Math.max(0, parent.width - Theme.spacingL * 2)
        spacing: Theme.spacingS

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacingS

            DankIcon {
                name: "error"
                size: Theme.iconSize
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: I18n.tr("Phone Connect Not Available", "Phone Connect unavailable error title")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.error
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            text: I18n.tr("Start KDE Connect or Valent to use this plugin", "Phone Connect daemon hint")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.error
            opacity: 0.8
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
