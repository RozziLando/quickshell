pragma Singleton
import QtQuick
import Quickshell

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
        source: "file://" + Quickshell.shellPath("assets/fonts/" + root.fontFile)
    }

    readonly property var codes: ({
        "wifi": 0xe4ea,
        "wifi0": 0xe4f0,
        "wifi1": 0xe4ec,
        "wifi2": 0xe4ee,
        "wifi3": 0xe4ea,
        "bluetooth": 0xe0da,
        "screenshot": 0xe626,
        "power": 0xe3da,
        "volume": 0xe44a,
        "volume-low": 0xe44c,
        "volume-mute": 0xe45a,
        "sun": 0xe472,
        "keyboard": 0xe2d8,
        "search": 0xe30c,
        "chevron": 0xe13a,
        "play": 0xe3d0,
        "pause": 0xe39e,
        "next": 0xe5a6,
        "previous": 0xe5a4,
        "ethernet": 0xedde,
        "back": 0xe138,
        "lock": 0xe2fa,
        "mic": 0xe326,
        "check": 0xe182,
        "app": 0xe5da,
        "monitor": 0xe32e,
        "laptop": 0xe586,
        "extend": 0xe534,
        "mirror": 0xe1ca,
        "sleep": 0xe330,
        "reboot": 0xe036,
        "grid": 0xe464,
        "file": 0xe230,
        "folder": 0xe24a,
        "terminal": 0xeae8,
        "headphones": 0xe2a6,
        "close": 0xe4f6,
        "palette": 0xe6c8,
        "cpu": 0xe610
    })

    function glyph(kind, level) {
        if (!ready) return ""
        var key = kind
        if (kind === "wifi" && level >= 0) key = "wifi" + Math.max(0, Math.min(3, level))
        var c = codes[key]
        return c === undefined ? "" : String.fromCharCode(c)
    }
}
