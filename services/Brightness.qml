pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Luminosità di schermo e tastiera, condivisa da centro di controllo e OSD.
// brightnessctl serve solo a trovare il dispositivo (nome, classe, massimo);
// il valore poi si legge dal file del kernel in /sys, che avvisa subito
// quando cambia (anche se lo cambiano i tasti funzione).
Singleton {
    id: root

    property string displayClass: "backlight"
    property string keyboardDevice: "*kbd_backlight"

    property real displayLevel: 0
    property bool displayAvailable: false
    property real keyboardLevel: 0
    property bool keyboardAvailable: false

    // Cambi arrivati da fuori (tasti, altri programmi), non dalle nostre barre
    signal displayChangedExternally()
    signal keyboardChangedExternally()

    function parseInfo(text) {
        // formato: nome,classe,valore,percentuale%,massimo
        var f = text.trim().split("\n")[0].split(",")
        if (f.length < 5) return null
        var max = parseInt(f[4])
        if (isNaN(max) || max <= 0) return null
        return { path: "/sys/class/" + f[1] + "/" + f[0] + "/brightness", max: max }
    }

    property string displayPath: ""
    property int displayMax: 0
    property string keyboardPath: ""
    property int keyboardMax: 0

    Process {
        id: displayProc
        command: ["brightnessctl", "-m", "-c", root.displayClass, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                var info = root.parseInfo(text)
                root.displayAvailable = info !== null
                if (info) {
                    root.displayMax = info.max
                    root.displayPath = info.path
                }
            }
        }
    }

    Process {
        id: keyboardProc
        command: ["brightnessctl", "-m", "-d", root.keyboardDevice, "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                var info = root.parseInfo(text)
                root.keyboardAvailable = info !== null
                if (info) {
                    root.keyboardMax = info.max
                    root.keyboardPath = info.path
                }
            }
        }
    }

    // Prima lettura completata: da lì in poi i cambi contano come "esterni"
    property bool displayReady: false
    property bool keyboardReady: false

    // Dopo un cambio dalle nostre barre, la prima lettura riporta il valore
    // arrotondato dal kernel: va preso senza considerarlo un cambio esterno
    property bool displayAbsorb: false
    property bool keyboardAbsorb: false

    FileView {
        id: displayFile
        path: root.displayPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(text())
            if (isNaN(v) || root.displayMax <= 0 || justSet.running) return
            // Scala percettiva, come i tasti (brightnessctl -e4)
            var level = Math.pow(v / root.displayMax, 1 / root.displayExponent)
            var changed = Math.abs(level - root.displayLevel) > 0.001
            root.displayLevel = level
            if (changed && root.displayReady && !root.displayAbsorb)
                root.displayChangedExternally()
            root.displayReady = true
            root.displayAbsorb = false
        }
    }

    FileView {
        id: keyboardFile
        path: root.keyboardPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var v = parseInt(text())
            if (isNaN(v) || root.keyboardMax <= 0 || justSet.running) return
            var level = v / root.keyboardMax
            var changed = Math.abs(level - root.keyboardLevel) > 0.001
            root.keyboardLevel = level
            if (changed && root.keyboardReady && !root.keyboardAbsorb)
                root.keyboardChangedExternally()
            root.keyboardReady = true
            root.keyboardAbsorb = false
        }
    }

    // Cerca i dispositivi (all'avvio e quando lo chiede il centro di controllo)
    function refresh() {
        displayProc.running = true
        keyboardProc.running = true
    }
    Component.onCompleted: refresh()

    // Rete di sicurezza: su alcuni portatili è il firmware a cambiare la
    // luminosità e il file non avvisa. Rilettura del file (nessun processo)
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (root.displayPath !== "") displayFile.reload()
            if (root.keyboardPath !== "") keyboardFile.reload()
        }
    }

    // Dopo un cambio dalle nostre barre ignora per un attimo le letture,
    // altrimenti le scritture intermedie del trascinamento farebbero
    // "saltare" la barra (e non sono cambi esterni)
    Timer {
        id: justSet
        interval: 600
    }

    // Schermo su scala percettiva, come i tasti di Hyprland (modules/keybindings.lua)
    // ("brightnessctl -e4"): ogni pressione sposta la barra di un passo
    // uguale, sia sui valori bassi sia su quelli alti
    readonly property int displayExponent: 4

    function setDisplay(value) {
        displayLevel = value
        displayAbsorb = true
        justSet.restart()
        // Minimo 1%: a 0% lo schermo potrebbe spegnersi del tutto
        var pct = Math.max(1, Math.round(value * 100))
        Quickshell.execDetached(["brightnessctl", "-e" + displayExponent, "-c", displayClass,
                                 "set", pct + "%"])
    }

    function setKeyboard(value) {
        keyboardLevel = value
        keyboardAbsorb = true
        justSet.restart()
        var pct = Math.round(value * 100)
        Quickshell.execDetached(["brightnessctl", "-d", keyboardDevice, "set", pct + "%"])
    }
}
