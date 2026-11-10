import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth

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

    property bool bluetoothDone: false
    onAdapterChanged: applyBluetooth()

    function applyBluetooth() {
        if (!firstStart || bluetoothDone || !adapter) return
        bluetoothDone = true
        adapter.enabled = Theme.bluetoothOnStartup
    }
}
