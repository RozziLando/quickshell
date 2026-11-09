pragma Singleton
import QtQuick
import Quickshell

// Font delle icone: Phosphor (MIT, assets/fonts/), dentro la configurazione:
// nessun pacchetto da installare su nessuna distro. Si sceglie con
// "iconFont" in theme.json:
//   phosphor, phosphor-light, phosphor-bold, phosphor-fill (stessi caratteri,
//   tratto diverso) oppure classic (icone disegnate a mano di LineIcon).
// LineIcon chiede qui il carattere di ogni icona ("kind").
Singleton {
    id: root

    readonly property string family: loader.name
    readonly property bool ready: Theme.iconFont !== "classic" && loader.status === FontLoader.Ready

    readonly property string fontFile: ({
        "phosphor-light": "Phosphor-Light.ttf",
        "phosphor-bold": "Phosphor-Bold.ttf",
        "phosphor-fill": "Phosphor-Fill.ttf"
    })[Theme.iconFont] || "Phosphor.ttf"

    FontLoader {
        id: loader
        // Con "classic" resta caricato ma non si usa (ready è false): una
        // sorgente vuota darebbe un avviso nel log
        source: "file://" + Quickshell.shellPath("assets/fonts/" + root.fontFile)
    }

    // Nome dell'icona nella shell -> codice del carattere Phosphor
    readonly property var codes: ({
        "wifi": 0xe4ea,          // wifi-high
        "wifi0": 0xe4f0,         // wifi-none
        "wifi1": 0xe4ec,         // wifi-low
        "wifi2": 0xe4ee,         // wifi-medium
        "wifi3": 0xe4ea,         // wifi-high
        "bluetooth": 0xe0da,
        "screenshot": 0xe626,    // frame-corners
        "power": 0xe3da,
        "volume": 0xe44a,        // speaker-high
        "volume-low": 0xe44c,    // speaker-low
        "volume-mute": 0xe45a,   // speaker-slash
        "sun": 0xe472,
        "keyboard": 0xe2d8,
        "search": 0xe30c,        // magnifying-glass
        "chevron": 0xe13a,       // caret-right
        "play": 0xe3d0,
        "pause": 0xe39e,
        "next": 0xe5a6,          // skip-forward
        "previous": 0xe5a4,      // skip-back
        "ethernet": 0xedde,      // network
        "back": 0xe138,          // caret-left
        "lock": 0xe2fa,
        "mic": 0xe326,           // microphone
        "check": 0xe182,
        "app": 0xe5da,           // app-window
        "monitor": 0xe32e,
        "laptop": 0xe586,
        "extend": 0xe534,        // arrows-out-line-horizontal
        "mirror": 0xe1ca,        // copy
        "sleep": 0xe330,         // moon
        "reboot": 0xe036,        // arrow-clockwise
        "grid": 0xe464,          // squares-four
        "file": 0xe230,
        "folder": 0xe24a,
        "terminal": 0xeae8,      // terminal-window
        "headphones": 0xe2a6,
        "close": 0xe4f6,         // x
        "palette": 0xe6c8,
        "cpu": 0xe610
    })

    // Carattere per un'icona ("" se il font non ce l'ha: si usa il disegno)
    function glyph(kind, level) {
        if (!ready) return ""
        var key = kind
        if (kind === "wifi" && level >= 0) key = "wifi" + Math.max(0, Math.min(3, level))
        var c = codes[key]
        return c === undefined ? "" : String.fromCharCode(c)
    }
}
