import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    spacing: Theme.spacingS

    StyledText {
        text: I18n.trFor("dankKDEConnect", "No devices found", "KDE Connect no devices message")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        anchors.horizontalCenter: parent.horizontalCenter
    }

    StyledText {
        text: I18n.trFor("dankKDEConnect", "Make sure KDE Connect or Valent is running on your other devices", "Phone Connect hint message")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        opacity: 0.7
        width: parent.width
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
