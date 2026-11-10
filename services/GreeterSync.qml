pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    function sync() { later.restart() }
    function syncNow() {
        later.stop()
        run()
    }

    property bool again: false
    function run() {
        if (proc.running) again = true
        else proc.running = true
    }

    Timer {
        id: later
        interval: 1200
        onTriggered: root.run()
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("greeter/sync.sh")]
        onExited: if (root.again) {
            root.again = false
            Qt.callLater(root.run)
        }
    }

    Connections {
        target: Theme
        function onThemeIdChanged() { root.sync() }
    }

    FileView {
        path: Quickshell.shellPath("theme.json")
        watchChanges: true
        onFileChanged: root.sync()
    }

    Component.onCompleted: sync()
}
