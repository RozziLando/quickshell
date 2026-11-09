import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.widgets

// Pagina Display: monitor collegati, modalità (estendi / duplica / solo uno)
// e accensione dei singoli schermi. Le modifiche passano da hyprctl e restano
// fino al prossimo riavvio o ricaricamento della config di Hyprland.
SubPage {
    id: page

    title: "Display"

    // In attesa di conferma il pannello non deve chiudersi
    readonly property bool busy: pendingRevert !== null

    // ---------- Stato dei monitor (hyprctl monitors all) ----------
    property var monitors: []

    Process {
        id: listProc
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.monitors = JSON.parse(text) } catch (e) {}
            }
        }
    }

    function refresh() { listProc.running = true }

    onVisibleChanged: if (visible) refresh()

    // Monitor collegati o scollegati: aggiorna
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name.indexOf("monitoradded") === 0
                || event.name.indexOf("monitorremoved") === 0)
                refreshLater.restart()
        }
    }

    // Hyprland applica le modifiche con un attimo di ritardo: rilegge due volte
    Timer {
        id: refreshLater
        interval: 400
        onTriggered: {
            page.refresh()
            refreshAgain.restart()
        }
    }
    Timer {
        id: refreshAgain
        interval: 1200
        onTriggered: page.refresh()
    }

    // ---------- Informazioni utili ----------
    function isInternal(m) {
        return /^(eDP|LVDS|DSI)/.test(m.name)
    }

    readonly property var internal: {
        for (var i = 0; i < monitors.length; i++)
            if (isInternal(monitors[i])) return monitors[i]
        return null
    }
    readonly property var externals: monitors.filter(function (m) { return !isInternal(m) })
    readonly property var primary: internal || (monitors.length > 0 ? monitors[0] : null)
    readonly property bool multi: monitors.length > 1

    function nameById(id) {
        for (var i = 0; i < monitors.length; i++)
            if (String(monitors[i].id) === String(id)) return monitors[i].name
        return String(id)
    }

    function mirrorOf(m) {
        var v = m.mirrorOf
        if (v === undefined || v === null || v === "none" || v === "") return ""
        return nameById(v)
    }

    function modeString(m) {
        return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2)
    }

    function label(m) {
        if (isInternal(m)) return "Built-in display"
        return m.description || m.name
    }

    function details(m) {
        if (m.disabled) return "Off"
        var mo = mirrorOf(m)
        if (mo !== "") return "Mirroring " + mo
        return m.width + "×" + m.height + " · " + Math.round(m.refreshRate) + " Hz · "
            + Math.round(m.scale * 100) + "%"
    }

    // Modalità attuale (per evidenziarla)
    readonly property string currentMode: {
        if (!multi) return ""
        for (var i = 0; i < monitors.length; i++)
            if (mirrorOf(monitors[i]) !== "") return "mirror"
        if (internal) {
            var extOn = externals.some(function (m) { return !m.disabled })
            if (internal.disabled && extOn) return "external"
            if (!internal.disabled && !extOn) return "internal"
        }
        return "extend"
    }

    // ---------- Applicazione delle impostazioni ----------
    // Ogni voce: { output, disabled } oppure
    // { output, mode, position, scale, transform, mirror }. La rotazione
    // (transform) va sempre indicata: con "keyword monitor" se manca si azzera
    function current(m) {
        if (m.disabled) return { output: m.name, disabled: true }
        return {
            output: m.name,
            mode: modeString(m),
            position: m.x + "x" + m.y,
            scale: String(m.scale),
            transform: m.transform || 0,
            mirror: mirrorOf(m)
        }
    }

    function on(m, position, mirror) {
        return {
            output: m.name,
            mode: m.disabled ? "preferred" : modeString(m),
            position: position,
            scale: m.disabled ? "auto" : String(m.scale),
            transform: m.transform || 0,
            mirror: mirror || ""
        }
    }

    function off(m) { return { output: m.name, disabled: true } }

    // Hyprland con config Lua (0.5x) usa hl.monitor; le versioni precedenti
    // "keyword monitor". Prima si accendono gli schermi, poi si spengono:
    // così non c'è mai un momento con tutti gli schermi spenti.
    function apply(specs) {
        specs = specs.filter(function (s) { return !s.disabled })
                     .concat(specs.filter(function (s) { return s.disabled }))
        var cmd
        if (Hyprland.usingLua) {
            cmd = ["hyprctl", "eval", specs.map(function (s) {
                if (s.disabled)
                    return 'hl.monitor({ output = "' + s.output + '", disabled = true })'
                // mirror va sempre indicato: se manca resta quello di prima
                return 'hl.monitor({ output = "' + s.output + '", mode = "' + s.mode
                    + '", position = "' + s.position + '", scale = "' + s.scale
                    + '", transform = ' + (s.transform || 0)
                    + ', mirror = "' + (s.mirror || "") + '", disabled = false })'
            }).join("\n")]
        } else {
            cmd = ["hyprctl", "--batch", specs.map(function (s) {
                if (s.disabled) return "keyword monitor " + s.output + ",disable"
                return "keyword monitor " + s.output + "," + s.mode + "," + s.position
                    + "," + s.scale + ",transform," + (s.transform || 0)
                    + (s.mirror ? ",mirror," + s.mirror : "")
            }).join(" ; ")]
        }
        Quickshell.execDetached(cmd)
        refreshLater.restart()
    }

    // Applica, ma ricorda com'era: se non confermi entro pochi secondi torna indietro
    property var pendingRevert: null
    property int countdown: 0
    // La richiesta di conferma sta in cima: se la pagina era scorsa in basso
    // (es. Apply dalla disposizione) non si vedrebbe e tutto tornerebbe
    // indietro da solo dopo 15 s
    onPendingRevertChanged: if (pendingRevert !== null) scrollToTop()

    function change(specs) {
        if (pendingRevert === null)
            pendingRevert = monitors.map(current)
        apply(specs)
        countdown = 15
        revertTimer.restart()
    }

    function keep() {
        revertTimer.stop()
        pendingRevert = null
    }

    function revert() {
        revertTimer.stop()
        if (pendingRevert !== null) apply(pendingRevert)
        pendingRevert = null
    }

    Timer {
        id: revertTimer
        interval: 1000
        repeat: true
        onTriggered: {
            page.countdown -= 1
            if (page.countdown <= 0) page.revert()
        }
    }

    // ---------- Modalità ----------
    // Larghezza "logica" (quella che occupa nel layout, scala compresa).
    // hyprctl dà la risoluzione non ruotata: ruotato di 90° o 270°
    // (transform dispari) in orizzontale occupa l'altezza
    function logicalWidth(m) {
        var w = m.transform % 2 === 1 ? m.height : m.width
        return w > 0 && m.scale > 0 ? Math.round(w / m.scale) : 0
    }

    // Affianca gli schermi da sinistra a destra. Le posizioni sono esplicite
    // perché "auto" impostato da Lua non li dispone affiancati. Quelli spenti
    // (larghezza ignota) vanno in fondo, così non si sovrappongono.
    function rowLayout(list) {
        var known = list.filter(function (m) { return !m.disabled && logicalWidth(m) > 0 })
        var unknown = list.filter(function (m) { return m.disabled || logicalWidth(m) === 0 })
        var x = 0
        return known.concat(unknown).map(function (m) {
            var spec = on(m, x + "x0")
            x += logicalWidth(m)
            return spec
        })
    }

    function setMode(mode) {
        var p = primary
        if (!p) return
        var others = monitors.filter(function (m) { return m.name !== p.name })
        var specs
        if (mode === "extend")
            specs = rowLayout([p].concat(others))
        else if (mode === "mirror")
            specs = [on(p, "0x0")].concat(others.map(function (m) { return on(m, "0x0", p.name) }))
        else if (mode === "external")
            specs = rowLayout(externals).concat(internal ? [off(internal)] : [])
        else if (mode === "internal")
            specs = [on(internal, "0x0")].concat(externals.map(off))
        if (specs) change(specs)
    }

    // Accende/spegne un singolo schermo (mai l'ultimo acceso)
    function toggle(m) {
        var enabled = monitors.filter(function (x) { return !x.disabled })
        if (!m.disabled) {
            if (enabled.length <= 1) return
            change([off(m)])
        } else {
            // A destra di quelli già accesi
            var right = 0
            enabled.forEach(function (x) { right = Math.max(right, x.x + logicalWidth(x)) })
            change([on(m, right + "x0")])
        }
    }

    // ---------- Contenuto ----------

    // Conferma dopo una modifica
    Rectangle {
        visible: page.pendingRevert !== null
        width: parent.width
        height: page.u(84)
        radius: page.u(22)
        color: Theme.card
        border.width: 1
        border.color: Theme.accent

        Column {
            anchors.centerIn: parent
            spacing: page.u(8)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Keep these display settings?"
                color: Theme.text
                font.pixelSize: page.u(11)
                font.bold: true
                font.family: Theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Reverting in " + page.countdown + "s"
                color: Theme.textSecondary
                font.pixelSize: page.u(9)
                font.family: Theme.fontFamily
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: page.u(8)

                Repeater {
                    model: [
                        { label: "Revert", keep: false },
                        { label: "Keep", keep: true }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: page.u(80)
                        height: page.u(24)
                        radius: height / 2
                        color: modelData.keep ? Theme.accent : Theme.highlight

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: parent.modelData.keep ? Theme.background : Theme.text
                            font.pixelSize: page.u(10)
                            font.bold: true
                            font.family: Theme.fontFamily
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: parent.modelData.keep ? page.keep() : page.revert()
                        }
                    }
                }
            }
        }
    }

    // Modalità (solo con più di uno schermo)
    SectionTitle {
        visible: page.multi
        sizeFactor: page.sizeFactor
        text: "Mode"
    }
    Grid {
        visible: page.multi
        width: parent.width
        columns: 2
        spacing: page.u(6)

        Repeater {
            model: {
                var list = [
                    { mode: "extend", label: "Extend", icon: "extend" },
                    { mode: "mirror", label: "Mirror", icon: "mirror" }
                ]
                if (page.internal && page.externals.length > 0) {
                    list.push({ mode: "internal", label: "Built-in only", icon: "laptop" })
                    list.push({ mode: "external", label: "External only", icon: "monitor" })
                }
                return list
            }

            delegate: Rectangle {
                id: modeCard
                required property var modelData
                readonly property bool current: page.currentMode === modelData.mode
                width: (parent.width - page.u(6)) / 2
                height: page.u(44)
                radius: page.u(22)
                color: current ? Theme.accent : (modeArea.containsMouse ? Theme.surface : Theme.card)
                border.width: 1
                border.color: current ? Theme.accent : Theme.cardBorder
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: page.u(8)

                    LineIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: modeCard.modelData.icon
                        size: page.u(18)
                        color: modeCard.current ? Theme.background : Theme.text
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modeCard.modelData.label
                        color: modeCard.current ? Theme.background : Theme.text
                        font.pixelSize: page.u(11)
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }

                MouseArea {
                    id: modeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (!modeCard.current) page.setMode(modeCard.modelData.mode)
                }
            }
        }
    }

    // Extend: disposizione grafica (rettangoli da trascinare)
    SectionTitle {
        visible: arrangement.visible
        sizeFactor: page.sizeFactor
        text: "Arrangement"
    }
    DisplayArrangement {
        id: arrangement
        visible: page.multi && page.currentMode === "extend"
        width: parent.width
        displayPage: page
        sizeFactor: page.sizeFactor
    }

    // Elenco degli schermi
    SectionTitle {
        sizeFactor: page.sizeFactor
        text: "Displays"
    }
    Repeater {
        model: page.monitors
        delegate: ListRow {
            required property var modelData
            sizeFactor: page.sizeFactor
            icon: page.isInternal(modelData) ? "laptop" : "monitor"
            title: page.label(modelData)
            subtitle: page.details(modelData)
            selected: !modelData.disabled
            // Click: accende/spegne (solo con più schermi)
            clickable: page.multi
            onClicked: page.toggle(modelData)
        }
    }

    Text {
        visible: !page.multi
        width: parent.width
        topPadding: page.u(8)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Connect another display to extend or mirror"
        color: Theme.textMuted
        font.pixelSize: page.u(10)
        font.family: Theme.fontFamily
    }
}
