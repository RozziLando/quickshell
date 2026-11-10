import QtQuick
import Quickshell.Widgets
import qs.services

Rectangle {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property string icon: ""
    property string iconSource: ""
    property int iconLevel: -1
    property string title: ""
    property string subtitle: ""
    property bool selected: false
    property string trailingIcon: ""
    property bool showRemove: false
    property bool clickable: true
    property bool hasExtra: false

    default property alias extra: extraHost.data

    signal clicked()
    signal removeClicked()

    width: parent ? parent.width : 0
    height: content.implicitHeight + 2 * u(8)
    radius: u(22)
    color: area.containsMouse && clickable ? Theme.surface : Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.u(8)
        }
        spacing: root.u(6)

        Item {
            width: parent.width
            height: root.u(32)

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.clickable
                onClicked: root.clicked()
            }

            Rectangle {
                id: badge
                width: root.u(32)
                height: width
                radius: width / 2
                color: root.selected ? Theme.accent : Theme.highlight
                Behavior on color { ColorAnimation { duration: 150 } }

                LineIcon {
                    anchors.centerIn: parent
                    visible: root.iconSource === ""
                    kind: root.icon
                    level: root.iconLevel
                    size: root.u(16)
                    color: root.selected ? Theme.background : Theme.text
                }

                IconImage {
                    id: rowIcon
                    anchors.centerIn: parent
                    backer.sourceSize.width: Theme.px(rowIcon.actualSize, rowIcon)
                    backer.sourceSize.height: Theme.px(rowIcon.actualSize, rowIcon)
                    visible: root.iconSource !== ""
                    source: root.iconSource
                    implicitSize: root.u(20)
                }
            }

            Column {
                anchors {
                    left: badge.right
                    leftMargin: root.u(10)
                    right: trailing.left
                    rightMargin: root.u(8)
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width
                    text: root.title
                    color: Theme.text
                    font.pixelSize: root.u(11)
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    color: Theme.textSecondary
                    font.pixelSize: root.u(9)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            Row {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: root.u(6)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(12)

                LineIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.trailingIcon !== ""
                    kind: root.trailingIcon
                    size: root.u(13)
                    color: Theme.textSecondary
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showRemove
                    width: root.u(16)
                    height: root.u(16)

                    LineIcon {
                        anchors.centerIn: parent
                        kind: "close"
                        size: root.u(10)
                        color: removeArea.containsMouse ? Theme.text : Theme.textMuted
                    }

                    MouseArea {
                        id: removeArea
                        anchors.fill: parent
                        anchors.margins: -root.u(5)
                        hoverEnabled: true
                        onClicked: root.removeClicked()
                    }
                }
            }
        }

        Column {
            id: extraHost
            visible: root.hasExtra
            width: parent.width
            spacing: root.u(4)
        }
    }
}
