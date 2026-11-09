pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "wallmatch.js" as WallMatch

// Cambio tema: un file per tema in themes/<id>.json. Applicare un tema
// aggiorna in un colpo solo:
//   - Quickshell: "theme" in theme.json (Theme.qml ricarica i colori);
//     l'ombra di Hyprland segue da sola il colore "glow" (HyprShadowSync)
//   - kitty: ~/.config/kitty/quickshell-theme.conf, incluso in fondo a
//     kitty.conf, e ricarica dei terminali aperti (SIGUSR1)
//   - Nautilus (libadwaita): ~/.config/gtk-4.0/quickshell-theme.css,
//     importato da gtk.css; cartelle colorate con la variante Yaru del tema
//     e colore d'accento di GNOME
//   - sfondo: "wallpaper" del tema, cercato in "wallpaperDir" (theme.json)
//
//   qs ipc call theme set nord
//   qs ipc call theme list
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string themesDir: Quickshell.shellPath("themes")

    // [{ id, name, colors, terminal, yaru, gnomeAccent, wallpaper }]
    property var themes: []
    // Tema chiesto via IPC prima che l'elenco fosse aggiornato
    property string pendingApply: ""
    readonly property string current: Theme.themeId

    // ---------- Elenco dei temi ----------
    function refresh() { listProc.running = true }

    Process {
        id: listProc
        running: true
        // Un tema per riga: "<id>\t<json su una riga>"
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
                if (root.pendingApply !== "") {
                    var name = root.pendingApply
                    root.pendingApply = ""
                    root.apply(name)    // se non c'è nemmeno ora: avviso nel log
                }
            }
        }
    }

    function find(id) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].id === id) return themes[i]
        return null
    }

    // ---------- Sfondi (cartella "wallpaperDir" di theme.json) ----------
    // [{ name, path, thumb, hasThumb }]
    property var wallpapers: []

    // Anteprime già pronte (PNG piccoli): decodificare ogni volta lo sfondo
    // intero (un PNG 4K) richiedeva fino a ~0,3 s per scheda. Il nome
    // contiene la data di modifica: sfondo cambiato -> anteprima nuova.
    // Quelle di sfondi che non ci sono più vengono cancellate.
    readonly property string thumbDir: Quickshell.cachePath("wallpaper-thumbs")
    // Nome del file mostrato ora (da awww/swww)
    property string currentWallpaper: ""

    function refreshWallpapers() {
        wallpaperProc.running = true
        currentProc.running = true
    }

    Process {
        id: wallpaperProc
        // Una riga per sfondo: "<file>\t<anteprima>\t<1 se esiste già>"
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
                root.wallpapers = text.split("\n").filter(function (l) { return l !== "" })
                    .map(function (l) {
                        var p = l.split("\t")
                        return { name: p[0].split("/").pop(), path: p[0],
                                 thumb: p[1] || "", hasThumb: p[2] === "1" }
                    })
            }
        }
    }

    // Sfondo con awww/swww, oppure swaybg (scripts/wallpaper.sh)
    readonly property string wallpaperScript: Quickshell.shellPath("scripts/wallpaper.sh")

    Process {
        id: currentProc
        command: ["sh", root.wallpaperScript, "get"]
        stdout: StdioCollector {
            onStreamFinished: root.currentWallpaper = text.trim().split("/").pop()
        }
    }

    // swaybg non ricorda lo sfondo: lo rimette la shell all'avvio.
    // Elenco degli sfondi già pronto: alla prima apertura dei temi non
    // compare per un attimo "No wallpapers found"
    Component.onCompleted: {
        Quickshell.execDetached(["sh", wallpaperScript, "restore"])
        refreshWallpapers()
    }

    // Opzioni dell'animazione ("wallpaperTransition" in theme.json)
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
        GreeterSync.sync()          // il login prende il nuovo sfondo
        Quickshell.execDetached(["sh", wallpaperScript, "set", path].concat(transitionArgs()))
        // Poi si rilegge quello vero: se il file non c'era (es. "wallpaper"
        // di un tema assente in wallpaperDir) resta segnato quello di prima
        recheck.restart()
    }
    Timer {
        id: recheck
        interval: 1500
        onTriggered: currentProc.running = true
    }

    // ---------- Applicazione ----------
    // keepWallpaper: non cambia lo sfondo (tema scelto in base allo sfondo)
    function apply(id, keepWallpaper) {
        var t = find(id)
        if (!t) {
            console.warn("Tema sconosciuto:", id)
            return
        }

        // 1. Quickshell: tema attivo in theme.json (il resto del file resta)
        // theme.json illeggibile (es. una virgola sbagliata scrivendolo a
        // mano): non si tocca, altrimenti si perderebbero le impostazioni
        settingsFile.reload()
        var settings
        try { settings = JSON.parse(settingsFile.text()) } catch (e) {
            console.warn("theme.json non valido, tema non salvato:", e)
            return
        }
        settings.theme = id
        settingsFile.setText(JSON.stringify(settings, null, 2) + "\n")

        // 2. kitty e 3. Nautilus: file generati
        if (t.terminal) kittyFile.setText(kittyConf(t))
        gtkFile.setText(gtkCss(t))

        // 4. Inclusioni, Yaru, accento GNOME, sfondo
        var wallpaper = t.wallpaper && !keepWallpaper ? Theme.wallpaperDir + "/" + t.wallpaper : ""
        applyProc.command = ["sh", "-c", applyScript, "sh",
                             t.yaru || "", t.gnomeAccent || ""]
        applyProc.running = true
        if (wallpaper !== "") setWallpaper(wallpaper)
    }

    FileView {
        id: settingsFile
        path: Quickshell.shellPath("theme.json")
        blockAllReads: true
    }
    FileView {
        id: kittyFile
        path: root.home + "/.config/kitty/quickshell-theme.conf"
        printErrors: false
    }
    FileView {
        id: gtkFile
        path: root.home + "/.config/gtk-4.0/quickshell-theme.css"
        printErrors: false
    }

    Process { id: applyProc }

    // $1 variante Yaru ("" = arancione), $2 accento GNOME
    readonly property string applyScript: '
        y="$1"; acc="$2"

        # kitty: include in fondo (vince sui colori scritti prima) e ricarica
        k="$HOME/.config/kitty/kitty.conf"
        # kitty installato ma senza kitty.conf (funziona anche così): si crea
        if [ ! -f "$k" ] && command -v kitty >/dev/null 2>&1; then
            mkdir -p "$(dirname "$k")"
            printf "# Colori dal theme switcher di Quickshell\\ninclude quickshell-theme.conf\\n" > "$k"
        fi
        if [ -f "$k" ] && ! grep -q "^include quickshell-theme.conf" "$k"; then
            cp "$k" "$k.bak-theme"
            printf "\\n# Colori dal theme switcher di Quickshell (lasciare in fondo)\\ninclude quickshell-theme.conf\\n" >> "$k"
        fi
        pkill -USR1 -x kitty 2>/dev/null

        # Nautilus / GTK 4: gtk.css importa i colori del tema
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

        # Icone Yaru del colore del tema (se installate) e accento GNOME
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

    // ---------- File generati ----------
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

    // Colori di libadwaita (Nautilus e app GTK 4): variabili CSS (libadwaita
    // ≥ 1.6) e @define-color (versioni precedenti)
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

    // ---------- Tema più adatto a uno sfondo ----------
    // pixels: RGBA dello sfondo disegnato in piccolo (vedi Launcher).
    // Un tema che dichiara proprio quello sfondo ("wallpaper") vince subito;
    // altrimenti si confrontano i colori principali dell'immagine con
    // accento, colori ANSI e tinta di sfondo di ogni tema (wallmatch.js)
    function bestThemeFor(pixels, path) {
        var file = String(path || "").split("/").pop()
        for (var i = 0; file !== "" && i < themes.length; i++)
            if (themes[i].wallpaper === file) return themes[i].id
        return WallMatch.best(pixels, themes)
    }

    IpcHandler {
        target: "theme"
        // Tema non ancora nell'elenco (file appena aggiunto in themes/): si
        // rilegge la cartella e si applica appena pronta
        function set(name: string): void {
            if (root.find(name)) { root.apply(name); return }
            root.pendingApply = name
            root.refresh()
        }
        // Elenco attuale; intanto si rilegge la cartella (temi appena aggiunti)
        function list(): string {
            root.refresh()
            return root.themes.map(function (t) { return t.id }).join("\n")
        }
        function current(): string { return root.current }
    }
}
