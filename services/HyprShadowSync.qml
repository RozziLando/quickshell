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

    function layoutCommand() {
        if (Hyprland.usingLua) {
            var parts = []
            if (Theme.hyprRounding) parts.push("decoration = { rounding = " + Theme.radius + " }")
            if (Theme.hyprGaps) parts.push("general = { gaps_out = " + Theme.edgeGap + " }")
            return parts.length > 0 ? ["hyprctl", "eval", "hl.config({ " + parts.join(", ") + " })"] : null
        }
        var cmds = []
        if (Theme.hyprRounding) cmds.push("keyword decoration:rounding " + Theme.radius)
        if (Theme.hyprGaps) cmds.push("keyword general:gaps_out " + Theme.edgeGap)
        return cmds.length > 0 ? ["hyprctl", "--batch", cmds.join(" ; ")] : null
    }

    function applyLayout() {
        var cmd = layoutCommand()
        if (!cmd) return
        layoutProc.command = cmd
        layoutProc.running = true
    }

    Process { id: layoutProc }

    function applyGlass() {
        if (!Hyprland.usingLua) {
            if (!Theme.glass) return
            glassProc.command = ["hyprctl", "--batch",
                "keyword layerrule blur on, ignore_alpha 0.2, match:namespace ^(quickshell(-bar)?)$"
                + " ; keyword layerrule blur, ^(quickshell(-bar)?)$"
                + " ; keyword layerrule ignorealpha 0.2, ^(quickshell(-bar)?)$"]
            glassProc.running = true
            return
        }
        glassProc.command = ["hyprctl", "eval",
            "hl.layer_rule({ name = \"quickshell-glass\", match = { namespace = \"^quickshell(-bar)?$\" }, blur = "
            + Theme.glass + ", ignore_alpha = 0.2 })"]
        glassProc.running = true
    }

    Process { id: glassProc }

    Timer {
        id: glassLater
        interval: 150
        onTriggered: root.applyGlass()
    }

    Timer {
        id: layoutLater
        interval: 150
        onTriggered: root.applyLayout()
    }

    Connections {
        target: Theme
        function onRadiusChanged() { if (Theme.hyprRounding) layoutLater.restart() }
        function onEdgeGapChanged() { if (Theme.hyprGaps) layoutLater.restart() }
        function onHyprRoundingChanged() { if (Theme.hyprRounding) layoutLater.restart() }
        function onHyprGapsChanged() { if (Theme.hyprGaps) layoutLater.restart() }
        function onGlassChanged() { glassLater.restart() }
    }

    Timer {
        id: applyLater
        interval: 150
        onTriggered: root.apply()
    }

    onColorChanged: applyLater.restart()
    onShadowOnChanged: applyLater.restart()
    onDarkChanged: applyLater.restart()
    Component.onCompleted: {
        applyLater.restart()
        layoutLater.restart()
        glassLater.restart()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                applyLater.restart()
                layoutLater.restart()
                glassLater.restart()
            }
        }
    }
}
