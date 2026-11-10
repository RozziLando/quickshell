import QtQuick
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "sysmon"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.88
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int pad: u(18)
    readonly property int openWidth: u(330) + 2 * pad + 2 * island.topRadius
    readonly property int openHeight: monitor.implicitHeight + 2 * pad

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        island.open(ownerId, openWidth, openHeight, true)
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
        interval: 250
        onTriggered: root.island.close(root.ownerId)
    }

    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, island.wantsKeyboard)

    SystemMonitor {
        id: monitor
        x: root.pad + root.island.topRadius
        y: root.pad
        width: parent.width - 2 * x
        sizeFactor: root.sizeFactor
        active: root.shown

        visible: root.shown
        FadeIn { active: root.shown; pause: 160; duration: 220 }
    }
}
