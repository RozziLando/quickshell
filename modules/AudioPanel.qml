import QtQuick
import qs.services
import qs.widgets
import qs.modules.controlcenter
import qs.modules.media

Item {
    id: root
    required property var island

    anchors.fill: parent

    readonly property string ownerId: "audio"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int edgePad: u(14)
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int gap: u(10)
    readonly property bool hasMedia: media.playerCount > 0
    readonly property int mediaH: hasMedia ? Theme.s(media.multi ? 112 : 96) : 0
    readonly property int pageH: Math.max(u(120), Math.min(u(390), audioPage.naturalHeight + u(10)))
    readonly property int openWidth: u(436)
    readonly property int openHeight: edgePad + (hasMedia ? mediaH + gap : 0) + pageH + edgePad
    readonly property int panelRadius: Theme.radius + edgePad * Theme.roundness

    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, false, panelRadius)
    onShownChanged: if (shown) media.index = media.pickPlaying()

    function open() {
        island.open(ownerId, openWidth, openHeight, false, panelRadius)
        island.grabOwner = ownerId
    }

    function toggle() {
        if (shown) island.close(ownerId)
        else open()
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
        onTriggered: {
            if (audioPage.busy) restart()
            else root.island.close(root.ownerId)
        }
    }

    Item {
        anchors {
            fill: parent
            topMargin: root.edgePad
            bottomMargin: root.edgePad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        visible: root.shown
        FadeIn { active: root.shown; pause: 140; duration: 200 }

        Card {
            id: mediaCard
            visible: root.hasMedia
            width: parent.width
            height: root.mediaH
            radius: Theme.radius

            MediaView {
                id: media
                anchors.fill: parent
                anchors.margins: root.u(14)
                sizeFactor: 0.9
                active: root.shown
            }
        }

        AudioPage {
            id: audioPage
            y: root.hasMedia ? root.mediaH + root.gap : 0
            width: parent.width
            height: root.pageH
            sizeFactor: root.sizeFactor
            showBack: false
            bottomGap: root.u(6)
        }
    }
}
