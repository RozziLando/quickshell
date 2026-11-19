pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        id: file
        path: Quickshell.shellPath("theme.json")
        blockAllReads: true
        blockWrites: true
    }

    function edit(change) {
        file.reload()
        var settings
        try { settings = JSON.parse(file.text()) } catch (e) {
            console.warn("theme.json non valido, impostazione non salvata:", e)
            return false
        }
        if (!settings || typeof settings !== "object" || Array.isArray(settings)) return false
        change(settings)
        file.setText(JSON.stringify(settings, null, 2) + "\n")
        return true
    }

    function set(key, value) {
        return edit(function (s) { s[key] = value })
    }

    function setEntry(key, name, value) {
        return edit(function (s) {
            var old = s[key], map = {}
            if (old && typeof old === "object" && !Array.isArray(old))
                for (var k in old) map[k] = old[k]
            if (value === undefined || value === null || value === ""
                || (Array.isArray(value) && value.length === 0)) delete map[name]
            else map[name] = value
            if (Object.keys(map).length > 0) s[key] = map
            else delete s[key]
        })
    }

    readonly property string desktopFile: (Quickshell.env("XDG_DATA_HOME")
        || Quickshell.env("HOME") + "/.local/share") + "/applications/quickshell-settings.desktop"

    readonly property string desktopEntry: [
        "[Desktop Entry]",
        "Type=Application",
        "Name=Quickshell Settings",
        "Comment=Settings of the Quickshell island",
        "Exec=quickshell ipc call settings open",
        "Icon=preferences-system",
        "Categories=Settings;DesktopSettings;",
        "Keywords=quickshell;island;theme;wallpaper;settings;",
        "Terminal=false",
        "StartupNotify=false",
        ""
    ].join("\n")

    Process {
        running: true
        command: ["sh", "-c",
            'f="$1"; mkdir -p "$(dirname "$f")" || exit 0;'
            + ' printf "%s" "$2" | cmp -s - "$f" && exit 0;'
            + ' printf "%s" "$2" > "$f.tmp" && mv -f "$f.tmp" "$f"',
            "sh", root.desktopFile, root.desktopEntry]
    }
}
