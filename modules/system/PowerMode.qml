import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property bool here: true
    readonly property bool wanted: Controls.powerModeShown && here

    visible: wanted
    width: parent ? parent.width : 0
    height: wanted ? u(44) : 0
    radius: Theme.radius
    color: area.containsMouse ? Theme.highlight : Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 160 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Controls.cyclePower()
    }

    Rectangle {
        id: badge
        x: root.u(8)
        anchors.verticalCenter: parent.verticalCenter
        width: parent.height - 2 * root.u(8)
        height: width
        radius: Theme.round(width)
        color: Theme.accent

        LineIcon {
            anchors.centerIn: parent
            kind: Controls.powerMode.icon
            size: Math.round(parent.width * 0.55)
            color: Theme.background
        }
    }

    Text {
        anchors.left: badge.right
        anchors.leftMargin: root.u(10)
        anchors.verticalCenter: parent.verticalCenter
        text: "Power mode"
        color: Theme.text
        font.pixelSize: root.u(12)
        font.bold: true
        font.family: Theme.fontFamily
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.u(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.u(8)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Controls.powerMode.label
            color: Theme.accent
            font.pixelSize: root.u(11)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.u(4)

            Repeater {
                model: Controls.powerModes.length
                delegate: Rectangle {
                    required property int index
                    width: root.u(6)
                    height: width
                    radius: Theme.round(width)
                    color: index === Controls.powerProfile ? Theme.accent : Theme.track
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
        }
    }
}
