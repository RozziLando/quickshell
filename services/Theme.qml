pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Impostazioni da theme.json, colori dal tema attivo (themes/<theme>.json).
// Il tema si cambia dal launcher (modalità temi) o con
// "qs ipc call theme set <nome>": vedi ThemeManager.qml.
Singleton {
    id: root

    // ---- Scala globale (limitata tra 0.5 e 3) ----
    readonly property real scale: Math.max(0.5, Math.min(3.0, data.scale))

    // Scala un valore in pixel: Theme.s(10)
    function s(value) {
        return Math.round(value * scale)
    }

    // Pixel veri del monitor per una misura già scalata (es. sourceSize delle
    // immagini): misura × fattore di scala dello schermo su cui sta "item"
    // (scale di Hyprland, anche frazionaria). Qt non lo fa da solo: senza,
    // su un monitor a scala 2 le immagini si caricherebbero a metà
    // risoluzione. Si aggiorna se la finestra cambia schermo
    function px(size, item) {
        var w = item ? item.QsWindow.window : null
        var dpr = w && w.devicePixelRatio > 0 ? w.devicePixelRatio : 1
        return Math.ceil(size * dpr)
    }

    // ---- Stile dell'isola ----
    // "floating": pillola staccata dal bordo con cerchi ai lati
    // "attached": vecchia versione attaccata al bordo con quadratini
    readonly property bool floatingIsland: data.islandStyle !== "attached"
    // true: a riposo solo l'orologio, le icone compaiono passandoci sopra
    readonly property bool minimalIsland: data.minimal
    // true: l'isola si nasconde (sale come in fullscreen) quando sul desktop
    // c'è una finestra in tiling o una finestra flottante le sta sopra
    readonly property bool autoHide: data.autoHide
    // Monitor dell'isola, col nome di Hyprland ("HDMI-A-1", "DP-1", "eDP-1"...;
    // vedi "hyprctl monitors"). Vuoto o non collegato: scelta automatica
    readonly property string monitor: String(data.monitor || "").trim()

    // ---- Font ----
    readonly property string fontFamily: data.fontFamily
    // Font delle icone: phosphor, phosphor-light, phosphor-bold,
    // phosphor-fill o classic (disegnate a mano). Vedi Icons.qml
    readonly property string iconFont: data.iconFont

    // ---- Tema ----
    readonly property string themeId: data.theme
    // Cartella degli sfondi (comune a tutti i temi), "~" = home
    readonly property string wallpaperDir: data.wallpaperDir.replace(/^~/, Quickshell.env("HOME"))
    // Animazione al cambio di sfondo (awww/swww): grow, outer, wave, wipe,
    // fade, left, right, top, bottom, random, simple
    readonly property string wallpaperTransition: data.wallpaperTransition

    // Percorso di un file -> URL per le immagini. Senza codifica un nome con
    // "#" o "%" (es. "sfondo #2.png") non si caricherebbe
    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    // Colore del tema, con ripiego se manca
    function c(key, fallback) {
        var v = palette.colors ? palette.colors[key] : undefined
        return v !== undefined && v !== "" ? v : fallback
    }

    // ---- Vetro ("glass" in theme.json) ----
    // Isola e finestre semitrasparenti: Hyprland sfoca quello che c'è dietro
    // (layer rule "quickshell-glass" in modules/wrule.lua di Hyprland). Anche riquadri e
    // pulsanti diventano traslucidi; bordo chiaro e riflesso in alto.
    readonly property bool glass: data.glass
    readonly property real glassOpacity: Math.max(0.3, Math.min(1, data.glassOpacity))
    readonly property color glassEdge: Qt.rgba(1, 1, 1, 0.16)
    readonly property color glassSheen: Qt.rgba(1, 1, 1, 0.09)

    // Colore del tema, reso traslucido in modalità vetro
    function tint(value, alpha) {
        var col = Qt.color(value)
        return glass ? Qt.rgba(col.r, col.g, col.b, alpha) : col
    }

    // Sfondo dell'isola (pillola, cerchi, finestre che si aprono)
    readonly property color panel: tint(c("background", "#1e1e2e"), glassOpacity)

    // ---- Colori ----
    readonly property color background: c("background", "#1e1e2e")
    readonly property color border: c("border", "#313244")
    readonly property color surface: tint(c("surface", "#313244"), 0.5)
    readonly property color highlight: tint(c("highlight", "#45475a"), 0.6)
    readonly property color selection: c("selection", "#585b70")

    // Riquadri del centro di controllo
    readonly property color card: tint(c("card", "#262637"), 0.4)
    readonly property color cardBorder: tint(c("cardBorder", "#313244"), 0.5)
    readonly property color track: tint(c("track", "#181825"), 0.5)

    readonly property color text: c("text", "#cdd6f4")
    readonly property color textSoft: c("textSoft", "#bac2de")
    readonly property color textSecondary: c("textSecondary", "#a6adc8")
    readonly property color textMuted: c("textMuted", "#6c7086")
    readonly property color textDisabled: c("textDisabled", "#585b70")

    readonly property color accent: c("accent", "#89b4fa")
    readonly property color warning: c("warning", "#f38ba8")

    // Alone attorno a isola e cerchi e ombra di Hyprland (#AARRGGBB)
    readonly property color glow: c("glow", "#0cffffff")
    // false: niente alone, tornano i bordi normali
    readonly property bool glowEnabled: data.glowEnabled
    // true: ombra scura classica (finestre di Hyprland e shell) al posto
    // dell'alone: Hyprland ha una sola ombra per finestra
    readonly property bool darkShadow: data.darkShadow
    // C'è un effetto (alone o ombra) al posto dei bordi?
    readonly property bool shadowEnabled: glowEnabled || darkShadow

    // ---- Blocco schermo e login ----
    // true: sfondo sfocato con un velo scuro; false: l'immagine così com'è
    readonly property bool lockBlur: data.lockBlur
    // Login (greetd): sfondo sfocato o nitido, indipendente dal blocco
    readonly property bool loginBlur: data.loginBlur
    // false: niente blocco schermo (né da ALT+L, né per inattività, né prima
    // di dormire) e nel menu di spegnimento solo Reboot / Power off
    readonly property bool lockScreen: data.lockScreen
    // false: niente sleep dalla shell (né per inattività, qualunque sia
    // idleSleepMinutes, né dal menu di spegnimento)
    readonly property bool sleepEnabled: data.sleepEnabled
    // false: login automatico su Hyprland (lo applica greeter/install.sh)
    readonly property bool loginScreen: data.loginScreen

    // ---- Avvio e inattività (theme.json) ----
    // Bluetooth acceso o spento al primo avvio della shell dopo l'accensione
    readonly property bool bluetoothOnStartup: data.bluetoothOnStartup
    // Minuti senza usare il computer prima di bloccare / sospendere (0 = mai)
    readonly property real idleLockMinutes: data.idleLockMinutes
    readonly property real idleSleepMinutes: data.idleSleepMinutes

    // ---- Impostazioni (theme.json) ----
    FileView {
        id: settingsFile
        path: Quickshell.shellPath("theme.json")
        // Caricamento subito, alla creazione di Theme (text() aspetta il
        // file): così chi legge Theme all'avvio trova già i valori veri e non
        // quelli di default. Serve soprattutto all'isola: se nascesse sullo
        // schermo sbagliato e poi cambiasse, durante il ricaricamento della
        // shell Quickshell crasherebbe (vedi Island.qml, preferredScreen)
        Component.onCompleted: text()
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: data

            property real scale: 1.0
            property string fontFamily: "JetBrains Mono"
            property string iconFont: "phosphor"
            property string islandStyle: "floating"
            property bool minimal: false
            property bool autoHide: false
            property string monitor: ""
            property bool glowEnabled: true
            property bool darkShadow: false
            property bool glass: false
            property real glassOpacity: 0.55
            property string theme: "midnight"
            property bool bluetoothOnStartup: false
            property bool lockBlur: true
            property bool loginBlur: true
            property bool lockScreen: true
            property bool sleepEnabled: true
            property bool loginScreen: true
            property real idleLockMinutes: 10
            property real idleSleepMinutes: 10
            property string wallpaperDir: "~/Wallpapers"
            property string wallpaperTransition: "grow"
            // Letta dall'estensione di VS Code (vscode/quickshell-theme-sync)
            property bool vscodeThemeSync: true
        }
    }

    // ---- Tema attivo (themes/<theme>.json) ----
    FileView {
        path: Quickshell.shellPath("themes/" + data.theme + ".json")
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: palette

            property var colors: ({})
        }
    }
}
