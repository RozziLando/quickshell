pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string repo: "RozziLando/quickshell"
    readonly property string branch: "main"
    readonly property string dir: Quickshell.shellDir
    readonly property string statusFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-update"

    property string mode: ""
    property string local: ""
    property string localDate: ""
    property string remote: ""
    property bool contained: false
    property bool checked: false
    property bool checking: false
    property real lastCheck: 0

    property string state: "idle"
    property string message: ""

    readonly property bool running: state === "running"
    readonly property bool enabled: Theme.updates
    readonly property bool available: enabled && checked && remote !== "" && !running
        && (mode === "git" ? !contained : local !== remote)
    readonly property string shortLocal: local !== "" ? local.substring(0, 7) : ""

    function check(force) {
        if (!enabled || checking || running) return
        if (!force && checked && Date.now() - lastCheck < 10 * 60 * 1000) return
        checking = true
        lastCheck = Date.now()
        checkProc.running = true
    }

    Process {
        id: checkProc
        command: ["sh", "-c",
            'd="$1"; repo="$2"; branch="$3";'
            + ' if [ -d "$d/.git" ] && command -v git >/dev/null 2>&1; then'
            + '  echo "mode git";'
            + '  echo "local $(git -C "$d" rev-parse HEAD 2>/dev/null) $(git -C "$d" log -1 --format=%cs 2>/dev/null)";'
            + ' else'
            + '  echo "mode archive";'
            + '  echo "local $(head -n 1 "$d/VERSION" 2>/dev/null)";'
            + ' fi;'
            + ' r=$(curl -fsS --connect-timeout 8 --max-time 15 -H "Accept: application/vnd.github.sha"'
            + '  "https://api.github.com/repos/$repo/commits/$branch" 2>/dev/null);'
            + ' echo "remote $r";'
            + ' if [ -n "$r" ] && [ -d "$d/.git" ]; then'
            + '  git -C "$d" merge-base --is-ancestor "$r" HEAD 2>/dev/null && echo contained;'
            + ' fi; true',
            "sh", root.dir, root.repo, root.branch]
        stdout: StdioCollector {
            onStreamFinished: {
                var sha = /^[0-9a-f]{40}$/
                var mode = "", local = "", date = "", remote = "", contained = false
                text.split("\n").forEach(function (line) {
                    var p = line.trim().split(/\s+/)
                    if (p[0] === "mode") mode = p[1] || ""
                    else if (p[0] === "local") {
                        local = sha.test(p[1] || "") ? p[1] : ""
                        date = /^\d{4}-\d{2}-\d{2}$/.test(p[2] || "") ? p[2] : ""
                    }
                    else if (p[0] === "remote") remote = sha.test(p[1] || "") ? p[1] : ""
                    else if (p[0] === "contained") contained = true
                })
                root.mode = mode
                root.local = local
                root.localDate = date
                root.remote = remote
                root.contained = contained
                root.checked = true
                root.checking = false
                if (root.state === "error" && !root.available) {
                    root.state = "idle"
                    root.message = ""
                }
            }
        }
        onExited: root.checking = false
    }

    onEnabledChanged: if (enabled) check(true)

    function update() {
        if (!enabled || running || checking) return
        state = "running"
        message = ""
        Quickshell.execDetached(["sh", "-c", 't=$(mktemp) || exit 1; cp "$0" "$t" && sh "$t" "$@"; rm -f "$t"',
                                 Quickshell.shellPath("scripts/update.sh"), dir, repo, branch, statusFile])
    }

    FileView {
        id: statusView
        path: root.statusFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readStatus(text())
        onLoadFailed: root.readStatus("")
    }

    function readStatus(content) {
        var line = String(content || "").split("\n")[0]
        var tab = line.indexOf("\t")
        var kind = tab >= 0 ? line.substring(0, tab) : line.trim()
        var rest = tab >= 0 ? line.substring(tab + 1) : ""
        if (kind === "running") {
            state = "running"
            message = ""
            aliveProc.command = ["sh", "-c", 'kill -0 "$1" 2>/dev/null', "sh", rest.trim() || "0"]
            aliveProc.running = true
        } else if (kind === "error") {
            state = "error"
            message = rest
        } else if (kind === "done") {
            var wasRunning = state === "running"
            state = "done"
            message = ""
            if (wasRunning || checked) check(true)
        } else {
            state = "idle"
            message = ""
        }
    }

    Process {
        id: aliveProc
        onExited: code => {
            if (code !== 0 && root.state === "running") {
                root.state = "error"
                root.message = "The update was interrupted"
            }
        }
    }
}
