pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real scale: Math.max(0.5, Math.min(3.0, data.scale))

    function s(value) {
        return Math.round(value * scale)
    }

    function px(size, item) {
        var w = item ? item.QsWindow.window : null
        var dpr = w && w.devicePixelRatio > 0 ? w.devicePixelRatio : 1
        return Math.ceil(size * dpr)
    }

    readonly property bool floatingIsland: data.islandStyle !== "attached"
    readonly property bool minimalIsland: data.minimal
    readonly property bool autoHide: data.autoHide
    readonly property string monitor: String(data.monitor || "").trim()

    readonly property string fontFamily: data.fontFamily
    readonly property string iconFont: data.iconFont

    readonly property string themeId: data.theme
    readonly property string wallpaperDir: data.wallpaperDir.replace(/^~/, Quickshell.env("HOME"))
    readonly property string wallpaperTransition: data.wallpaperTransition

    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    function c(key, fallback) {
        var v = palette.colors ? palette.colors[key] : undefined
        return v !== undefined && v !== "" ? v : fallback
    }

    readonly property bool glass: data.glass
    readonly property real glassOpacity: Math.max(0.3, Math.min(1, data.glassOpacity))
    readonly property color glassEdge: Qt.rgba(1, 1, 1, 0.16)
    readonly property color glassSheen: Qt.rgba(1, 1, 1, 0.09)

    function tint(value, alpha) {
        var col = Qt.color(value)
        return glass ? Qt.rgba(col.r, col.g, col.b, alpha) : col
    }

    readonly property color panel: tint(c("background", "#1e1e2e"), glassOpacity)

    readonly property color background: c("background", "#1e1e2e")
    readonly property color border: c("border", "#313244")
    readonly property color surface: tint(c("surface", "#313244"), 0.5)
    readonly property color highlight: tint(c("highlight", "#45475a"), 0.6)
    readonly property color selection: c("selection", "#585b70")

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

    readonly property color glow: c("glow", "#0cffffff")
    readonly property bool glowEnabled: data.glowEnabled
    readonly property bool darkShadow: data.darkShadow
    readonly property bool shadowEnabled: glowEnabled || darkShadow

    readonly property bool lockBlur: data.lockBlur
    readonly property bool loginBlur: data.loginBlur
    readonly property bool lockScreen: data.lockScreen
    readonly property bool sleepEnabled: data.sleepEnabled
    readonly property bool loginScreen: data.loginScreen

    readonly property bool bluetoothOnStartup: data.bluetoothOnStartup
    readonly property real idleLockMinutes: data.idleLockMinutes
    readonly property real idleSleepMinutes: data.idleSleepMinutes
    readonly property bool networkMonitor: data.networkMonitor

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("theme.json")
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
            property bool vscodeThemeSync: true
            property bool networkMonitor: false
        }
    }

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
