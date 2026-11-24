pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "wallmatch.js" as WallMatch

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string themesDir: Quickshell.shellPath("themes")

    property var themes: []
    property string pendingApply: ""
    readonly property string current: Theme.themeId

    function refresh() { listProc.running = true }

    Process {
        id: listProc
        running: true
        command: ["sh", "-c",
            'for f in "$1"/*.json; do printf "%s\\t" "$(basename "$f" .json)"; tr -d "\\n" < "$f"; echo; done',
            "sh", root.themesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = []
                text.split("\n").forEach(function (line) {
                    var tab = line.indexOf("\t")
                    if (tab < 0) return
                    try {
                        var t = JSON.parse(line.substring(tab + 1))
                        t.id = line.substring(0, tab)
                        if (!t.name) t.name = t.id
                        out.push(t)
                    } catch (e) {
                        console.warn("Tema non valido:", line.substring(0, tab), e)
                    }
                })
                out.sort(function (a, b) { return a.name.localeCompare(b.name) })
                root.themes = out
                root.ensureFiles()
                if (root.pendingApply !== "") {
                    var name = root.pendingApply
                    root.pendingApply = ""
                    root.apply(name)
                }
            }
        }
    }

    function ensureFiles() {
        var t = find(Theme.themeId)
        if (!t || ensureProc.running) return
        ensureProc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$4")"; if [ -n "$3" ] && command -v kitty >/dev/null 2>&1; then mkdir -p "$(dirname "$2")"; fi;'
            + ' [ -z "$3" ] || grep -qsxF "# Tema: $1" "$2" || echo missing;'
            + ' grep -qsxF "   Tema: $1 */" "$4" || echo missing',
            "sh", t.name, kittyFile.path, t.terminal ? "1" : "", gtkFile.path]
        ensureProc.running = true
    }

    Process {
        id: ensureProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("missing") < 0) return
                var t = root.find(Theme.themeId)
                if (!t) return
                if (t.terminal) kittyFile.setText(root.kittyConf(t))
                gtkFile.setText(root.gtkCss(t))
                root.runApplyScript([t.yaru || "", t.gnomeAccent || ""])
            }
        }
    }

    Connections {
        target: Theme
        function onThemeIdChanged() { ensureDelay.restart() }
    }

    Timer {
        id: ensureDelay
        interval: 800
        onTriggered: root.ensureFiles()
    }

    function find(id) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].id === id) return themes[i]
        return null
    }

    property var wallpapers: []

    readonly property string thumbDir: Quickshell.cachePath("wallpaper-thumbs")
    property string currentWallpaper: ""
    property bool wallpapersListed: false
    property bool currentChecked: false
    property bool initialDone: false

    function refreshWallpapers() {
        wallpaperProc.running = true
        currentProc.running = true
    }

    Process {
        id: wallpaperProc
        command: ["sh", "-c",
            'd="$2"; mkdir -p "$d"; keep="|";'
            + ' for f in "$1"/*; do case "$f" in'
            + '  *.png|*.PNG|*.jpg|*.JPG|*.jpeg|*.JPEG|*.webp|*.WEBP) ;; *) continue;; esac;'
            + '  t="$(basename "$f").$(stat -c %Y "$f").png"; keep="$keep$t|";'
            + '  if [ -f "$d/$t" ]; then e=1; else e=0; fi;'
            + '  printf "%s\\t%s\\t%s\\n" "$f" "$d/$t" "$e";'
            + ' done;'
            + ' for t in "$d"/*; do [ -f "$t" ] || continue;'
            + '  case "$keep" in *"|$(basename "$t")|"*) ;; *) rm -f "$t";; esac;'
            + ' done',
            "sh", Theme.wallpaperDir, root.thumbDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpapersListed = true
                root.wallpapers = text.split("\n").filter(function (l) { return l !== "" })
                    .map(function (l) {
                        var p = l.split("\t")
                        return { name: p[0].split("/").pop(), path: p[0],
                                 thumb: p[1] || "", hasThumb: p[2] === "1" }
                    })
                root.setInitialWallpaper()
            }
        }
    }

    readonly property string wallpaperScript: Quickshell.shellPath("scripts/wallpaper.sh")

    Process {
        id: currentProc
        command: ["sh", root.wallpaperScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentWallpaper = text.trim().split("/").pop()
                root.currentChecked = true
                root.setInitialWallpaper()
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", wallpaperScript, "restore"])
        refreshWallpapers()
    }

    Connections {
        target: Theme
        function onWallpaperDirChanged() { root.refreshWallpapers() }
    }

    function setInitialWallpaper() {
        if (initialDone || !wallpapersListed || !currentChecked) return
        initialDone = true
        if (currentWallpaper !== "" || wallpapers.length === 0) return
        var t = find(Theme.themeId)
        var name = t ? pickDefaultWallpaper(t) : ""
        if (name === "" || wallpaperFile(name) === "") name = wallpapers[0].name
        setWallpaper(Theme.wallpaperDir + "/" + name)
    }

    function transitionArgs() {
        var t = Theme.wallpaperTransition || "grow"
        var args = ["--transition-type", t, "--transition-fps", "60",
                    "--transition-duration", "1.4",
                    "--transition-bezier", ".4,0,.2,1"]
        if (t === "grow" || t === "outer") args = args.concat(["--transition-pos", "center"])
        if (t === "wave" || t === "wipe") args = args.concat(["--transition-angle", "30"])
        return args
    }

    function setWallpaper(path) {
        currentWallpaper = path.split("/").pop()
        GreeterSync.sync()
        Quickshell.execDetached(["sh", wallpaperScript, "set", path].concat(transitionArgs()))
        recheck.restart()
    }
    Timer {
        id: recheck
        interval: 1500
        onTriggered: currentProc.running = true
    }

    function apply(id, keepWallpaper) {
        var t = find(id)
        if (!t) {
            console.warn("Tema sconosciuto:", id)
            return
        }

        if (!Settings.set("theme", id)) return

        if (t.terminal) kittyFile.setText(kittyConf(t))
        gtkFile.setText(gtkCss(t))

        var name = keepWallpaper ? "" : pickDefaultWallpaper(t)
        runApplyScript([t.yaru || "", t.gnomeAccent || ""])
        if (name !== "") setWallpaper(Theme.wallpaperDir + "/" + name)
        return name
    }

    property var queuedApply: null
    function runApplyScript(args) {
        if (applyProc.running) {
            queuedApply = args
            return
        }
        applyProc.command = ["sh", "-c", applyScript, "sh"].concat(args)
        applyProc.running = true
    }

    function wallpaperFile(entry) {
        for (var i = 0; i < wallpapers.length; i++) {
            var n = wallpapers[i].name
            if (n === entry || n.replace(/\.[^.]*$/, "") === entry) return n
        }
        return ""
    }

    function toList(value) {
        if (typeof value === "string") return [value]
        if (value && typeof value === "object" && typeof value.length === "number")
            return Array.prototype.slice.call(value)
        return []
    }

    function wallpaperNames(value) {
        var list = toList(value)
        return list.map(function (w) { return String(w || "").trim().split("/").pop() })
                   .filter(function (w) { return w !== "" })
    }

    function wallpapersFor(id) {
        var out = []
        wallpaperNames(Theme.themeWallpapers[id]).forEach(function (n) {
            var f = root.wallpaperFile(n)
            if (f !== "" && out.indexOf(f) < 0) out.push(f)
        })
        return out
    }

    function themesFor(file) {
        var list = toList(Theme.wallpaperThemes[file])
        var out = []
        list.forEach(function (id) {
            id = String(id || "")
            if (id !== "" && root.find(id) && out.indexOf(id) < 0) out.push(id)
        })
        return out
    }

    function randomOf(list) {
        return list.length > 0 ? list[Math.floor(Math.random() * list.length)] : ""
    }

    function chosenWallpaper(id) { return randomOf(wallpapersFor(id)) }
    function chosenTheme(file) { return randomOf(themesFor(file)) }

    function pickDefaultWallpaper(t) {
        var chosen = chosenWallpaper(t.id)
        if (chosen !== "") return chosen
        var list = wallpaperNames(t.defaultWallpapers)
        var found = list.map(wallpaperFile).filter(function (w) { return w !== "" })
        if (found.length > 0) list = found
        return list.length > 0 ? list[Math.floor(Math.random() * list.length)] : ""
    }

    FileView {
        id: kittyFile
        path: root.home + "/.config/kitty/quickshell-theme.conf"
        blockWrites: true
        printErrors: false
    }
    FileView {
        id: gtkFile
        path: root.home + "/.config/gtk-4.0/quickshell-theme.css"
        blockWrites: true
        printErrors: false
    }

    Process {
        id: applyProc
        onExited: if (root.queuedApply) Qt.callLater(function () {
            var args = root.queuedApply
            root.queuedApply = null
            if (args) root.runApplyScript(args)
        })
    }

    readonly property string applyScript: '
        y="$1"; acc="$2"

        k="$HOME/.config/kitty/kitty.conf"
        if [ ! -f "$k" ] && command -v kitty >/dev/null 2>&1; then
            mkdir -p "$(dirname "$k")"
            printf "# Colori dal theme switcher di Quickshell\\ninclude quickshell-theme.conf\\n" > "$k"
        fi
        if [ -f "$k" ] && ! grep -q "^include quickshell-theme.conf" "$k"; then
            cp "$k" "$k.bak-theme"
            printf "\\n# Colori dal theme switcher di Quickshell (lasciare in fondo)\\ninclude quickshell-theme.conf\\n" >> "$k"
        fi
        pkill -USR1 -x kitty 2>/dev/null

        g="$HOME/.config/gtk-4.0/gtk.css"
        mkdir -p "$(dirname "$g")"
        if ! grep -qs "quickshell-theme.css" "$g"; then
            if [ -L "$g" ] || [ ! -s "$g" ]; then
                [ -L "$g" ] && mv "$g" "$g.bak-theme"
                printf "@import url(\\"quickshell-theme.css\\");\\n" > "$g"
            else
                cp "$g" "$g.bak-theme"
                { printf "@import url(\\"quickshell-theme.css\\");\\n"; cat "$g.bak-theme"; } > "$g"
            fi
        fi

        if command -v gsettings >/dev/null 2>&1; then
            if [ -n "$y" ]; then icon="Yaru-$y-dark"; else icon="Yaru-dark"; fi
            for d in /usr/share/icons "$HOME/.local/share/icons" "$HOME/.icons"; do
                if [ -d "$d/$icon" ]; then
                    gsettings set org.gnome.desktop.interface icon-theme "$icon"
                    break
                fi
            done
            [ -n "$acc" ] && gsettings set org.gnome.desktop.interface accent-color "$acc" 2>/dev/null
        fi
    '

    function kittyConf(t) {
        var c = t.colors || {}, term = t.terminal, ansi = term.ansi || []
        var lines = [
            "# Generato dal theme switcher di Quickshell: non modificare a mano",
            "# Tema: " + t.name,
            "",
            "foreground " + term.foreground,
            "background " + term.background,
            "cursor " + term.cursor,
            "cursor_text_color " + term.background,
            "selection_foreground " + term.selectionForeground,
            "selection_background " + term.selectionBackground,
            "url_color " + (c.accent || term.foreground),
            "",
            "active_border_color " + (c.accent || term.foreground),
            "inactive_border_color " + (c.border || term.background),
            "tab_bar_background " + (c.background || term.background),
            "active_tab_foreground " + (c.background || term.background),
            "active_tab_background " + (c.accent || term.foreground),
            "inactive_tab_foreground " + (c.textSecondary || term.foreground),
            "inactive_tab_background " + (c.card || term.background),
            ""
        ]
        for (var i = 0; i < ansi.length && i < 16; i++)
            lines.push("color" + i + " " + ansi[i])
        return lines.join("\n") + "\n"
    }

    function gtkCss(t) {
        var c = t.colors || {}
        var map = {
            "accent_color": c.accent,
            "accent_bg_color": c.accent,
            "accent_fg_color": c.background,
            "destructive_color": c.warning,
            "destructive_bg_color": c.warning,
            "destructive_fg_color": c.background,
            "window_bg_color": c.card,
            "window_fg_color": c.text,
            "view_bg_color": c.card,
            "view_fg_color": c.text,
            "headerbar_bg_color": c.card,
            "headerbar_fg_color": c.text,
            "headerbar_backdrop_color": c.card,
            "sidebar_bg_color": c.background,
            "sidebar_fg_color": c.text,
            "sidebar_backdrop_color": c.background,
            "secondary_sidebar_bg_color": c.background,
            "secondary_sidebar_fg_color": c.text,
            "card_bg_color": c.surface,
            "card_fg_color": c.text,
            "popover_bg_color": c.card,
            "popover_fg_color": c.text,
            "dialog_bg_color": c.card,
            "dialog_fg_color": c.text
        }
        var defs = [], vars = []
        for (var k in map) {
            if (!map[k]) continue
            defs.push("@define-color " + k + " " + map[k] + ";")
            vars.push("    --" + k.replace(/_/g, "-") + ": " + map[k] + ";")
        }
        return "/* Generato dal theme switcher di Quickshell: non modificare a mano\n"
            + "   Tema: " + t.name + " */\n\n"
            + defs.join("\n") + "\n\n:root {\n" + vars.join("\n") + "\n}\n"
    }

    function favoriteThemeFor(path) {
        var file = String(path || "").split("/").pop()
        if (file === "") return ""
        var chosen = chosenTheme(file)
        if (chosen !== "") return chosen
        var stem = file.replace(/\.[^.]*$/, "")
        var ids = []
        for (var i = 0; i < themes.length; i++) {
            var list = themes[i].preferredBy
            if (typeof list === "string") list = [list]
            if (!Array.isArray(list)) continue
            for (var j = 0; j < list.length; j++) {
                var w = String(list[j] || "").trim().split("/").pop()
                if (w !== "" && (w === file || w === stem)) { ids.push(themes[i].id); break }
            }
        }
        if (ids.length > 0) return ids[Math.floor(Math.random() * ids.length)]
        for (i = 0; i < themes.length; i++) {
            var defaults = wallpaperNames(themes[i].defaultWallpapers)
            if (defaults.indexOf(file) >= 0 || defaults.indexOf(stem) >= 0) return themes[i].id
        }
        return ""
    }

    function bestThemeFor(pixels, path) {
        return favoriteThemeFor(path) || WallMatch.best(pixels, themes)
    }

    IpcHandler {
        target: "theme"
        function set(name: string): void {
            if (root.find(name)) { root.apply(name); return }
            root.pendingApply = name
            root.refresh()
        }
        function list(): string {
            root.refresh()
            return root.themes.map(function (t) { return t.id }).join("\n")
        }
        function current(): string { return root.current }
    }
}
