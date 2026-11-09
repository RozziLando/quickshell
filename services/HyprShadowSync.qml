import QtQuick
import Quickshell.Io
import Quickshell.Hyprland

// Tiene l'ombra delle finestre di Hyprland allineata alla shell (theme.json):
//   - "darkShadow": true  -> ombra scura classica, spostata in basso
//   - altrimenti "glowEnabled" -> alone del colore "glow" del tema
//   - nessuno dei due     -> niente ombra
// Le modifiche valgono finché Hyprland gira: dopo un reload della sua
// config vengono riapplicate.
Item {
    id: root

    // Colore Qt -> "rgba(RRGGBBAA)" (formato accettato da Hyprland)
    function hex(v) {
        var h = Math.round(v * 255).toString(16)
        return h.length < 2 ? "0" + h : h
    }
    readonly property string glowColor: "rgba(" + hex(Theme.glow.r) + hex(Theme.glow.g)
                                        + hex(Theme.glow.b) + hex(Theme.glow.a) + ")"

    readonly property bool dark: Theme.darkShadow
    readonly property bool shadowOn: Theme.darkShadow || Theme.glowEnabled
    readonly property string color: dark ? "rgba(00000099)" : glowColor
    // Alone: stretto e centrato (come range in modules/looknfeel.lua di
    // Hyprland); ombra: ampia e in basso
    readonly property int range: dark ? 20 : 3
    readonly property string offset: dark ? "0 5" : "0 0"

    function apply() {
        // Hyprland con config Lua (0.5x) usa hl.config; prima si usava keyword
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

    // Più modifiche ravvicinate (es. salvataggio di theme.json) -> un solo comando
    Timer {
        id: applyLater
        interval: 150
        onTriggered: root.apply()
    }

    onColorChanged: applyLater.restart()
    onShadowOnChanged: applyLater.restart()
    onDarkChanged: applyLater.restart()
    Component.onCompleted: applyLater.restart()

    // Hyprland ha ricaricato la sua config: riapplica
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") applyLater.restart()
        }
    }
}
