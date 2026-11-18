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

    property bool backlightChecked: false
    readonly property bool ddcWanted: Theme.displayOnDesktop === true
    property bool ddc: false
    property var ddcBuses: []
    property int ddcMax: 100
    property int ddcPending: -1
    property real ddcLastDetect: 0

    Process {
        id: displayProc
        command: ["sh", "-c", 'command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m -c "$1" info',
                  "sh", root.displayClass]
        stdout: StdioCollector {
            onStreamFinished: {
                var info = root.parseInfo(text)
                root.backlightChecked = true
                if (info) {
                    root.ddc = false
                    root.ddcBuses = []
                    root.displayMax = info.max
                    root.displayPath = info.path
                    root.displayAvailable = true
                } else {
                    root.displayPath = ""
                    root.displayMax = 0
                    root.updateDdc(true)
                }
            }
        }
    }

    Process {
        id: keyboardProc
        command: ["sh", "-c", 'command -v brightnessctl >/dev/null 2>&1 && brightnessctl -m -d "$1" info',
                  "sh", root.keyboardDevice]
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

    function updateDdc(opening) {
        if (!backlightChecked || displayPath !== "") return
        if (!ddcWanted) {
            ddc = false
            ddcBuses = []
            ddcPending = -1
            displayAvailable = false
            return
        }
        if (!ddc) detectDdc()
        else if (opening && ddcBuses.length < Quickshell.screens.length
                 && Date.now() - ddcLastDetect > 60000) detectDdc()
        else readDdc()
    }

    onDdcWantedChanged: updateDdc(false)

    function detectDdc() {
        if (ddcDetect.running) return
        ddcLastDetect = Date.now()
        ddcDetect.running = true
    }

    Process {
        id: ddcDetect
        command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && ddcutil detect --terse 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.ddcWanted || root.displayPath !== "") return
                var buses = []
                text.split(/\n\s*\n/).forEach(function (block) {
                    if (!/^\s*Display \d+/.test(block)) return
                    var m = block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/)
                    if (m) buses.push(m[1])
                })
                root.ddcBuses = buses
                root.ddc = buses.length > 0
                if (root.ddc) root.readDdc()
                else root.displayAvailable = false
            }
        }
    }

    function readDdc() {
        if (!ddc || ddcRead.running || ddcWrite.running || justSet.running) return
        ddcRead.command = ["sh", "-c",
            'for b in "$@"; do for i in 1 2 3; do'
            + ' out=$(ddcutil getvcp 10 --brief --bus "$b" 2>/dev/null)'
            + ' && case "$out" in "VCP 10 C "*) echo "$out"; exit 0;; esac;'
            + ' done; done; exit 1', "sh"].concat(ddcBuses)
        ddcRead.running = true
    }

    Process {
        id: ddcRead
        onRunningChanged: if (!running) root.writeDdc()
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.ddc) return
                var f = text.trim().split(/\s+/)
                var cur = parseInt(f[3]), max = parseInt(f[4])
                if (f[0] !== "VCP" || isNaN(cur) || isNaN(max) || max <= 0) {
                    root.displayAvailable = false
                    return
                }
                root.ddcMax = max
                root.displayAvailable = true
                if (!justSet.running && !ddcWrite.running && root.ddcPending < 0)
                    root.displayLevel = Math.max(0, Math.min(1, cur / max))
            }
        }
    }

    function writeDdc() {
        if (!ddc || ddcPending < 0 || ddcWrite.running || ddcRead.running) return
        ddcWrite.command = ["sh", "-c",
            'v=$1; shift; for b in "$@"; do (for i in 1 2 3 4; do'
            + ' ddcutil setvcp 10 "$v" --bus "$b" --noverify >/dev/null 2>&1 && break; done) & done; wait',
            "sh", String(ddcPending)].concat(ddcBuses)
        ddcPending = -1
        ddcWrite.running = true
    }

    Process {
        id: ddcWrite
        onRunningChanged: if (!running) root.writeDdc()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.ddcWanted && root.backlightChecked && root.displayPath === "") redetect.restart()
        }
    }

    Timer {
        id: redetect
        interval: 2000
        onTriggered: if (root.ddcWanted && root.displayPath === "") root.detectDdc()
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
        running: root.displayPath !== "" || root.keyboardPath !== ""
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
        if (ddc) {
            ddcPending = Math.round(displayLevel * ddcMax)
            writeDdc()
            return
        }
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
