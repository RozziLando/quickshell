pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string displayClass: "backlight"
    property string keyboardDevice: "*kbd_backlight"

    property real displayLevel: 0
    property bool displayAvailable: false
    property real keyboardLevel: 0
    property bool keyboardAvailable: false

    signal displayChangedExternally()
    signal keyboardChangedExternally()

    function parseInfo(text) {
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

    property bool displayReady: false
    property bool keyboardReady: false

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
            var level = root.displayFromRaw(v)
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

    function refresh() {
        displayProc.running = true
        keyboardProc.running = true
    }
    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (root.displayPath !== "") displayFile.reload()
            if (root.keyboardPath !== "") keyboardFile.reload()
        }
    }

    Timer {
        id: justSet
        interval: 600
    }

    readonly property int displayExponent: 4
    readonly property int displayMinRaw: displayMax > 20 ? 2 : 1
    readonly property real displayFloor: displayMax > 0
        ? Math.pow(Math.min(1, displayMinRaw / displayMax), 1 / displayExponent) : 0

    function displayFromRaw(raw) {
        if (displayFloor >= 1) return raw >= displayMinRaw ? 1 : 0
        var curve = Math.pow(Math.max(0, raw) / displayMax, 1 / displayExponent)
        return Math.max(0, Math.min(1, (curve - displayFloor) / (1 - displayFloor)))
    }

    function displayToRaw(level) {
        var curve = displayFloor + Math.max(0, Math.min(1, level)) * (1 - displayFloor)
        var raw = Math.round(displayMax * Math.pow(curve, displayExponent))
        return Math.max(displayMinRaw, Math.min(displayMax, raw))
    }

    function setDisplay(value) {
        displayLevel = Math.max(0, Math.min(1, value))
        displayAbsorb = true
        justSet.restart()
        if (displayMax <= 0) return
        Quickshell.execDetached(["brightnessctl", "-c", displayClass, "set",
                                 String(displayToRaw(displayLevel))])
    }

    function setKeyboard(value) {
        keyboardLevel = value
        keyboardAbsorb = true
        justSet.restart()
        var pct = Math.round(value * 100)
        Quickshell.execDetached(["brightnessctl", "-d", keyboardDevice, "set", pct + "%"])
    }
}
