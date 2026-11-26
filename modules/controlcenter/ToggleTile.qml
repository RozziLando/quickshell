import QtQuick
import qs.services
import qs.widgets

Card {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }
    property string kind: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked()
    signal toggled()

    property real cornerRadius: Theme.radius
    radius: Math.min(cornerRadius, height / 2)
    color: area.containsMouse ? Theme.surface : Theme.card
    Behavior on color { ColorAnimation { duration: 150 } }

    scale: area.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    readonly property int pad: Math.round(height * 0.12)

    Rectangle {
        id: badge
        width: root.height - 2 * root.pad
        height: width
        radius: Theme.round(width)
        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        color: root.active ? Theme.accent : Theme.highlight
        Behavior on color { ColorAnimation { duration: 150 } }

        LineIcon {
            anchors.centerIn: parent
            kind: root.kind
            size: Math.round(badge.width * 0.46)
            color: root.active ? Theme.background : Theme.text
        }

        z: 1
        MouseArea {
            id: badgeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.toggled()
        }
    }

    Column {
        anchors {
            left: badge.right
            leftMargin: root.u(10)
            right: parent.right
            rightMargin: root.u(12)
            verticalCenter: parent.verticalCenter
        }
        spacing: root.u(1)

        Text {
            width: parent.width
            text: root.title
            color: Theme.text
            font.pixelSize: root.u(12)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: root.u(9)
            font.bold: true
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: root.subtitle
            color: Theme.textSecondary
            font.pixelSize: root.u(10)
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: root.u(8)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}
