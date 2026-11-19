import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: root

    property bool paired: false
    property string tip: ""
    property color tint: Theme.accent
    property color base: Theme.background
    property color ink: Theme.text

    signal clicked()

    width: SettingsUi.u(24)
    height: width
    radius: width / 2
    color: paired || area.containsMouse ? tint : Qt.rgba(base.r, base.g, base.b, 0.85)
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.25)
    Behavior on color { ColorAnimation { duration: 120 } }

    LineIcon {
        anchors.centerIn: parent
        kind: "pencil"
        size: SettingsUi.u(12)
        color: root.paired || area.containsMouse ? root.base : root.ink
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -SettingsUi.u(3)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            SettingsUi.hideTip(root)
            root.clicked()
        }
        onContainsMouseChanged: {
            if (containsMouse && root.tip !== "") SettingsUi.showTip(root, root.tip)
            else SettingsUi.hideTip(root)
        }
    }

    Component.onDestruction: SettingsUi.hideTip(root)
}
