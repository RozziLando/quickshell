import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import qs.services

Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    readonly property string userName: Quickshell.env("USER") || ""

    property string wallpaperPath: ""
    property var shotScreens: []
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    function shotPath(screenName) { return shotDir + "/qs-lock-" + screenName + ".jpg" }

    property bool suspendAfterLock: false

    readonly property bool enabled: Theme.lockScreen

    function lock() {
        if (!enabled || sessionLock.locked || capture.running) return
        errorText = ""
        GreeterSync.sync()
        shotScreens = []
        capture.command = ["sh", "-c",
            'sh "$1" get; shift;'
            + ' if [ "$1" = 1 ]; then shift;'
            + '  for o in "$@"; do grim -t jpeg -q 85 -o "$o" "' + shotDir + '/qs-lock-$o.jpg" 2>/dev/null && echo "SHOT $o"; done;'
            + ' fi',
            "sh", Quickshell.shellPath("scripts/wallpaper.sh"), Theme.lockBlur ? "1" : "0"]
            .concat(Quickshell.screens.map(function (sc) { return sc.name }))
        capture.running = true
        captureTimeout.restart()
    }

    function lockAndSuspend() {
        if (!enabled) { suspendNow(); return }
        suspendAfterLock = true
        if (sessionLock.secure) suspendNow()
        else lock()
    }

    function suspendNow() {
        suspendAfterLock = false
        Quickshell.execDetached(["systemctl", "suspend"])
    }

    Process {
        id: capture
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                if (lines[0] && lines[0].indexOf("SHOT ") !== 0) root.wallpaperPath = lines[0]
                if (!sessionLock.locked)
                    root.shotScreens = lines.filter(function (l) { return l.indexOf("SHOT ") === 0 })
                                            .map(function (l) { return l.substring(5) })
                root.engage()
            }
        }
    }

    Timer {
        id: captureTimeout
        interval: 3000
        onTriggered: root.engage()
    }

    function engage() {
        captureTimeout.stop()
        if (sessionLock.locked) return
        sessionLock.locked = true
    }

    property string errorText: ""
    property string pendingPassword: ""
    property var pamNotices: []

    function tryUnlock(password) {
        if (pam.active) return
        errorText = ""
        pendingPassword = password
        pamNotices = []
        pam.start()
    }

    PamContext {
        id: pam
        config: "login"
        user: root.userName

        onMessageChanged: if (message !== "") root.pamNotices = root.pamNotices.concat([message])

        onResponseRequiredChanged: {
            if (responseRequired) {
                var n = root.pamNotices
                if (n.length > 0 && n[n.length - 1] === message) root.pamNotices = n.slice(0, -1)
                respond(root.pendingPassword)
                root.pendingPassword = ""
            }
        }
        onCompleted: result => {
            root.pendingPassword = ""
            if (result === PamResult.Success) {
                sessionLock.locked = false
                Quickshell.execDetached(["sh", "-c", 'rm -f "$1"/qs-lock-*.jpg', "sh", root.shotDir])
            } else {
                root.errorText = root.pamNotices.length > 0 ? root.pamNotices.join(" ") : "Incorrect password"
                root.failed()
            }
        }
        onError: error => {
            root.pendingPassword = ""
            root.errorText = "Authentication error"
            root.failed()
        }
    }

    signal failed()

    property var avatarFiles: []
    Process {
        id: avatarProc
        running: true
        command: ["sh", "-c", 'for e in png jpg jpeg; do [ -f "$1.$e" ] && echo "$1.$e"; done; true',
                  "sh", Quickshell.shellPath("assets/avatar")]
        stdout: StdioCollector {
            onStreamFinished: root.avatarFiles = text.split("\n").filter(function (l) { return l !== "" })
        }
    }
    onLockedChanged: if (locked && !avatarProc.running) avatarProc.running = true

    WlSessionLock {
        id: sessionLock

        onSecureChanged: {
            if (!secure) return
            if (root.suspendAfterLock) root.suspendNow()
            if (root.sleepPending) inhibitor.running = false
        }

        WlSessionLockSurface {
            id: surface
            color: "black"

            LoginView {
                id: view
                anchors.fill: parent
                backgroundSource: Theme.lockBlur && surface.screen
                                  && root.shotScreens.indexOf(surface.screen.name) >= 0
                    ? Theme.fileUrl(root.shotPath(surface.screen.name))
                    : root.wallpaperPath !== "" ? Theme.fileUrl(root.wallpaperPath) : ""
                userName: root.userName
                avatarSources: root.avatarFiles.map(Theme.fileUrl)
                busy: pam.active
                errorText: root.errorText
                onSubmitted: password => root.tryUnlock(password)

                Connections {
                    target: root
                    function onFailed() { view.fail(root.errorText) }
                }
            }
        }
    }

    property bool sleepPending: false
    onEnabledChanged: if (!sleepPending) inhibitor.running = enabled

    Process {
        id: inhibitor
        running: root.enabled
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay",
                  "--who=Quickshell", "--why=Lock the screen before sleep", "cat"]
    }

    function prepareForSleep(start) {
        if (start) {
            sleepPending = true
            Mpris.players.values.forEach(function (p) { if (p.canPause && p.isPlaying) p.pause() })
            if (sessionLock.secure || !root.enabled) inhibitor.running = false
            else lock()
        } else {
            sleepPending = false
            inhibitor.running = root.enabled
        }
    }

    readonly property string sessionPath: {
        var id = Quickshell.env("XDG_SESSION_ID") || ""
        if (id === "") return ""
        var out = ""
        for (var i = 0; i < id.length; i++) {
            var ch = id[i]
            var keep = /[A-Za-z0-9]/.test(ch) && !(i === 0 && /[0-9]/.test(ch))
            out += keep ? ch : "_" + ch.charCodeAt(0).toString(16)
        }
        return "/org/freedesktop/login1/session/" + out
    }
    function isOurSession(line) {
        return sessionPath === "" || line.indexOf(sessionPath + ":") >= 0
    }

    Process {
        id: logindWatch
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep (true") >= 0) root.prepareForSleep(true)
                else if (line.indexOf("PrepareForShutdown (true") >= 0) GreeterSync.syncNow()
                else if (line.indexOf("PrepareForSleep (false") >= 0) root.prepareForSleep(false)
                else if (line.indexOf(".Session.Lock ") >= 0 && root.isOurSession(line)) root.lock()
            }
        }
        onRunningChanged: if (!running) watchRestart.restart()
    }
    Timer {
        id: watchRestart
        interval: 3000
        onTriggered: logindWatch.running = true
    }

    IdleMonitor {
        enabled: root.enabled && Theme.idleLockMinutes > 0
        timeout: Math.max(1, Theme.idleLockMinutes * 60)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lock()
    }

    IdleMonitor {
        enabled: Theme.sleepEnabled && Theme.idleSleepMinutes > 0
        timeout: Math.max(1, Theme.idleSleepMinutes * 60)
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) root.lockAndSuspend()
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function suspend(): void { root.lockAndSuspend() }
    }
}
