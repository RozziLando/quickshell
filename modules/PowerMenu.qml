import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "power"
    property var lock: null
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int circleSize: u(48)
    readonly property int gap: u(16)
    readonly property int edgePad: u(14)
    readonly property int openWidth: 2 * sidePad + actions.length * circleSize
                                     + (actions.length - 1) * gap
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int topPad: edgePad
    readonly property int bottomPad: edgePad
    readonly property int panelRadius: circleSize / 2 + edgePad
    readonly property int openHeight: topPad + circleSize + bottomPad

    readonly property var actions: (Theme.sleepEnabled ? [
        { id: "sleep",    label: "Sleep",     icon: "sleep",  confirm: false }
    ] : []).concat(Theme.lockScreen ? [
        { id: "lock",     label: "Lock",      icon: "lock",   confirm: false }
    ] : []).concat([
        { id: "reboot",   label: "Reboot",    icon: "reboot", confirm: true },
        { id: "poweroff", label: "Power off", icon: "power",  confirm: true }
    ])

    function run(id) {
        close()
        if (id === "sleep") {
            if (lock) lock.lockAndSuspend()
        } else if (id === "lock") {
            if (lock) lock.lock()
        } else if (id === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"])
        } else if (id === "poweroff") {
            Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }

    property string armed: ""

    function activate(index) {
        var a = actions[index]
        if (!a) return
        if (a.confirm && armed !== a.id) {
            armed = a.id
            disarmTimer.restart()
            return
        }
        run(a.id)
    }

    Timer {
        id: disarmTimer
        interval: 4000
        onTriggered: root.armed = ""
    }

    property int selected: -1

    function open() {
        armed = ""
        selected = -1
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
        island.grabOwner = ownerId
        focusTimer.restart()
    }

    function close() {
        armed = ""
        island.close(ownerId)
    }

    function toggle() {
        if (shown) close()
        else open()
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.toggle() }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: keys.forceActiveFocus()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: root.shown

        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.selected = root.selected <= 0 ? root.actions.length - 1 : root.selected - 1
        Keys.onRightPressed: root.selected = (root.selected + 1) % root.actions.length
        Keys.onTabPressed: root.selected = (root.selected + 1) % root.actions.length
        Keys.onBacktabPressed: root.selected = root.selected <= 0 ? root.actions.length - 1 : root.selected - 1
        Keys.onReturnPressed: root.activate(root.selected)
        Keys.onEnterPressed: root.activate(root.selected)

        visible: root.shown
        FadeIn { active: root.shown; pause: 160; duration: 220 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.topPad
            spacing: root.gap

            Repeater {
                model: root.actions

                delegate: Column {
                    id: action
                    required property var modelData
                    required property int index
                    readonly property bool isArmed: root.armed === modelData.id
                    onIsArmedChanged: if (!isArmed) button.opacity = 1
                    width: root.circleSize
                    spacing: root.u(8)

                    CircleButton {
                        id: button
                        anchors.horizontalCenter: parent.horizontalCenter
                        kind: action.isArmed ? "check" : action.modelData.icon
                        size: root.circleSize
                        readonly property bool chosen: root.selected === action.index
                        active: true
                        activeColor: action.isArmed ? Theme.warning
                                   : chosen ? Theme.accent : Theme.highlight
                        iconColor: action.isArmed || chosen ? Theme.background : Theme.text
                        border.width: 0
                        onHoveredChanged: {
                            if (hovered) root.selected = action.index
                            else if (root.selected === action.index) root.selected = -1
                        }
                        onClicked: root.activate(action.index)

                        opacity: 1
                        SequentialAnimation on opacity {
                            running: action.isArmed
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.55; duration: 450; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }
}
