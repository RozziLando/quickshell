import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "lock"
    title: "Login & Lock"
    description: "Login screen, lock screen, sleep and what happens when the computer is not used."

    readonly property var minuteSteps: [0, 1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120]

    function minutes(v) {
        v = Math.round(v)
        if (v <= 0) return "Never"
        if (v < 60) return v + " min"
        var h = Math.floor(v / 60), m = v % 60
        return h + " h" + (m > 0 ? " " + m + " min" : "")
    }

    readonly property string installer: Quickshell.shellPath("greeter/install.sh")
    readonly property string installCommand: "sudo " + SettingsUi.home(installer)

    property string greeterState: ""

    Process {
        id: greeterProc
        command: ["sh", "-c",
            'f=/etc/greetd/config.toml;'
            + ' [ -r "$f" ] || { echo missing; exit 0; };'
            + ' grep -q quickshell "$f" || { echo other; exit 0; };'
            + ' if grep -q "^\\[initial_session\\]" "$f"; then echo auto; else echo password; fi']
        stdout: StdioCollector {
            onStreamFinished: page.greeterState = text.trim()
        }
    }

    Timer {
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: page.visible
        onTriggered: if (!greeterProc.running) greeterProc.running = true
    }

    readonly property string greeterNote: {
        if (greeterState === "missing" || greeterState === "other")
            return "The login screen of the shell is not installed. To install it, run in a terminal:"
        if (greeterState === "auto" && Theme.loginScreen)
            return "Now the computer logs in automatically. To ask for the password, run in a terminal:"
        if (greeterState === "password" && !Theme.loginScreen)
            return "Now the login screen asks for the password. To log in automatically, run in a terminal:"
        return ""
    }

    property bool copied: false
    Timer {
        id: copiedTimer
        interval: 1600
        onTriggered: page.copied = false
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Login screen"
    }

    ToggleRow {
        title: "Login screen"
        info: "Ask for the password at boot. Off: the computer logs in automatically. The change needs the installer of the login screen to run again as root."
        key: "loginScreen"
        checked: Theme.loginScreen
        hasBelow: page.greeterNote !== ""

        below: Item {
            width: parent ? parent.width : 0
            height: noteColumn.implicitHeight

            Column {
                id: noteColumn
                width: parent.width
                spacing: SettingsUi.u(6)

                Text {
                    width: parent.width
                    text: page.greeterNote
                    color: Theme.textSecondary
                    font.pixelSize: SettingsUi.u(9)
                    font.family: Theme.fontFamily
                    wrapMode: Text.WordWrap
                }

                Rectangle {
                    width: parent.width
                    height: SettingsUi.u(30)
                    radius: SettingsUi.radius
                    color: Theme.track

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: SettingsUi.u(12)
                        anchors.right: copyButton.left
                        anchors.rightMargin: SettingsUi.u(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.installCommand
                        color: Theme.text
                        font.pixelSize: SettingsUi.u(9.5)
                        font.family: "monospace"
                        elide: Text.ElideMiddle
                    }

                    PillButton {
                        id: copyButton
                        anchors.right: parent.right
                        anchors.rightMargin: SettingsUi.u(3)
                        anchors.verticalCenter: parent.verticalCenter
                        height: SettingsUi.u(24)
                        icon: page.copied ? "check" : "copy"
                        text: page.copied ? "Copied" : "Copy"
                        onClicked: {
                            Quickshell.execDetached(["wl-copy", page.installCommand])
                            page.copied = true
                            copiedTimer.restart()
                        }
                    }
                }
            }
        }
    }

    ToggleRow {
        title: "Login blur"
        info: "Login screen background: the wallpaper blurred. Off: the plain wallpaper."
        key: "loginBlur"
        checked: Theme.loginBlur
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Lock screen"
    }

    ToggleRow {
        title: "Lock screen"
        info: "Lock the screen with the shortcut, after the inactivity time and before sleep. Off: the screen is never locked."
        key: "lockScreen"
        checked: Theme.lockScreen
    }

    ToggleRow {
        active: Theme.lockScreen
        title: "Lock blur"
        info: "Lock screen background: what was on the screen, blurred. Off: the plain wallpaper."
        key: "lockBlur"
        checked: Theme.lockBlur
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Sleep and inactivity"
    }

    ToggleRow {
        title: "Sleep"
        info: "Sleep in the power menu and after the inactivity time. Off: the computer never goes to sleep by itself."
        key: "sleepEnabled"
        checked: Theme.sleepEnabled
    }

    SliderRow {
        active: Theme.lockScreen
        title: "Lock after"
        info: "Lock the screen after this much time without using the computer. Needs the lock screen."
        values: page.minuteSteps
        value: Theme.idleLockMinutes
        format: function (v) { return page.minutes(v) }
        onCommitted: v => Settings.set("idleLockMinutes", v)
    }

    SliderRow {
        active: Theme.sleepEnabled
        title: "Sleep after"
        info: "Put the computer to sleep after this much time without using it. Needs sleep."
        values: page.minuteSteps
        value: Theme.idleSleepMinutes
        format: function (v) { return page.minutes(v) }
        onCommitted: v => Settings.set("idleSleepMinutes", v)
    }
}
