import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "lock"
    title: "Login & Lock"
    description: "Login, lock, sleep and idle."

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
            return "Not installed, your login manager is in use. To install it, run:"
        if (greeterState === "auto" && Theme.loginScreen)
            return "Now it logs in automatically. To ask for the password, run:"
        if (greeterState === "password" && !Theme.loginScreen)
            return "Now it asks for the password. To log in automatically, run:"
        if (greeterState === "")
            return ""
        return "Installed. To apply the current settings, run:"
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
        info: "Ask for the password at boot. Off: automatic login. Applied by the installer below."
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
        info: "Blur the wallpaper behind the login."
        key: "loginBlur"
        checked: Theme.loginBlur
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Lock screen"
    }

    ToggleRow {
        title: "Lock screen"
        info: "Lock with the shortcut, when idle and before sleep."
        key: "lockScreen"
        checked: Theme.lockScreen
    }

    ToggleRow {
        active: Theme.lockScreen
        title: "Lock blur"
        info: "Blur the screen behind the lock. Off: the wallpaper."
        key: "lockBlur"
        checked: Theme.lockBlur
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Sleep and inactivity"
    }

    ToggleRow {
        title: "Sleep"
        info: "Sleep from the power menu and when idle."
        key: "sleepEnabled"
        checked: Theme.sleepEnabled
    }

    SliderRow {
        active: Theme.lockScreen
        title: "Lock after"
        info: "Idle time before locking."
        values: page.minuteSteps
        value: Theme.idleLockMinutes
        format: function (v) { return page.minutes(v) }
        onCommitted: v => Settings.set("idleLockMinutes", v)
    }

    SliderRow {
        active: Theme.sleepEnabled
        title: "Sleep after"
        info: "Idle time before sleeping."
        values: page.minuteSteps
        value: Theme.idleSleepMinutes
        format: function (v) { return page.minutes(v) }
        onCommitted: v => Settings.set("idleSleepMinutes", v)
    }
}
