import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    function hex(v) {
        var h = Math.round(v * 255).toString(16)
        return h.length < 2 ? "0" + h : h
    }
    readonly property string glowColor: "rgba(" + hex(Theme.glow.r) + hex(Theme.glow.g)
                                        + hex(Theme.glow.b) + hex(Theme.glow.a) + ")"

    readonly property bool dark: Theme.darkShadow
    readonly property bool shadowOn: Theme.darkShadow || Theme.glowEnabled
    readonly property string color: dark ? "rgba(00000099)" : glowColor
    readonly property int range: dark ? 20 : 3
    readonly property string offset: dark ? "0 5" : "0 0"

    function apply() {
        if (Hyprland.usingLua) {
            applyProc.command = ["hyprctl", "eval",
                "hl.config({ decoration = { shadow = { enabled = " + root.shadowOn
                + ", color = \"" + root.color + "\", range = " + root.range
                + ", offset = \"" + root.offset + "\" } } })"]
        } else {
            applyProc.command = ["hyprctl", "--batch",
                "keyword decoration:shadow:enabled " + (root.shadowOn ? 1 : 0)
                + "; keyword decoration:shadow:color " + root.color
                + "; keyword decoration:shadow:range " + root.range
                + "; keyword decoration:shadow:offset " + root.offset]
        }
        applyProc.running = true
    }

    Process { id: applyProc }

    Timer {
        id: applyLater
        interval: 150
        onTriggered: root.apply()
    }

    onColorChanged: applyLater.restart()
    onShadowOnChanged: applyLater.restart()
    onDarkChanged: applyLater.restart()
    Component.onCompleted: applyLater.restart()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") applyLater.restart()
        }
    }
}
