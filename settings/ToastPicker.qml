import QtQuick
import qs.services

Rectangle {
    id: root

    property string current: "top-right"
    signal picked(string value)

    width: SettingsUi.u(150)
    height: SettingsUi.u(86)
    radius: Math.min(SettingsUi.radius, height / 4)
    color: Theme.track
    border.width: 1
    border.color: Theme.cardBorder

    readonly property var spots: [
        { value: "top-left", x: 0, y: 0 }, { value: "top", x: 0.5, y: 0 }, { value: "top-right", x: 1, y: 0 },
        { value: "bottom-left", x: 0, y: 1 }, { value: "bottom", x: 0.5, y: 1 }, { value: "bottom-right", x: 1, y: 1 }
    ]

    Repeater {
        model: root.spots
        delegate: Rectangle {
            required property var modelData
            readonly property bool on: modelData.value === root.current
            readonly property int pad: SettingsUi.u(8)
            width: SettingsUi.u(34)
            height: SettingsUi.u(14)
            radius: Math.min(Theme.radius, height / 2)
            x: pad + modelData.x * (root.width - width - 2 * pad)
            y: pad + modelData.y * (root.height - height - 2 * pad)
            color: on ? Theme.accent : (area.containsMouse ? Theme.textMuted : Theme.highlight)
            Behavior on color { ColorAnimation { duration: 120 } }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -SettingsUi.u(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(modelData.value)
            }
        }
    }
}
