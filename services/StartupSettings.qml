import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

// Impostazioni applicate una volta sola all'avvio del computer (non quando
// la shell si ricarica o viene riavviata):
//   "bluetoothOnStartup" in theme.json: Bluetooth acceso (true) o spento (false)
// "Primo avvio" = manca un segnaposto in $XDG_RUNTIME_DIR, cartella che si
// svuota a ogni spegnimento / fine sessione.
Item {
    id: root

    property bool firstStart: false
    readonly property var adapter: Bluetooth.defaultAdapter

    Process {
        running: true
        command: ["sh", "-c",
            'f="${XDG_RUNTIME_DIR:-/tmp}/quickshell-startup-done";'
            + ' if [ -e "$f" ]; then echo again; else touch "$f"; echo first; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                root.firstStart = text.trim() === "first"
                root.applyBluetooth()
            }
        }
    }

    // L'adattatore può comparire qualche secondo dopo l'avvio
    property bool bluetoothDone: false
    onAdapterChanged: applyBluetooth()

    function applyBluetooth() {
        if (!firstStart || bluetoothDone || !adapter) return
        bluetoothDone = true
        adapter.enabled = Theme.bluetoothOnStartup
    }
}
