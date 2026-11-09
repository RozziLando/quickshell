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

    // ---------- Player ----------
    readonly property var player: view.player
    readonly property int playerCount: view.playerCount
    readonly property bool multi: view.multi

    // Dimensione del player: 1 = misura originale, 0.8 = 20% più piccolo
    readonly property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int openWidth: root.u(380)
    readonly property int openHeight: multi ? root.u(128) : root.u(112)

    // All'apertura parte dal player che sta suonando
    onShownChanged: if (shown) view.index = view.pickPlaying()

    // Se cambia il numero di player mentre l'isola è aperta, adatta l'altezza
    onPlayerCountChanged: {
        if (playerCount === 0) {
            if (shown) island.close(ownerId)
        } else {
            if (shown) island.open(ownerId, openWidth, openHeight, island.wantsKeyboard)
        }
    }

    // ---------- Chiusura con l'hover ----------
    // Il player non si apre più con il mouse: se però è aperto (peek)
    // e ci passi sopra, resta aperto finché non esci
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

    // ---------- Peek (apparizione breve da comando) ----------
    function peek() {
        if (!player) return
        // Non interrompe launcher o notifiche
        if (island.owner !== "" && island.owner !== ownerId) return

        closeTimer.stop()
        island.open(ownerId, openWidth, openHeight)
        peekTimer.restart()
    }

    Timer {
        id: peekTimer
        interval: 2000
        onTriggered: {
            // Se ci sei sopra col mouse resta aperto: lo chiuderà l'uscita dell'hover
            if (!root.island.hovered) root.island.close(root.ownerId)
        }
    }

    // ---------- Apertura dal cerchio sinistro ----------
    // Resta aperto finché non clicchi fuori o di nuovo sul cerchio
    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        peekTimer.stop()
        closeTimer.stop()
        // Aperto da te: prende la tastiera, così Esc lo chiude
        island.open(ownerId, openWidth, openHeight, true)
        island.grabOwner = ownerId
    }

    IpcHandler {
        target: "media"
        function peek(): void { root.peek() }
    }

    // ---------- Interfaccia ----------
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

        // Senza player mostra la stessa grafica vuota (♪, "Nothing playing")
        visible: root.shown
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
        FadeIn { active: root.shown; pause: 160; duration: 220 }
    }
}
