import QtQuick
import qs.services
import qs.widgets

Rectangle {
    id: root

    property string text: ""
    property string textFont: ""
    property string icon: "chevron"
    property var items: []
    property var current: undefined
    property bool searchable: false
    property int menuWidth: 0

    signal picked(var value)
    signal clicked()

    readonly property bool open: SettingsUi.menu !== null && SettingsUi.menu.anchor === root

    width: SettingsUi.u(200)
    height: SettingsUi.u(30)
    radius: SettingsUi.radius
    color: area.containsMouse || open ? Theme.surface : Theme.highlight
    border.width: 1
    border.color: open ? Theme.accent : Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: SettingsUi.u(12)
        anchors.right: chevron.left
        anchors.rightMargin: SettingsUi.u(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: Theme.text
        font.pixelSize: SettingsUi.u(10)
        font.family: root.textFont !== "" ? root.textFont : Theme.fontFamily
        elide: Text.ElideRight
    }

    LineIcon {
        id: chevron
        anchors.right: parent.right
        anchors.rightMargin: SettingsUi.u(10)
        anchors.verticalCenter: parent.verticalCenter
        kind: root.icon
        size: SettingsUi.u(12)
        rotation: root.icon === "chevron" ? (root.open ? -90 : 90) : 0
        color: Theme.textSecondary
        Behavior on rotation { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked()
            if (root.items.length === 0) return
            if (root.open) {
                SettingsUi.closeMenu()
                return
            }
            SettingsUi.openMenu({
                anchor: root,
                items: root.items,
                current: root.current,
                searchable: root.searchable,
                width: Math.max(root.width, root.menuWidth),
                pick: function (value) { root.picked(value) }
            })
        }
    }

    Component.onDestruction: if (open) SettingsUi.closeMenu()
}
