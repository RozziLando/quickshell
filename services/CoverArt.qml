pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.cachePath("covers")
    property var ready: ({})
    property var waiting: []
    property string current: ""

    function key(url) {
        var h1 = 5381, h2 = 52711
        for (var i = 0; i < url.length; i++) {
            var c = url.charCodeAt(i)
            h1 = ((h1 << 5) + h1 + c) | 0
            h2 = ((h2 << 5) + h2 ^ c) | 0
        }
        return (h1 >>> 0).toString(16) + (h2 >>> 0).toString(16)
    }

    function source(url) {
        var u = String(url || "")
        if (u === "") return ""
        if (!/^https?:/i.test(u)) return u
        var file = dir + "/" + key(u)
        if (ready[u]) return "file://" + file
        Qt.callLater(root.request, u)
        return ""
    }

    function request(u) {
        if (ready[u] || current === u || waiting.indexOf(u) >= 0) return
        waiting = waiting.concat([u])
        next()
    }

    function next() {
        if (fetch.running || waiting.length === 0) return
        current = waiting[0]
        waiting = waiting.slice(1)
        fetch.command = ["sh", "-c",
            'mkdir -p "$3" || exit 1; f="$3/$2";'
            + ' if [ ! -s "$f" ]; then'
            + '  command -v curl >/dev/null 2>&1 || exit 1;'
            + '  curl -fsSL --max-time 15 -o "$f.part" "$1" && mv -f "$f.part" "$f" || { rm -f "$f.part"; exit 1; };'
            + '  ls -t "$3" | tail -n +61 | while IFS= read -r o; do rm -f "$3/$o"; done;'
            + ' fi; touch "$f"',
            "sh", current, key(current), dir]
        fetch.running = true
    }

    Process {
        id: fetch
        onExited: code => {
            if (code === 0 && root.current !== "") {
                var r = Object.assign({}, root.ready)
                r[root.current] = true
                root.ready = r
            }
            root.current = ""
            Qt.callLater(root.next)
        }
    }
}
