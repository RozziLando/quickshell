import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.services
import qs.lock

ShellRoot {
    id: root

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
    property string pamNotice: ""
    property bool busy: false

    function login(password) {
        if (!Greetd.available) {
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
