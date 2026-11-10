import QtQuick
import qs.services
import qs.widgets

Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property string title: ""
    property bool showSwitch: false
    property bool switchOn: false

    signal back()
    signal switchToggled()

    default property alias content: body.data

    onVisibleChanged: if (visible) scrollToTop()
    function scrollToTop() { flick.contentY = 0 }

    Keys.onEscapePressed: root.back()

    Item {
        id: header
        width: parent.width
        height: root.u(34)

        Rectangle {
            id: backButton
            width: root.u(32)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backArea.containsMouse ? Theme.surface : Theme.card
            border.width: 1
            border.color: Theme.cardBorder
            Behavior on color { ColorAnimation { duration: 150 } }

            LineIcon {
                anchors.centerIn: parent
                kind: "back"
                size: root.u(16)
                color: Theme.text
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.back()
            }
        }

        Text {
            anchors.left: backButton.right
            anchors.leftMargin: root.u(12)
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.text
            font.pixelSize: root.u(15)
            font.bold: true
            font.family: Theme.fontFamily
        }

        Switch {
            visible: root.showSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sizeFactor: root.sizeFactor
            checked: root.switchOn
            onToggled: root.switchToggled()
        }
    }

    Flickable {
        id: flick
        anchors {
            top: header.bottom
            topMargin: root.u(10)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
            spacing: root.u(6)
        }
    }
}
