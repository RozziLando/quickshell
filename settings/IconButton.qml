import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: root

    property string icon: ""
    property string tip: ""

    signal clicked()

    width: SettingsUi.u(24)
    height: width
    radius: Theme.round(width)
    color: area.containsMouse ? Theme.surface : Theme.highlight
    border.width: 1
    border.color: Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }

    LineIcon {
        anchors.centerIn: parent
        kind: root.icon
        size: SettingsUi.u(12)
        color: Theme.text
    }

    MouseArea {
        id: area
        anchors.fill: parent
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
