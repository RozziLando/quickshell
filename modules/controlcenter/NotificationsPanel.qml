import QtQuick
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    required property var notifications

    anchors.fill: parent

    readonly property string ownerId: "inbox"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int edgePad: u(14)
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int openWidth: u(436)
    readonly property int openHeight: 2 * edgePad + card.height
    readonly property int panelRadius: Theme.radius + edgePad * Theme.roundness

    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, false, panelRadius)

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        island.open(ownerId, openWidth, openHeight, false, panelRadius)
        island.grabOwner = ownerId
    }

    Connections {
        target: root.island
        function onHoveredChanged() {
            if (root.island.hovered) closeTimer.stop()
            else if (root.shown) closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 400
        onTriggered: root.island.close(root.ownerId)
    }

    NotificationCard {
        id: card
        x: root.sidePad
        y: root.edgePad
        width: parent.width - 2 * root.sidePad
        visible: root.shown
        notifications: root.notifications
        sizeFactor: root.sizeFactor
        maxVisible: 6
        framed: false
        onActivated: root.island.close(root.ownerId)
        FadeIn { active: root.shown; pause: 140; duration: 200 }
    }
}
