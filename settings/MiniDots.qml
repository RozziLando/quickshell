import QtQuick
import qs.services

Row {
    id: dots

    property int count: 1
    property color tone: Theme.track
    property real size: SettingsUi.u(3)

    spacing: size

    Repeater {
        model: dots.count
        delegate: Rectangle {
            width: dots.size
            height: dots.size
            radius: Theme.round(width)
            color: dots.tone
        }
    }
}
