import QtQuick
import qs.services

Rectangle {
    id: row

    property string title: ""
    property string subtitle: ""
    property string info: ""
    property bool active: true

    default property alias control: slot.data
    property alias below: belowHost.data
    property bool hasBelow: false

    width: parent ? parent.width : 0
    height: top.height + (hasBelow ? belowHost.implicitHeight + SettingsUi.u(10) : 0)
    radius: SettingsUi.radius
    color: Theme.card
    border.width: 1
    border.color: Theme.cardBorder
    opacity: active ? 1 : 0.45
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
        id: top
        width: parent.width
        height: Math.max(SettingsUi.u(46), labels.implicitHeight + SettingsUi.u(18))

        Column {
            id: labels
            anchors.left: parent.left
            anchors.leftMargin: SettingsUi.u(16)
            anchors.right: slot.left
            anchors.rightMargin: SettingsUi.u(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: SettingsUi.u(2)

            Row {
                spacing: SettingsUi.u(6)
                width: parent.width

                Text {
                    id: titleText
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - SettingsUi.u(22))
                    text: row.title
                    color: Theme.text
                    font.pixelSize: SettingsUi.u(11)
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                InfoDot {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.info
                }
            }

            Text {
                width: parent.width
                visible: row.subtitle !== ""
                text: row.subtitle
                color: Theme.textSecondary
                font.pixelSize: SettingsUi.u(9)
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: slot
            enabled: row.active
            anchors.right: parent.right
            anchors.rightMargin: SettingsUi.u(14)
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    Column {
        id: belowHost
        visible: row.hasBelow
        enabled: row.active
        anchors.top: top.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: SettingsUi.u(16)
        anchors.rightMargin: SettingsUi.u(16)
        anchors.topMargin: -SettingsUi.u(4)
        spacing: SettingsUi.u(6)
    }
}
