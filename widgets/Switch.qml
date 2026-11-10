import QtQuick
import qs.services

Rectangle {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property bool checked: false
    signal toggled()

    width: u(40)
    height: u(22)
    radius: height / 2
    color: checked ? Theme.accent : Theme.highlight
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: parent.height - root.u(6)
        height: width
        radius: width / 2
        y: root.u(3)
        x: root.checked ? parent.width - width - root.u(3) : root.u(3)
        color: root.checked ? Theme.background : Theme.text
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -root.u(4)
        onClicked: root.toggled()
    }
}
