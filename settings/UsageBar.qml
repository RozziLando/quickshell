import QtQuick
import qs.services

Column {
    id: bar

    property string title: ""
    property string value: ""
    property real fraction: 0
    property bool warn: fraction > 0.9

    width: parent ? parent.width : 0
    spacing: SettingsUi.u(5)

    Item {
        width: parent.width
        height: titleText.implicitHeight

        Text {
            id: titleText
            text: bar.title
            color: Theme.textSecondary
            font.pixelSize: SettingsUi.u(10)
            font.family: Theme.fontFamily
        }
        Text {
            anchors.right: parent.right
            text: bar.value
            color: bar.warn ? Theme.warning : Theme.text
            font.pixelSize: SettingsUi.u(10)
            font.bold: true
            font.family: Theme.fontFamily
        }
    }

    Rectangle {
        width: parent.width
        height: SettingsUi.u(6)
        radius: height / 2
        color: Theme.track

        Rectangle {
            height: parent.height
            radius: height / 2
            width: parent.width * Math.max(0, Math.min(1, bar.fraction))
            color: bar.warn ? Theme.warning : Theme.accent
            Behavior on width { NumberAnimation { duration: 400 } }
        }
    }
}
