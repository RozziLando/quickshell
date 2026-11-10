import QtQuick
import qs.services

Card {
    id: root
    property string kind: ""
    property bool active: false
    property color activeColor: Theme.accent
    property color iconColor: active ? Theme.background : Theme.text
    property int size: Theme.s(52)
    readonly property bool hovered: area.containsMouse
    signal clicked()

    width: size
    height: size
    radius: size / 2

    color: active ? (area.containsMouse ? Qt.lighter(activeColor, 1.12) : activeColor)
                  : (area.containsMouse ? Theme.surface : Theme.card)
    border.color: active ? activeColor : Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: area.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    LineIcon {
        anchors.centerIn: parent
        kind: root.kind
        size: Math.round(root.size * 0.42)
        color: root.iconColor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
