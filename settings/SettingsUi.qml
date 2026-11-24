pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Singleton {
    id: root

    property real factor: 1.0
    function u(value) { return Theme.s(value * factor) }
    readonly property int radius: Theme.radius

    property var menu: null
    property var picker: null
    property var tip: null

    function openMenu(spec) {
        tip = null
        menu = spec
    }
    function closeMenu() { menu = null }

    function showTip(anchor, text) { tip = { anchor: anchor, text: text } }
    function hideTip(anchor) { if (tip && tip.anchor === anchor) tip = null }

    property var hyprMemory: ({})

    readonly property var hyprOptions: ({
        "rounding": { key: "hyprRounding", option: "decoration:rounding", section: "decoration", field: "rounding" },
        "gaps": { key: "hyprGaps", option: "general:gaps_out", section: "general", field: "gaps_out" }
    })

    function linkHypr(kind) {
        var o = hyprOptions[kind]
        readProc.kind = kind
        readProc.command = ["hyprctl", "-j", "getoption", o.option]
        readProc.running = true
    }

    Process {
        id: readProc
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var kind = readProc.kind, o = root.hyprOptions[kind], value = ""
                try {
                    var j = JSON.parse(text)
                    value = j.int !== undefined ? String(j.int) : String(j.css || j.float || "")
                } catch (e) {}
                var m = Object.assign({}, root.hyprMemory)
                if (value !== "") m[kind] = value
                root.hyprMemory = m
                Settings.set(o.key, true)
            }
        }
    }

    function undoHypr(kind) {
        var o = hyprOptions[kind], value = String(hyprMemory[kind] || "")
        Settings.set(o.key, false)
        var m = Object.assign({}, hyprMemory)
        delete m[kind]
        hyprMemory = m
        if (value === "") {
            Quickshell.execDetached(["hyprctl", "reload", "config-only"])
            return
        }
        var parts = value.trim().split(/\s+/)
        var same = parts.every(function (p) { return p === parts[0] })
        if (Hyprland.usingLua) {
            var lua = same ? parts[0] : '"' + parts.join(" ") + '"'
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({ " + o.section + " = { " + o.field + " = " + lua + " } })"])
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", o.option, same ? parts[0] : parts.join(",")])
        }
    }

    function home(path) {
        var h = Quickshell.env("HOME")
        return String(path).indexOf(h) === 0 ? "~" + String(path).substring(h.length) : String(path)
    }
}
