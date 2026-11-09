import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import qs.services

// Blocco schermo (ext-session-lock): sfondo attuale sfocato, ora grande,
// password in basso (LoginView, la stessa del login con greetd).
//
//   qs ipc call lock lock      blocca
//   qs ipc call lock suspend   blocca e sospende
//
// Sospensione da qualunque parte (menu, coperchio, systemctl suspend): la
// shell tiene un "delay inhibitor" di logind, così prima di dormire blocca
// lo schermo e mette in pausa i media, poi lascia andare il sistema.
// Il modo di sospensione (deep / s2idle) lo sceglie il kernel in base a
// firmware e processore (Intel, AMD, ARM): qui non si forza nulla.
Scope {
    id: root

    readonly property bool locked: sessionLock.locked
    readonly property string userName: Quickshell.env("USER") || ""

    // Sfondo del blocco:
    //  - "lockBlur": true  -> foto di quello che c'è sullo schermo al momento
    //    del blocco (finestre comprese), sfocata da LoginView
    //  - "lockBlur": false -> lo sfondo attuale (awww/swww), nitido
    // Il login invece mostra sempre lo sfondo (non c'è un desktop da fotografare)
    property string wallpaperPath: ""
    // Schermi di cui c'è la foto: gli altri (foto fallita, schermo
    // collegato a blocco già attivo) mostrano lo sfondo, non il nero
    property var shotScreens: []
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    function shotPath(screenName) { return shotDir + "/qs-lock-" + screenName + ".jpg" }

    // ---------- Blocco ----------
    property bool suspendAfterLock: false

    // "lockScreen": false in theme.json -> niente blocco (es. autologin)
    readonly property bool enabled: Theme.lockScreen

    function lock() {
        if (!enabled || sessionLock.locked || capture.running) return
        errorText = ""
        GreeterSync.sync()          // il login avrà lo stesso sfondo
        shotScreens = []
        // $1 = script dello sfondo (awww/swww/swaybg), $2 = 1 se va
        // fotografato lo schermo, poi i nomi degli schermi
        capture.command = ["sh", "-c",
            'sh "$1" get; shift;'
            + ' if [ "$1" = 1 ]; then shift;'
            // JPEG: veloce anche con schermate piene di dettagli (il PNG con
            // una pagina web può superare il secondo); tanto viene sfocata
            // "SHOT <schermo>" per ogni foto riuscita
            + '  for o in "$@"; do grim -t jpeg -q 85 -o "$o" "' + shotDir + '/qs-lock-$o.jpg" 2>/dev/null && echo "SHOT $o"; done;'
            + ' fi',
            "sh", Quickshell.shellPath("scripts/wallpaper.sh"), Theme.lockBlur ? "1" : "0"]
            .concat(Quickshell.screens.map(function (sc) { return sc.name }))
        capture.running = true
        captureTimeout.restart()
    }

    function lockAndSuspend() {
        // Senza blocco: sospende e basta
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
                // Arrivata dopo il blocco di sicurezza (timeout): resta lo
                // sfondo, niente cambio sotto gli occhi
                if (!sessionLock.locked)
                    root.shotScreens = lines.filter(function (l) { return l.indexOf("SHOT ") === 0 })
                                            .map(function (l) { return l.substring(5) })
                // Si blocca solo ora, con lo sfondo giusto già deciso: prima
                // si vedeva un attimo lo sfondo e poi la foto dello schermo
                root.engage()
            }
        }
    }

    // Se la lettura tarda si blocca comunque (sicurezza prima di tutto)
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

    // ---------- Sblocco (PAM) ----------
    property string errorText: ""
    property string pendingPassword: ""
    // Avvisi di PAM durante il tentativo (es. pam_faillock: "The account is
    // locked due to 3 failed logins." "(10 minutes left to unlock)"): se
    // l'accesso fallisce si mostrano al posto di "Incorrect password", che
    // con l'account bloccato sarebbe fuorviante. Arrivano come semplici
    // informazioni (non errori) e poi PAM chiede comunque la password
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
        // Stessa catena di autenticazione del login della distro
        config: "login"
        user: root.userName

        onMessageChanged: if (message !== "") root.pamNotices = root.pamNotices.concat([message])

        onResponseRequiredChanged: {
            if (responseRequired) {
                // L'ultimo messaggio è la domanda ("Password: "), non un avviso
                var n = root.pamNotices
                if (n.length > 0 && n[n.length - 1] === message) root.pamNotices = n.slice(0, -1)
                respond(root.pendingPassword)
                root.pendingPassword = ""
            }
        }
        onCompleted: result => {
            // Rifiutata senza chiedere la password (es. account bloccato):
            // non resta in memoria
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

    // Foto dell'utente che esiste davvero (assets/avatar.png, .jpg o .jpeg),
    // cercata a ogni blocco: provarle tutte lasciava avvisi nel log
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

        // Bloccato e confermato dal compositor
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
                // Foto dell'utente: assets/avatar.png (o .jpg) nella cartella di Quickshell
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

    // ---------- Sospensione (logind) ----------
    // Delay inhibitor: logind aspetta (max ~5 s) che lo rilasciamo prima di
    // sospendere. "cat" resta aperto finché la Process è attiva.
    property bool sleepPending: false
    // "lockScreen" cambiato in theme.json: l'inhibitor segue (le righe sotto
    // lo accendono e spengono a mano, e il collegamento automatico si perde)
    onEnabledChanged: if (!sleepPending) inhibitor.running = enabled

    Process {
        id: inhibitor
        // Serve solo a bloccare prima di dormire: senza blocco non c'è
        running: root.enabled
        stdinEnabled: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay",
                  "--who=Quickshell", "--why=Lock the screen before sleep", "cat"]
    }

    function prepareForSleep(start) {
        if (start) {
            sleepPending = true
            // Pausa a tutti i player
            Mpris.players.values.forEach(function (p) { if (p.canPause && p.isPlaying) p.pause() })
            if (sessionLock.secure || !root.enabled) inhibitor.running = false
            else lock()
        } else {
            // Risveglio: si riprende l'inhibitor per la prossima volta
            sleepPending = false
            inhibitor.running = root.enabled
        }
    }

    // Percorso D-Bus della nostra sessione: logind codifica l'ID come
    // sd_bus_path_encode ("3" -> "_33": cifra iniziale e simboli in esadecimale)
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
    // "loginctl lock-session" di un'altra sessione (altro utente, altro TTY)
    // non deve bloccare questa. ID sconosciuto: si accetta ogni segnale
    function isOurSession(line) {
        return sessionPath === "" || line.indexOf(sessionPath + ":") >= 0
    }

    // Segnali di logind: PrepareForSleep (sospensione) e Lock
    // (loginctl lock-session). gdbus fa parte di glib2, su ogni distro.
    Process {
        id: logindWatch
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep (true") >= 0) root.prepareForSleep(true)
                // Spegnimento/riavvio: il login prende l'ultimo sfondo
                else if (line.indexOf("PrepareForShutdown (true") >= 0) GreeterSync.syncNow()
                else if (line.indexOf("PrepareForSleep (false") >= 0) root.prepareForSleep(false)
                else if (line.indexOf(".Session.Lock ") >= 0 && root.isOurSession(line)) root.lock()
            }
        }
        // Se si interrompe riparte
        onRunningChanged: if (!running) watchRestart.restart()
    }
    Timer {
        id: watchRestart
        interval: 3000
        onTriggered: logindWatch.running = true
    }

    // ---------- Inattività ----------
    // Dopo "idleLockMinutes" senza usare il computer blocca, dopo
    // "idleSleepMinutes" sospende (theme.json; 0 = mai). Protocollo standard
    // di Wayland: rispetta chi tiene sveglio lo schermo (es. un video).
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
