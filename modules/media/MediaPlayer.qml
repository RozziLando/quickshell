import QtQuick
import Quickshell.Io
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "media"
    readonly property bool shown: island.owner === ownerId

    readonly property var player: view.player
    readonly property int playerCount: view.playerCount
    readonly property bool multi: view.multi

    readonly property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int openWidth: root.u(380)
    readonly property int openHeight: multi ? root.u(128) : root.u(112)

    onShownChanged: if (shown) view.index = view.pickPlaying()

    onPlayerCountChanged: {
        if (playerCount === 0) {
            if (shown) island.close(ownerId)
        } else {
            if (shown) island.open(ownerId, openWidth, openHeight, island.wantsKeyboard)
        }
    }

    Connections {
        target: root.island
        function onHoveredChanged() {
            if (root.island.hovered)
                closeTimer.stop()
            else if (root.shown && !peekTimer.running)
                closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.island.close(root.ownerId)
    }

    function peek() {
        if (!player) return
        if (island.owner !== "" && island.owner !== ownerId) return

        closeTimer.stop()
        island.open(ownerId, openWidth, openHeight)
        peekTimer.restart()
    }

    Timer {
        id: peekTimer
        interval: 2000
        onTriggered: {
            if (!root.island.hovered) root.island.close(root.ownerId)
        }
    }

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        peekTimer.stop()
        closeTimer.stop()
        island.open(ownerId, openWidth, openHeight, true)
        island.grabOwner = ownerId
    }

    IpcHandler {
        target: "media"
        function peek(): void { root.peek() }
    }

    MediaView {
        id: view
        anchors {
            fill: parent
            topMargin: root.u(14)
            bottomMargin: root.u(18)
            leftMargin: root.u(30)
            rightMargin: root.u(30)
        }
        sizeFactor: root.sizeFactor

        visible: root.shown
        FadeIn { active: root.shown; pause: 160; duration: 220 }
    }
}
