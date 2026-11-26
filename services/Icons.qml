pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property string fontName: {
        var v = String(Theme.iconFont || "").trim().toLowerCase()
        if (v === "" || v === "phosphor" || v === "phosphor-regular") return "Phosphor"
        var m = v.match(/^phosphor-([a-z]+)$/)
        return m ? "Phosphor-" + m[1].charAt(0).toUpperCase() + m[1].slice(1) : "Phosphor"
    }
    readonly property bool installed: Qt.fontFamilies().indexOf(fontName) >= 0
    readonly property string family: loader.status === FontLoader.Ready ? loader.name : fontName
    readonly property bool ready: Theme.iconFont !== "classic"
                                  && (loader.status === FontLoader.Ready || installed)

    FontLoader {
        id: loader
        source: root.installed ? "" : "file://" + Quickshell.shellPath("assets/fonts/" + root.fontName + ".ttf")
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
        "cpu": 0xe610,
        "gear": 0xe270,
        "info": 0xe2ce,
        "pencil": 0xe3b4,
        "plus": 0xe3d4,
        "image": 0xe2ca,
        "update": 0xe028,
        "copy": 0xe1ca,
        "font": 0xe6ee,
        "bell": 0xe0ce,
        "sliders": 0xe434,
        "drag": 0xeae2,
        "layout": 0xe6d6,
        "calendar": 0xe108,
        "gauge": 0xe628,
        "leaf": 0xe2da,
        "lightning": 0xe2de,
        "scales": 0xe750
    })

    function glyph(kind, level) {
        if (!ready) return ""
        var key = kind
        if (kind === "wifi" && level >= 0) key = "wifi" + Math.max(0, Math.min(3, level))
        var c = codes[key]
        return c === undefined ? "" : String.fromCharCode(c)
    }
}
