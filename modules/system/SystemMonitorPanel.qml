import QtQuick
import qs.services
import qs.widgets

// Monitor di sistema al centro dell'isola, aperto dal cerchio destro.
// Resta aperto finché non clicchi fuori o di nuovo sul cerchio.
Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "sysmon"
    readonly property bool shown: island.owner === ownerId

    // Stessa scala del centro di controllo di prima (0.88)
    readonly property real sizeFactor: 0.88
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int pad: u(18)
    // topRadius: parte trasparente ai lati della pillola
    readonly property int openWidth: u(330) + 2 * pad + 2 * island.topRadius
    readonly property int openHeight: monitor.implicitHeight + 2 * pad

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        // Prende la tastiera, così Esc lo chiude
        island.open(ownerId, openWidth, openHeight, true)
        island.grabOwner = ownerId
    }

    // Si chiude appena il puntatore esce dall'isola (come il player)
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

    // Se cambia l'altezza (es. arrivano i sensori) si adatta
    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, island.wantsKeyboard)

    SystemMonitor {
        id: monitor
        x: root.pad + root.island.topRadius
        y: root.pad
        width: parent.width - 2 * x
        sizeFactor: root.sizeFactor
        active: root.shown

        visible: root.shown
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
        FadeIn { active: root.shown; pause: 160; duration: 220 }
    }
}
