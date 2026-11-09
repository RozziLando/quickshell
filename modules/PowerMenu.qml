import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

// Menu di spegnimento: Sleep, Lock, Reboot, Power off.
// Si apre dal pulsante power del centro di controllo o con
// "qs ipc call power toggle"; si chiude uscendo col mouse o con Esc.
Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "power"
    // Blocco schermo (lock/Lock.qml), passato da shell.qml
    property var lock: null
    readonly property bool shown: island.owner === ownerId

    // Stessa scala del centro di controllo (sizeFactor in ControlCenter.qml)
    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    // Cerchi grandi come quelli del centro di controllo (circleSize = u(48))
    readonly property int circleSize: u(48)
    // Pulsanti distanti tra loro come i cerchi del centro di controllo
    // (gap = u(10)); la finestra si adatta a quanti sono (4, o 2 senza blocco)
    // con lo stesso spazio dal bordo su tutti i lati (edgePad, come lì)
    readonly property int gap: u(16)   // un po' più distanti dei cerchi del centro di controllo (u(10))
    readonly property int edgePad: u(14)
    readonly property int openWidth: 2 * sidePad + actions.length * circleSize
                                     + (actions.length - 1) * gap
    readonly property int sidePad: edgePad + island.topRadius   // + parte trasparente
    readonly property int topPad: edgePad
    readonly property int bottomPad: edgePad
    // Angoli concentrici con i cerchi: raggio del cerchio + margine
    readonly property int panelRadius: circleSize / 2 + edgePad
    // Solo icone: margine sopra + cerchio + margine sotto. Reboot e Power off
    // chiedono conferma: al primo click il cerchio si colora d'accento
    readonly property int openHeight: topPad + circleSize + bottomPad

    // ---------- Azioni ----------
    // Reboot e Power off usano systemd (presente su Arch, Fedora, ecc.)
    // Sleep solo con "sleepEnabled", Lock solo con "lockScreen" (theme.json);
    // Reboot e Power off ci sono sempre
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
            // Blocca e poi sospende (lock/Lock.qml)
            if (lock) lock.lockAndSuspend()
        } else if (id === "lock") {
            if (lock) lock.lock()
        } else if (id === "reboot") {
            Quickshell.execDetached(["systemctl", "reboot"])
        } else if (id === "poweroff") {
            Quickshell.execDetached(["systemctl", "poweroff"])
        }
    }

    // Reboot e Power off chiedono conferma: primo click "arma", secondo esegue
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

    // ---------- Apertura / chiusura ----------
    property int selected: -1   // pulsante scelto con le frecce

    function open() {
        armed = ""
        selected = -1
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
        // Si chiude solo cliccando fuori (focus grab dell'isola) o con Esc
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

    // La tastiera arriva dopo che il compositor ha dato il focus
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: keys.forceActiveFocus()
    }

    // ---------- Interfaccia ----------
    Item {
        id: keys
        anchors.fill: parent
        focus: root.shown

        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.selected = root.selected <= 0 ? root.actions.length - 1 : root.selected - 1
        Keys.onRightPressed: root.selected = (root.selected + 1) % root.actions.length
        // Tab / Shift+Tab come le frecce
        Keys.onTabPressed: root.selected = (root.selected + 1) % root.actions.length
        Keys.onBacktabPressed: root.selected = root.selected <= 0 ? root.actions.length - 1 : root.selected - 1
        Keys.onReturnPressed: root.activate(root.selected)
        Keys.onEnterPressed: root.activate(root.selected)

        // Si nasconde di colpo, compare in dissolvenza (come gli altri moduli)
        visible: root.shown
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
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
                    // La pulsazione si ferma dove si trova: senza questo il
                    // cerchio restava semitrasparente (anche alla riapertura)
                    onIsArmedChanged: if (!isArmed) button.opacity = 1
                    width: root.circleSize
                    spacing: root.u(8)

                    CircleButton {
                        id: button
                        anchors.horizontalCenter: parent.horizontalCenter
                        // In attesa di conferma: spunta al posto dell'icona,
                        // "clicca di nuovo"
                        kind: action.isArmed ? "check" : action.modelData.icon
                        size: root.circleSize
                        // Come i cerchi di Wi-Fi / Bluetooth spenti; d'accento
                        // quando sono scelti (Tab, frecce, mouse). In attesa di
                        // conferma (Reboot, Power off) del colore di avviso
                        readonly property bool chosen: root.selected === action.index
                        active: true
                        activeColor: action.isArmed ? Theme.warning
                                   : chosen ? Theme.accent : Theme.highlight
                        iconColor: action.isArmed || chosen ? Theme.background : Theme.text
                        border.width: 0
                        // Il mouse sceglie come la tastiera; uscendo si deseleziona
                        onHoveredChanged: {
                            if (hovered) root.selected = action.index
                            else if (root.selected === action.index) root.selected = -1
                        }
                        onClicked: root.activate(action.index)

                        // In attesa di conferma pulsa piano
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
