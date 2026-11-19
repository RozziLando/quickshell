import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool busy: false

    signal clicked()

    readonly property color fg: primary ? Theme.background : Theme.text

    width: content.implicitWidth + 2 * SettingsUi.u(12)
    height: SettingsUi.u(28)
    radius: SettingsUi.radius
    color: primary ? (area.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
                   : (area.containsMouse ? Theme.surface : Theme.highlight)
    border.width: primary ? 0 : 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }

    scale: area.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: SettingsUi.u(6)

        LineIcon {
            id: buttonIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            kind: root.icon
            size: SettingsUi.u(13)
            color: root.fg
            RotationAnimation on rotation {
                running: root.busy
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                onRunningChanged: if (!running) buttonIcon.rotation = 0
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.fg
            font.pixelSize: SettingsUi.u(10)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
