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

    readonly property real cornerBase: Math.max(0, Math.min(30, Number(data.cornerRadius)))
    readonly property int radius: s(cornerBase)
    readonly property real roundness: Math.min(1, cornerBase / 15)

    function round(size) {
        return size / 2 * roundness
    }

    readonly property bool barMode: data.layout === "bar"
    readonly property string barStyle: data.barStyle === "capsules" ? "integrated"
        : ["attached", "floating", "integrated", "transparent", "pills", "pillsAttached"].indexOf(data.barStyle) >= 0 ? data.barStyle : "floating"
    readonly property bool barCurves: data.barCurves !== false
    readonly property bool barFrame: ((barStyle === "integrated" && barCurves) || barStyle === "pillsAttached") && data.barFrame === true
    readonly property bool barPills: barStyle === "pills" || barStyle === "pillsAttached"
    readonly property bool barFused: data.barFused !== false && barStyle !== "transparent" && !barPills
    readonly property real barLength: Math.max(20, Math.min(100, Number(data.barLength) || 100)) / 100
    readonly property real edgeGapBase: Math.max(0, Math.min(30, Number(data.edgeGap)))
    readonly property int edgeGap: s(edgeGapBase)
    readonly property bool controlCenter: data.controlCenter !== false
    readonly property bool hyprRounding: data.hyprRounding === true
    readonly property bool hyprGaps: data.hyprGaps === true
    readonly property string barPosition: ["top", "bottom", "left", "right"].indexOf(data.barPosition) >= 0
        ? data.barPosition : "top"
    readonly property bool barVertical: barPosition === "left" || barPosition === "right"
    readonly property var barItems: data.barItems
    readonly property bool clockWeekday: data.clockWeekday === true
    readonly property bool clockDay: data.clockDay === true
    readonly property bool clockMonth: data.clockMonth === true
    readonly property string toastPosition: ["top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"]
        .indexOf(data.toastPosition) >= 0 ? data.toastPosition : "top-right"
    readonly property var toastSpots: ["top-left", "top", "top-right", "bottom-left", "bottom", "bottom-right"]
    readonly property bool toastSeparate: data.toastSeparate === true
    readonly property string mediaPosition: toastSpots.indexOf(data.mediaPosition) >= 0 ? data.mediaPosition : toastPosition
    readonly property string osdPosition: toastSpots.indexOf(data.osdPosition) >= 0 ? data.osdPosition : toastPosition
    readonly property string popupAnimation: ["pop", "slide", "zoom", "unfold", "fade", "none"].indexOf(data.popupAnimation) >= 0 ? data.popupAnimation : "pop"
    readonly property real popupSpeed: data.popupSpeed === "relaxed" ? 1.35 : data.popupSpeed === "snappy" ? 0.7 : 1
    readonly property bool audioPanel: data.audioPanel === true

    readonly property bool floatingIsland: data.islandStyle !== "attached"
    readonly property bool minimalIsland: data.minimal
    readonly property bool autoHide: data.autoHide
    readonly property string monitor: String(data.monitor || "").trim()

    function isMonitor(screen) {
        return monitor !== "" && !!screen
            && (screen.name === monitor || String(screen.model || "").trim() === monitor)
    }

    readonly property string fontFamily: data.fontFamily
    readonly property string iconFont: data.iconFont

    readonly property string themeId: data.theme
    readonly property string wallpaperDir: data.wallpaperDir.replace(/^~/, Quickshell.env("HOME"))
    readonly property string wallpaperTransition: data.wallpaperTransition
    readonly property var themeWallpapers: data.themeWallpapers || ({})
    readonly property var wallpaperThemes: data.wallpaperThemes || ({})

    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    function c(key, fallback) {
        var v = palette.colors ? palette.colors[key] : undefined
        return v !== undefined && v !== "" ? v : fallback
    }

    readonly property bool glass: data.glass
    readonly property real glassOpacity: Math.max(0.3, Math.min(1, data.glassOpacity))

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
    readonly property bool updates: data.updates !== false
    readonly property bool sleepEnabled: data.sleepEnabled
    readonly property bool loginScreen: data.loginScreen

    readonly property bool bluetoothOnStartup: data.bluetoothOnStartup
    readonly property real idleLockMinutes: data.idleLockMinutes
    readonly property real idleSleepMinutes: data.idleSleepMinutes
    readonly property bool networkMonitor: data.networkMonitor
    readonly property bool backgroundApps: data.backgroundApps
    readonly property bool powerMode: data.powerMode
    readonly property bool showEmptyWorkspaces: data.showEmptyWorkspaces !== false
    readonly property bool displayOnDesktop: data.displayOnDesktop
    readonly property bool vscodeThemeSync: data.vscodeThemeSync
    readonly property var controlTiles: data.controlTiles
    readonly property var controlSections: data.controlSections
    readonly property var controlWidths: data.controlWidths
    readonly property var controlItems: data.controlItems
    readonly property var controlGrid: data.controlGrid
    readonly property var controlBottom: data.controlBottom

    Process {
        id: seed
        command: ["sh", "-c",
            '[ -s "$1" ] && exit 0; [ -f "$2" ] && cp "$2" "$1" || exit 0;'
            + ' for b in /sys/class/power_supply/*; do'
            + '  [ "$(cat "$b/type" 2>/dev/null)" = Battery ] || continue;'
            + '  [ "$(cat "$b/scope" 2>/dev/null)" = Device ] && continue;'
            + '  [ -s "$3" ] && exit 11;'
            + ' done; exit 10', "sh",
            Quickshell.shellPath("theme.json"), Quickshell.shellPath("theme.default.json"),
            Quickshell.shellPath("theme.laptop.json")]
        onExited: code => {
            if (code === 11) {
                laptopDefaults.pending = true
                laptopDefaults.reload()
            }
            else if (code === 10) settingsFile.reload()
        }
    }

    FileView {
        id: laptopDefaults
        property bool pending: false
        path: Quickshell.shellPath("theme.laptop.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            if (!pending) return
            pending = false
            var extra
            try { extra = JSON.parse(text()) } catch (e) { extra = null }
            if (extra && typeof extra === "object" && !Array.isArray(extra))
                Settings.edit(function (s) { for (var k in extra) s[k] = extra[k] })
            settingsFile.reload()
        }
        onLoadFailed: {
            if (!pending) return
            pending = false
            settingsFile.reload()
        }
    }

    Component.onCompleted: seed.running = true

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("theme.json")
        Component.onCompleted: text()
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoadFailed: seed.running = true

        adapter: JsonAdapter {
            id: data

            property real scale: 1.1
            property real cornerRadius: 15
            property string fontFamily: "Inter"
            property string iconFont: "phosphor"
            property string islandStyle: "floating"
            property bool minimal: false
            property bool autoHide: false
            property string monitor: ""
            property bool glowEnabled: false
            property bool darkShadow: true
            property bool glass: false
            property bool glassAuto: false
            property real glassOpacity: 0.75
            property string theme: "midnight"
            property bool bluetoothOnStartup: true
            property bool lockBlur: true
            property bool loginBlur: true
            property bool lockScreen: true
            property bool updates: true
            property bool sleepEnabled: true
            property bool loginScreen: true
            property real idleLockMinutes: 10
            property real idleSleepMinutes: 10
            property string wallpaperDir: "~/Wallpapers"
            property string wallpaperTransition: "grow"
            property bool vscodeThemeSync: true
            property bool networkMonitor: true
            property bool backgroundApps: true
            property bool powerMode: true
            property bool showEmptyWorkspaces: true
            property bool displayOnDesktop: true
            property string layout: "bar"
            property string barStyle: "pills"
            property bool barFrame: false
            property bool barCurves: false
            property bool barFused: true
            property real barLength: 100
            property real edgeGap: 5
            property bool controlCenter: true
            property bool hyprRounding: false
            property bool hyprGaps: false
            property string barPosition: "top"
            property var barItems: ({})
            property bool clockWeekday: false
            property bool clockDay: false
            property bool clockMonth: false
            property string toastPosition: "top-right"
            property bool toastSeparate: true
            property string popupAnimation: "pop"
            property string popupSpeed: "normal"
            property string mediaPosition: "top"
            property string osdPosition: "bottom"
            property bool audioPanel: true
            property var controlTiles: "auto"
            property var controlSections: "auto"
            property var controlWidths: ({})
            property var controlItems: "auto"
            property var controlGrid: "auto"
            property var controlBottom: "auto"
            property var themeWallpapers: ({})
            property var wallpaperThemes: ({})
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
