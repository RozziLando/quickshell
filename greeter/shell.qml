// Login con greetd: stessa schermata del blocco schermo (lock/LoginView.qml).
// Non si avvia da qui: install.sh la copia in /etc/greetd/quickshell insieme
// ai file che usa, e greetd la lancia dentro cage.
// Senza greetd (anteprima) mostra la schermata senza accedere davvero.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.services
import qs.lock

ShellRoot {
    id: root

    // Impostazioni scritte da install.sh: utente e sessione da avviare
    FileView {
        id: configFile
        path: Quickshell.shellPath("greeter.json")
        blockLoading: true
        adapter: JsonAdapter {
            id: config
            property string user: ""
            property var session: ["start-hyprland"]
        }
    }

    property string pendingPassword: ""
    // Avvisi di PAM (es. pam_faillock: "The account is locked due to 3 failed
    // logins." "(10 minutes left to unlock)"): arrivano come informazioni,
    // non errori, e se l'accesso fallisce si mostrano al posto di
    // "Incorrect password"
    property string pamNotice: ""
    property bool busy: false

    function login(password) {
        if (!Greetd.available) {
            // Anteprima: nessun accesso vero
            view.fail("Preview: greetd not running")
            return
        }
        pamNotice = ""
        pendingPassword = password
        busy = true
        Greetd.createSession(config.user)
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (!responseRequired && message !== "")
                root.pamNotice = root.pamNotice !== "" ? root.pamNotice + " " + message : message
            if (responseRequired) {
                Greetd.respond(root.pendingPassword)
                root.pendingPassword = ""
            }
        }
        function onAuthFailure(message) {
            root.busy = false
            root.pendingPassword = ""
            Greetd.cancelSession()
            view.fail(root.pamNotice !== "" ? root.pamNotice : "Incorrect password")
        }
        function onError(error) {
            root.busy = false
            root.pendingPassword = ""
            Greetd.cancelSession()
            view.fail(error)
        }
        // Password giusta: dissolvenza al nero, poi parte la sessione
        // (session.sh pulisce la console: si passa dal nero a Hyprland)
        function onReadyToLaunch() {
            fadeOut.start()
        }
    }

    FloatingWindow {
        visible: true
        color: "black"
        implicitWidth: 1280
        implicitHeight: 800

        LoginView {
            id: view
            anchors.fill: parent
            backgroundSource: Qt.resolvedUrl(Quickshell.shellPath("wallpaper"))
            userName: config.user
            // Copiata da assets/avatar.* (greeter/sync.sh)
            avatarSources: ["file://" + Quickshell.shellPath("avatar")]
            busy: root.busy
            showPower: true
            blurred: Theme.loginBlur
            onSubmitted: password => root.login(password)
            onPowerAction: action => {
                if (action === "sleep") Quickshell.execDetached(["systemctl", "suspend"])
                else if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
                else if (action === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
            }
        }

        // Velo nero per la dissolvenza d'uscita
        Rectangle {
            id: veil
            anchors.fill: parent
            color: "black"
            opacity: 0
        }

        SequentialAnimation {
            id: fadeOut
            NumberAnimation { target: veil; property: "opacity"; to: 1; duration: 450; easing.type: Easing.InOutQuad }
            ScriptAction { script: Greetd.launch(config.session, ["XDG_SESSION_TYPE=wayland"]) }
        }
    }
}
