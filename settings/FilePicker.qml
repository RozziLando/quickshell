import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io

Item {
    id: root

    visible: false

    property var callback: null
    property string mode: ""
    readonly property bool busy: proc.running || fileDialog.visible || folderDialog.visible

    function open(kind, title, start, done) {
        if (busy) return
        mode = kind
        callback = done
        proc.command = ["sh", Quickshell.shellPath("scripts/pick.sh"), kind, title,
                        start || Quickshell.env("HOME")]
        fileDialog.title = title
        folderDialog.title = title
        var folder = "file://" + (start || Quickshell.env("HOME"))
        fileDialog.currentFolder = folder
        folderDialog.currentFolder = folder
        proc.running = true
    }

    function finish(paths) {
        var done = callback
        callback = null
        paths = paths.filter(function (p) { return p !== "" })
        if (done && paths.length > 0) done(paths)
    }

    function localPath(url) {
        var s = String(url)
        return s.indexOf("file://") === 0 ? decodeURIComponent(s.substring(7)) : s
    }

    property int exitCode: -1
    property bool streamDone: false
    property string output: ""

    Process {
        id: proc
        onStarted: {
            root.exitCode = -1
            root.streamDone = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.output = text
                root.streamDone = true
                root.handle()
            }
        }
        onExited: code => {
            root.exitCode = code
            root.handle()
        }
    }

    function handle() {
        if (exitCode < 0 || !streamDone) return
        var code = exitCode
        exitCode = -1
        streamDone = false
        if (code === 3) {
            if (mode === "dir") folderDialog.open()
            else {
                fileDialog.fileMode = mode === "images" ? FileDialog.OpenFiles : FileDialog.OpenFile
                fileDialog.open()
            }
            return
        }
        finish(code === 0 ? output.split("\n").map(function (l) { return l.trim() }) : [])
    }

    FileDialog {
        id: fileDialog
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP)"]
        onAccepted: root.finish(selectedFiles.map(root.localPath))
        onRejected: root.finish([])
    }

    FolderDialog {
        id: folderDialog
        onAccepted: root.finish([root.localPath(selectedFolder)])
        onRejected: root.finish([])
    }
}
