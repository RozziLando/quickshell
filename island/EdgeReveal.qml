import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// "autoHide": striscia invisibile lungo tutto il bordo alto dello schermo.
// Isola nascosta per le finestre (non in fullscreen): passandoci sopra
// l'isola scende e le finestre le fanno spazio (Island.qml, peek). Mentre è
// scesa la striscia copre tutta la fascia sopra le finestre: l'isola resta
// finché il puntatore non torna all'altezza delle finestre.
// Sta un livello sotto l'isola (Top, l'isola è Overlay): sopra la pillola,
// i cerchi e la zona centrale del bordo (centro di controllo) vince l'isola.
PanelWindow {
    id: edge
    required property var island

    screen: island.screen
    // Come l'isola: al ricaricamento riusata solo se resta sullo stesso
    // schermo (cambiare schermo a una finestra riusata fa crashare Quickshell)
    reloadableId: "edge-" + (island.screen ? island.screen.name : "none")
    // Si ricrea insieme all'isola quando cambiano gli schermi (remapping)
    visible: !island.remapping && island.autoHide && island.autoHidden && !island.fullscreen

    anchors {
        top: true
        left: true
        right: true
    }
    // A riposo pochi pixel sul bordo; con l'isola scesa fino alle finestre:
    // spazio riservato dall'isola + margine alto di Hyprland (gaps_out)
    implicitHeight: island.peek ? island.reservedHeight + gapTop
                                : Math.max(3, Theme.s(3))
    color: "transparent"
    // Non sposta le finestre e non si sposta per lo spazio dell'isola
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Diverso da "quickshell": la regola del vetro di Hyprland (modules/wrule.lua)
    // non la sfoca
    WlrLayershell.namespace: "quickshell-edge"

    // Margine alto delle finestre (general:gaps_out, formato CSS "alto destra
    // basso sinistra"); riletto se la config di Hyprland cambia
    property int gapTop: 0
    Process {
        id: gapsProc
        running: true
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text)
                    const v = parseInt(String(o.css !== undefined ? o.css : o.int).trim().split(/\s+/)[0])
                    edge.gapTop = isNaN(v) ? 0 : v
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") gapsProc.running = true
        }
    }

    Item {
        anchors.fill: parent
        HoverHandler { id: hover }
    }

    Binding {
        target: edge.island
        property: "edgeStripHovered"
        value: hover.hovered && edge.visible
    }
}
