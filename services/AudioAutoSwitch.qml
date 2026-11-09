import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// Cuffie collegate -> uscita audio automatica.
//  - Bluetooth / USB: compare una nuova uscita, diventa quella predefinita
//    (gli schermi HDMI/DisplayPort no: collegare un monitor non ruba l'audio)
//  - Jack: stessa scheda audio, cambia la porta. Quando la porta "Headphones"
//    diventa disponibile si passa lì; staccandole si torna agli altoparlanti
// Scollegando cuffie Bluetooth/USB è PipeWire a tornare all'uscita di prima.
Item {
    id: root

    // ---------- Bluetooth / USB ----------
    // Uscite presenti all'avvio: non contano come "appena collegate"
    property var knownSinks: ({})
    property bool started: false

    function isOutputDevice(n) {
        return n && n.isSink && !n.isStream && n.audio
    }

    function isHeadsetLike(n) {
        var name = String(n.name || "")
        if (/hdmi|displayport/i.test(name)) return false
        if (name.indexOf("bluez_output") === 0) return true
        if (/usb/i.test(name)) return true
        var p = n.properties || {}
        var ff = String(p["device.form-factor"] || "").toLowerCase()
        return ["headphone", "headset", "hands-free", "handset"].indexOf(ff) >= 0
    }

    function scanSinks() {
        var nodes = Pipewire.nodes.values
        var now = {}
        for (var i = 0; i < nodes.length; i++) {
            var n = nodes[i]
            if (!isOutputDevice(n)) continue
            now[n.id] = true
            if (started && !knownSinks[n.id] && isHeadsetLike(n)) {
                console.log("Cuffie collegate, uscita audio:", n.description || n.name)
                Pipewire.preferredDefaultAudioSink = n
            }
        }
        knownSinks = now
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.scanSinks() }
    }

    // Lascia a PipeWire il tempo di elencare le uscite già presenti
    Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.scanSinks()
            root.started = true
        }
    }

    // ---------- Jack (porta della scheda) ----------
    // Stato precedente delle porte cuffie: "sink|porta" -> disponibile
    property var portState: ({})
    property bool portsKnown: false

    // Elenco delle uscite con le porte: services/AudioPorts (un solo pactl
    // per tutta la shell), aggiornato a ogni cambio
    Connections {
        target: AudioPorts
        function onSinksChanged() {
            var sinks = AudioPorts.sinks
            var state = {}
            sinks.forEach(function (s) {
                var ports = s.ports || []
                ports.forEach(function (p) {
                    if (!/headphone|headset/i.test(p.name + " " + (p.type || ""))) return
                    var key = s.name + "|" + p.name
                    var avail = p.availability !== "not available"
                    state[key] = avail
                    if (!root.portsKnown || root.portState[key] === avail) return
                    if (avail && s.active_port !== p.name) {
                        // Inserite: porta cuffie e uscita predefinita
                        Quickshell.execDetached(["sh", "-c",
                            'pactl set-sink-port "$1" "$2"; pactl set-default-sink "$1"',
                            "sh", s.name, p.name])
                    } else if (!avail && s.active_port === p.name) {
                        // Staccate: prima porta disponibile che non sia di cuffie
                        var other = ports.filter(function (q) {
                            return q.availability !== "not available"
                                && !/headphone|headset/i.test(q.name + " " + (q.type || ""))
                        })[0]
                        if (other) Quickshell.execDetached(["pactl", "set-sink-port", s.name, other.name])
                    }
                })
            })
            root.portState = state
            root.portsKnown = true
        }
    }

}
