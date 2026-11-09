import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

// OSD: quando volume o luminosità cambiano dai tasti, l'isola scende con la
// sola barra (stile del centro di controllo), poi torna all'orologio
Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "osd"
    readonly property bool shown: island.owner === ownerId

    // Dimensione dell'OSD: 0.88 = come il centro di controllo, ora +10%
    readonly property real sizeFactor: 0.968
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int sliderH: u(24)
    // Staccata: alta esattamente come l'orologio, barra centrata in verticale
    // e stesso margine ai lati (topRadius = parte trasparente ai lati)
    readonly property int topPad: island.floating ? Math.floor((island.idleH - sliderH) / 2) : u(12)
    readonly property int bottomPad: island.floating ? island.idleH - sliderH - topPad : u(16)
    readonly property int sidePad: island.floating ? island.topRadius + topPad : u(24)
    readonly property int openWidth: u(280)   // era 340
    readonly property int openHeight: topPad + sliderH + bottomPad

    // Quanto resta visibile dopo l'ultimo cambio (ms)
    property int timeout: 1500

    // "volume", "display" o "keyboard"
    property string kind: "volume"

    // ---------- Audio ----------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // All'avvio i valori arrivano "cambiando": non vanno mostrati
    property bool ready: false
    Timer {
        interval: 2500
        running: true
        onTriggered: root.ready = true
    }

    // Cambiando dispositivo d'uscita il volume "cambia": non è un tasto
    property bool sinkSwitching: false
    onSinkChanged: {
        sinkSwitching = true
        sinkSettle.restart()
    }
    Timer {
        id: sinkSettle
        interval: 800
        onTriggered: root.sinkSwitching = false
    }

    Connections {
        target: root.audioAvailable ? root.sink.audio : null
        function onVolumeChanged() { if (!root.sinkSwitching) root.show("volume") }
        function onMutedChanged() { if (!root.sinkSwitching) root.show("volume") }
    }

    // ---------- Luminosità ----------
    Connections {
        target: Brightness
        function onDisplayChangedExternally() { root.show("display") }
        function onKeyboardChangedExternally() { root.show("keyboard") }
    }

    // ---------- Logica ----------
    function show(which) {
        if (!ready) return
        // Mai sopra launcher o centro di controllo (lì la barra c'è già)
        var o = island.owner
        if (o !== "" && o !== ownerId && o !== "media" && o !== "notif") return

        kind = which
        island.open(ownerId, openWidth, openHeight)
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: root.timeout
        onTriggered: {
            // Resta aperto finché ci sei sopra o stai trascinando
            if (root.island.hovered || slider.dragging) restart()
            else root.island.close(root.ownerId)
        }
    }

    // ---------- Interfaccia ----------
    // Solo la barra, senza riquadro né titolo
    MiniSlider {
        id: slider
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.sidePad
            rightMargin: root.sidePad
            topMargin: root.topPad
        }
        height: root.sliderH
        sizeFactor: root.sizeFactor
        showPercent: false

        icon: root.kind === "volume" ? "volume"
              : root.kind === "display" ? "sun" : "keyboard"
        value: root.kind === "volume" ? (root.audioAvailable ? root.sink.audio.volume : 0)
             : root.kind === "display" ? Brightness.displayLevel : Brightness.keyboardLevel
        muted: root.kind === "volume" && root.audioAvailable && root.sink.audio.muted

        onMoved: value => {
            if (root.kind === "volume") {
                if (root.audioAvailable)
                    root.sink.audio.volume = Math.max(0, Math.min(1, value))
            } else if (root.kind === "display") {
                Brightness.setDisplay(value)
            } else {
                Brightness.setKeyboard(value)
            }
            hideTimer.restart()
        }
        onIconClicked: {
            if (root.kind === "volume" && root.audioAvailable) root.sink.audio.muted = !root.sink.audio.muted
        }

        // Si nasconde di colpo, compare in dissolvenza (come gli altri moduli)
        visible: root.shown
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
        FadeIn { active: root.shown; pause: 120; duration: 180 }
    }
}
