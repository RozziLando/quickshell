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
    property var mainView: null
    function fail(message) { if (mainView) mainView.fail(message) }

    readonly property string mainScreenName: {
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (Theme.monitor !== "" && list[i].name === Theme.monitor) return list[i].name
        for (i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i].name
        return list.length > 0 ? list[0].name : ""
    }
    property string pamNotice: ""
    property bool busy: false

    function login(password) {
        if (!Greetd.available) {
            root.fail("Preview: greetd not running")
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
            root.fail(root.pamNotice !== "" ? root.pamNotice : "Incorrect password")
        }
        function onError(error) {
            root.busy = false
            root.pendingPassword = ""
            Greetd.cancelSession()
            root.fail(error)
        }
        function onReadyToLaunch() {
            fadeOut.start()
        }
    }

    FloatingWindow {
        id: win
        visible: true
        color: "black"
        implicitWidth: 1280
        implicitHeight: 800

        readonly property var screenList: Quickshell.screens
        readonly property real layoutX: screenList.length > 0 ? Math.min.apply(null, screenList.map(function (sc) { return sc.x })) : 0
        readonly property real layoutY: screenList.length > 0 ? Math.min.apply(null, screenList.map(function (sc) { return sc.y })) : 0
        readonly property real layoutW: screenList.length > 0 ? Math.max.apply(null, screenList.map(function (sc) { return sc.x + sc.width })) - layoutX : 0
        readonly property real layoutH: screenList.length > 0 ? Math.max.apply(null, screenList.map(function (sc) { return sc.y + sc.height })) - layoutY : 0
        readonly property bool spanning: screenList.length > 1
            && Math.abs(width - layoutW) <= 2 && Math.abs(height - layoutH) <= 2

        Repeater {
            model: win.spanning ? win.screenList : [null]

            delegate: Item {
                id: area
                required property var modelData
                readonly property bool isMain: !modelData || modelData.name === root.mainScreenName
                x: modelData ? modelData.x - win.layoutX : 0
                y: modelData ? modelData.y - win.layoutY : 0
                width: modelData ? modelData.width : win.width
                height: modelData ? modelData.height : win.height

                LoginView {
                    id: areaView
                    anchors.fill: parent
                    showLogin: area.isMain
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
                    Component.onCompleted: if (area.isMain) root.mainView = areaView
                }
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
