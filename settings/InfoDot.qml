import QtQuick
import qs.services
import qs.widgets

Item {
    id: root

    property string text: ""

    width: SettingsUi.u(16)
    height: width
    visible: text !== ""

    LineIcon {
        anchors.centerIn: parent
        kind: "info"
        size: SettingsUi.u(13)
        color: area.containsMouse ? Theme.accent : Theme.textMuted
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -SettingsUi.u(3)
        hoverEnabled: true
        onContainsMouseChanged: {
            if (containsMouse) SettingsUi.showTip(root, root.text)
            else SettingsUi.hideTip(root)
        }
    }

    Component.onDestruction: SettingsUi.hideTip(root)
}
