pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tiene il login (greetd) uguale al blocco schermo: lancia greeter/sync.sh,
// che copia schermata, tema, foto e sfondo attuale in /etc/greetd/quickshell
// (cartella dell'utente dopo install.sh, quindi senza sudo).
// Parte a ogni avvio/ricarica della shell, a ogni modifica di theme.json, al
// cambio di tema o di sfondo, e prima di bloccare, dormire o spegnere.
Singleton {
    id: root

    function sync() { later.restart() }
    // Subito, senza attesa (spegnimento: il sistema non aspetta)
    function syncNow() {
        later.stop()
        run()
    }

    // Copia già in corso: se ne fa un'altra appena finisce, altrimenti una
    // modifica arrivata a metà (es. nuovo sfondo) non raggiungerebbe il login
    property bool again: false
    function run() {
        if (proc.running) again = true
        else proc.running = true
    }

    // Più richieste ravvicinate -> una sola copia (e lo sfondo nuovo fa in
    // tempo a comparire in awww)
    Timer {
        id: later
        interval: 1200
        onTriggered: root.run()
    }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("greeter/sync.sh")]
        // Fuori dal segnale, a processo ormai chiuso
        onExited: if (root.again) {
            root.again = false
            Qt.callLater(root.run)
        }
    }

    Connections {
        target: Theme
        function onThemeIdChanged() { root.sync() }
    }

    // Qualsiasi modifica a theme.json (es. "lockBlur") arriva subito al login
    FileView {
        path: Quickshell.shellPath("theme.json")
        watchChanges: true
        onFileChanged: root.sync()
    }

    Component.onCompleted: sync()
}
