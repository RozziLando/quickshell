pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Porte delle schede audio (jack delle cuffie), lette con pactl: PipeWire
// via Quickshell non le espone. Un solo "pactl subscribe" per tutta la shell
// (icona dell'audio e cambio automatico dell'uscita).
// pactl: "libpulse" su Arch, "pulseaudio-utils" su Fedora. Se manca, qui
// non succede nulla (si riconoscono solo le cuffie Bluetooth / USB).
Singleton {
    id: root

    // Uscite come le dà "pactl -f json list sinks" e nome di quella predefinita
    property var sinks: []
    property string defaultSink: ""
    // false se pactl non c'è: niente tentativi a vuoto
    property bool available: true

    // La porta attiva dell'uscita predefinita è quella delle cuffie?
    readonly property bool headphonePort: {
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].name !== defaultSink) continue
            return /headphone|headset/.test(String(sinks[i].active_port || "").toLowerCase())
        }
        return false
    }

    function refresh() { queryLater.restart() }

    Process {
        id: query
        command: ["sh", "-c", "pactl get-default-sink; pactl -f json list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                var nl = text.indexOf("\n")
                if (nl < 0) return
                try {
                    var list = JSON.parse(text.substring(nl + 1))
                    root.defaultSink = text.substring(0, nl).trim()
                    root.sinks = list
                } catch (e) {}
            }
        }
    }

    Timer {
        id: queryLater
        interval: 150
        onTriggered: if (root.available && !query.running) query.running = true
    }

    // Avvisa quando cambia qualcosa (jack inserito, uscita cambiata)
    Process {
        id: subscribe
        running: true
        command: ["sh", "-c", "command -v pactl >/dev/null || exit 127; exec pactl subscribe"]
        stdout: SplitParser {
            // "Event 'change' on sink #56": uscite, schede, server. Non i
            // flussi delle app ("sink-input"), che cambiano di continuo
            onRead: line => { if (/ on (sink|card|server)( |$)/.test(line)) queryLater.restart() }
        }
        onExited: code => {
            if (code === 127) root.available = false
            else restartLater.restart()    // es. PipeWire riavviato
        }
    }
    Timer {
        id: restartLater
        interval: 5000
        onTriggered: subscribe.running = true
    }

    Component.onCompleted: refresh()
}
