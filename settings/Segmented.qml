import QtQuick
import qs.services

Rectangle {
    id: root

    property var options: []
    property string current: ""

    signal picked(string value)

    width: row.implicitWidth + 2 * SettingsUi.u(3)
    height: SettingsUi.u(30)
    radius: Math.min(SettingsUi.radius, height / 2)
    color: Theme.track

    Row {
        id: row
        anchors.centerIn: parent
        spacing: SettingsUi.u(2)

        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.value === root.current
                width: label.implicitWidth + 2 * SettingsUi.u(12)
                height: root.height - 2 * SettingsUi.u(3)
                radius: Math.min(SettingsUi.radius, height / 2)
                color: on ? Theme.accent : (area.containsMouse ? Theme.surface : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.on ? Theme.background : Theme.text
                    font.pixelSize: SettingsUi.u(10)
                    font.weight: parent.on ? Font.DemiBold : Font.Normal
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (!parent.on) root.picked(modelData.value)
                }
            }
        }
    }
}
