import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: badge

    property bool active: false
    readonly property bool hovered: area.containsMouse

    signal clicked()

    visible: active || hovered

    x: -width / 3
    y: -height / 3
    z: 5
    width: SettingsUi.u(18)
    height: width
    radius: Theme.round(width)
    color: area.containsMouse ? Theme.warning : Theme.highlight
    border.width: 1
    border.color: Theme.cardBorder

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.45
        height: Math.max(1, Math.round(SettingsUi.u(2)))
        radius: height / 2
        color: area.containsMouse ? Theme.background : Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -SettingsUi.u(3)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: badge.clicked()
    }
}
