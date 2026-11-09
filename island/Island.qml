import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

PanelWindow {
    id: win
    // "monitor" in theme.json (es. "HDMI-A-1") se è collegato; altrimenti
    // lo schermo del portatile se c'è (eDP/LVDS/DSI), altrimenti il primo
    // collegato (Quickshell non ha un concetto di "primario")
    function pickScreen() {
        var list = Quickshell.screens
        var wanted = Theme.monitor
        if (wanted !== "")
            for (var j = 0; j < list.length; j++)
                if (list[j].name === wanted) return list[j]
        for (var i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i]
        return list.length > 0 ? list[0] : null
    }
    // Schermo scelto: calcolato alla creazione, poi cambiato solo da
    // checkScreen() a finestra nascosta, mai da un binding. Quando la shell
    // si ricarica Quickshell riusa la finestra vecchia per l'isola nuova:
    // se nel frattempo lo schermo cambia (QWindow::setScreen su una finestra
    // riusata o in distruzione) Quickshell crasha. Per questo Theme.monitor
    // è già giusto alla creazione (vedi Theme.qml)
    property var preferredScreen: pickScreen()
    screen: preferredScreen
    // Al ricaricamento la finestra vecchia viene riusata solo se è sullo
    // stesso schermo; altrimenti se ne crea una nuova (niente setScreen
    // su una finestra riusata, vedi sopra)
    reloadableId: "island-" + (preferredScreen ? preferredScreen.name : "none")
    anchors.top: true

    // Schermi cambiati (monitor scollegato, schermo spento da "External
    // only"): se lo schermo dell'isola sparisce la finestra si chiude e non
    // torna da sola, nemmeno quando lo schermo riappare. Nascondendola e
    // rimostrandola viene ricreata sullo schermo giusto. Solo se serve: un
    // monitor collegato in più (o il mirror) non tocca l'isola
    property bool remapping: false
    visible: !remapping
    property var lastScreen: null   // impostato all'avvio (Component.onCompleted)
    Connections {
        target: Quickshell
        function onScreensChanged() { screenCheck.restart() }
    }
    // "monitor" cambiato in theme.json: l'isola si sposta subito
    Connections {
        target: Theme
        function onMonitorChanged() { screenCheck.restart() }
    }
    // Il controllo parte un attimo dopo, non dentro il segnale: mentre la
    // shell si ricarica Theme e gli schermi della vecchia config cambiano
    // mentre questa finestra viene distrutta; il timer muore con lei e non
    // scatta, così non si cambia schermo a una finestra morente (crash)
    Timer {
        id: screenCheck
        interval: 50
        onTriggered: win.checkScreen()
    }
    function checkScreen() {
        var list = Quickshell.screens, present = false
        for (var i = 0; i < list.length; i++)
            if (list[i] === win.lastScreen) present = true
        var next = pickScreen()
        var moved = !present || next !== win.lastScreen
        win.lastScreen = next
        if (!moved) return
        // Quello che è aperto resta aperto (es. la conferma della pagina
        // Display dopo "External only"): non è un click fuori
        remapGuard.restart()
        win.grabReady = false
        // Lo schermo cambia solo a finestra nascosta, poi la si rimostra
        win.remapping = true
        win.preferredScreen = next
        Qt.callLater(function () { win.remapping = false })
    }
    Timer {
        id: remapGuard
        interval: 800
    }

    // Tutto ciò che metti dentro <Island> finisce nella pillola
    default property alias content: contentHost.data

    // ---- Dimensioni (scalate) ----
    // Staccata: orologio più corto (la parte visibile è idleW - 2 * topRadius)
    // Attaccata: più larga, con audio e batteria ai lati dell'orologio
    // Minimal: a riposo solo l'orologio (attaccata stretta come la staccata);
    // passandoci sopra si allarga per mostrare le icone.
    // Attaccata minimal a riposo: 150 come la prima versione dell'isola
    readonly property int idleW: floating ? Theme.s(112)
        : minimal && !revealed ? Theme.s(150) : Theme.s(172)
    readonly property int idleH: Theme.s(30)
    readonly property int maxW: Theme.s(800)   // finestra = massimo espandibile
    readonly property int maxH: Theme.s(480)

    // ---- Stile: pillola staccata (floating) o attaccata al bordo ----
    // Si cambia con "islandStyle" in theme.json ("floating" / "attached")
    readonly property bool floating: Theme.floatingIsland

    // ---- Minimal ("minimal" in theme.json) ----
    // A riposo si vede solo l'orologio. Passandoci sopra compaiono le icone
    // (cerchi ai lati o dentro la pillola), cliccabili; il centro di
    // controllo si apre cliccando sull'orario, non più con l'hover.
    readonly property bool minimal: Theme.minimalIsland
    // Il mouse è sull'orologio o vicino ai cerchi
    readonly property bool pointerNear: hoverHandler.hovered || leftNear.hovered || rightNear.hovered
    // Dopo aver aperto qualcosa le icone non ricompaiono finché il mouse non
    // esce: chiudendo si torna sempre dritti all'orologio
    property bool revealBlocked: false
    onPointerNearChanged: {
        if (!pointerNear && owner === "") revealBlocked = false
        // autoHide: uscendo dall'isola scesa dal bordo, torna su
        if (pointerNear) peekEnd.stop()
        else if (peek) peekEnd.restart()
    }
    readonly property bool revealWanted: minimal && owner === "" && !concealed
        && pointerNear && !revealBlocked
    // Icone visibili; restano un attimo dopo l'uscita per poterle raggiungere
    property bool revealed: false
    onRevealWantedChanged: {
        if (revealWanted) {
            hideIcons.stop()
            revealed = true
        } else {
            hideIcons.restart()
        }
    }
    Timer {
        id: hideIcons
        interval: 350
        onTriggered: win.revealed = false
    }
    // Icone ai lati / nella pillola visibili?
    readonly property bool iconsShown: !minimal || revealed

    // Click sull'orario (minimal): apre il centro di controllo
    signal clockClicked()
    readonly property int topGap: floating ? Theme.s(5) : 0   // distanza dal bordo alto

    // ---- Quadratini "volanti" ai lati dell'orologio ----
    readonly property int topRadius: Theme.s(10)     // raccordo pillola-bordo schermo
    // Lato del quadratino; staccata: cerchi poco più bassi dell'orologio
    readonly property int sideSize: floating ? idleH - Theme.s(4) : Theme.s(28)
    // Staccata: icone più piccole rispetto al cerchio
    readonly property real sideIconScale: floating ? 0.82 : 1
    readonly property int sideGap: Theme.s(11)       // spazio dal corpo della pillola
    // Reazione al mouse: entro sideReach dal quadratino si sposta verso il
    // cursore, al massimo di sideShift
    readonly property int sideReach: Theme.s(28)
    readonly property int sideShift: Theme.s(4)
    // La zona scende di poco sotto la striscia riservata, così non ruba i
    // click alle finestre (che iniziano dopo gaps_out di Hyprland)
    readonly property int sideZoneH: topGap + idleH + Theme.s(6)
    // Solo nell'isola staccata; sempre visibili (seguono la pillola quando
    // si allarga), tranne in fullscreen
    readonly property bool sidesShown: floating && !concealed && iconsShown && appeared

    // ---- Comparsa all'avvio ----
    // Appena partita la shell, la finestra non è ancora centrata da Hyprland
    // (per un attimo si vedrebbe l'isola spostata a sinistra): l'isola resta
    // sopra lo schermo e scende quando la finestra è già al suo posto
    property bool appeared: false
    // true solo durante la prima discesa (animazione con rimbalzo)
    property bool startupDrop: false
    Timer {
        interval: 450
        running: true
        onTriggered: {
            win.startupDrop = true
            win.appeared = true
            dropDone.start()
        }
    }
    Timer {
        id: dropDone
        interval: 500
        onTriggered: win.startupDrop = false
    }

    // ---- Click sui cerchi: il modulo si apre al centro (vedi shell.qml) ----
    signal leftClicked()
    signal rightClicked()


    // ---- Stato ----
    property string owner: ""
    property int requestW: 0
    property int requestH: 0
    property bool wantsKeyboard: false
    property bool fullscreen

    // Nascosta: fullscreen, oppure "autoHide" con finestre sul desktop
    // (tranne mentre la si fa scendere dal bordo alto: peek)
    readonly property bool concealed: fullscreen || (autoHidden && !peek)
    // Zona al centro del bordo alto che apre il centro di controllo: attiva
    // finché ci sono fullscreen o finestre, anche con l'isola scesa.
    // Minimal con autoHide no: lì si apre cliccando l'orario, quindi anche
    // il centro del bordo fa solo scendere l'isola (EdgeReveal)
    readonly property bool hotspotActive: fullscreen || (autoHidden && !minimal)

    // A riposo e nascosta: la pillola è ritirata al bordo dello schermo
    readonly property bool hiddenMode: concealed && owner === ""

    // Dimensioni di destinazione della pillola
    readonly property int targetW: owner === "" ? idleW : Math.min(requestW, maxW)
    readonly property int targetH: owner === ""
        ? (hiddenMode && !floating ? 0 : idleH)
        : Math.min(requestH, maxH)

    // Il mouse è sulla pillola oppure sulla striscia in alto (fullscreen)?
    property bool hovered: hoverHandler.hovered || (hotspotActive && hotspotHover.hovered)

    // Hover che apre il centro di controllo. Staccata: tutta la pillola.
    // Attaccata: l'orologio o il bordo alto dello schermo, non le icone ai
    // lati (così si possono cliccare senza aprirlo)
    readonly property int edgeH: Math.max(3, Theme.s(4))
    readonly property bool edgeHovered: edgeHover.hovered || (hotspotActive && hotspotHover.hovered)
    // Minimal: mai con l'hover (si apre cliccando sull'orario)
    readonly property bool openHovered: minimal ? false
        : floating ? hovered : (edgeHovered || clockHover.hovered)
    // Attaccata: distanza delle icone dal corpo della pillola
    readonly property int inlineIconPad: Theme.s(8)

    // ---- Raggio degli angoli dell'isola aperta ----
    // Ogni modulo può chiedere il suo (ultimo argomento di open): angoli
    // concentrici con i riquadri interni = raggio interno + margine
    readonly property int defaultRadius: Theme.s(15)
    property int requestRadius: 0
    readonly property int cornerRadius: owner !== "" && requestRadius > 0 ? requestRadius : defaultRadius

    // ---- API per i moduli ----
    // radius: facoltativo; se manca resta quello già chiesto dallo stesso modulo
    function open(id, w, h, keyboard, radius) {
        var isNew = owner !== id
        owner = id
        requestW = w
        requestH = h
        wantsKeyboard = keyboard === true
        if (radius !== undefined) requestRadius = radius
        else if (isNew) requestRadius = 0
        // Esc chiude qualsiasi modulo; quelli con un proprio campo (launcher,
        // centro di controllo, menu) si prendono il focus subito dopo.
        // Solo per un modulo nuovo: un ridimensionamento non tocca il focus
        if (isNew) escCatcher.forceActiveFocus()
    }

    function close(id) {
        if (owner !== id) return    // chiude solo chi l'ha aperta
        owner = ""
        wantsKeyboard = false
    }

    implicitWidth: maxW
    implicitHeight: maxH
    color: "transparent"
    // Riserva solo lo spazio dell'orologio. Con "autoHide" niente (l'isola
    // si nasconde quando ci sono finestre, la striscia resterebbe vuota),
    // tranne quando la si fa scendere dal bordo: le finestre le fanno spazio.
    // Nascosta (concealed) mai: Hyprland conta come fullscreen anche le
    // finestre massimizzate, che però rispettano lo spazio riservato e
    // lascerebbero un buco in alto al posto dell'isola
    readonly property int reservedHeight: topGap + idleH
    exclusiveZone: !concealed && (!autoHide || peek) ? reservedHeight : 0

    // Cattura il mouse la pillola; in fullscreen anche la striscia in alto.
    // La striscia resta attiva anche a pannello aperto: altrimenti, mentre la
    // pillola si espande, il cursore fermo sulla striscia "perde" l'hover e
    // il pannello si chiude e riapre di continuo.
    mask: Region {
        item: pill
        Region { item: win.hotspotActive ? hotspot : null }
        Region { item: win.sidesShown ? leftZone : null }
        Region { item: win.sidesShown ? rightZone : null }
        // I quadratini aperti sono più grandi della loro zona
        Region { item: win.sidesShown ? leftSide : null }
        Region { item: win.sidesShown ? rightSide : null }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    // Moduli aperti da te (click, scorciatoia): tastiera esclusiva, così Esc
    // funziona subito. Quelli che compaiono da soli (OSD, notifiche) non
    // rubano la tastiera: Esc funziona dopo averci cliccato sopra
    // A riposo mai: altrimenti Hyprland può dare la tastiera all'isola appena
    // compare (all'avvio) e le finestre non ricevono i tasti finché non si
    // cambia desktop. Con qualcosa aperto "a richiesta" (Esc dopo un click)
    WlrLayershell.keyboardFocus: wantsKeyboard ? WlrKeyboardFocus.Exclusive
                               : owner !== "" ? WlrKeyboardFocus.OnDemand
                               : WlrKeyboardFocus.None

    // Esc: chiude il modulo aperto, qualunque sia
    Item {
        id: escCatcher
        focus: true
        Keys.onEscapePressed: if (win.owner !== "") win.close(win.owner)
    }

    // ---- Rilevamento fullscreen (workspace attivo del monitor dell'isola) ----
    // Usa l'IPC nativo di Quickshell: nessun processo esterno (hyprctl/sh)
    readonly property var hyprMonitor: Hyprland.monitorFor(win.screen)
    fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace
                   && hyprMonitor.activeWorkspace.hasFullscreen)

    Timer {
        id: fsDebounce
        interval: 50
        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            // autoHide: serve sapere quali finestre sono flottanti e dove
            if (win.autoHide) Hyprland.refreshToplevels()
        }
    }

    // ---- Auto-hide ("autoHide" in theme.json) ----
    // Visibile solo sul desktop libero: si nasconde se sul workspace attivo
    // c'è una finestra in tiling, o una flottante che copre la zona
    // dell'isola (pillola e cerchi a riposo)
    readonly property bool autoHide: Theme.autoHide

    function coversIsland(o) {
        if (!o.at || !o.size || !hyprMonitor) return false
        var screenW = win.screen ? win.screen.width : win.width
        // Metà larghezza della zona a riposo (più un piccolo margine).
        // Staccata: fino al bordo delle zone che sentono il mouse attorno ai
        // cerchi (sideReach), altrimenti una finestra lì accanto non
        // nasconderebbe l'isola ma perderebbe i click in quel punto
        var reach = (floating ? (Theme.s(112) / 2 - topRadius + sideGap + sideSize + sideReach)
                              : Theme.s(172) / 2 - topRadius) + Theme.s(6)
        var left = screenW / 2 - reach, right = screenW / 2 + reach
        var bottom = sideZoneH
        var x = o.at[0] - hyprMonitor.x, y = o.at[1] - hyprMonitor.y
        return x < right && x + o.size[0] > left && y < bottom && y + o.size[1] > 0
    }

    // Finestre del workspace attivo: covered = qualcuna copre l'isola,
    // floating = quante sono flottanti
    readonly property var workspaceWindows: {
        var r = { covered: false, floating: 0 }
        var ws = hyprMonitor ? hyprMonitor.activeWorkspace : null
        if (!autoHide || !ws) return r
        // Workspace speciale (scratchpad) aperto sopra: contano anche le sue
        var mi = hyprMonitor.lastIpcObject || {}
        var special = mi.specialWorkspace && mi.specialWorkspace.name ? mi.specialWorkspace.name : ""
        var list = Hyprland.toplevels.values
        for (var i = 0; i < list.length; i++) {
            var w = list[i].workspace
            if (w !== ws && !(special !== "" && w && w.name === special)) continue
            var o = list[i].lastIpcObject || {}
            // Appena aperta (dati non ancora arrivati) conta come tiling
            if (o.floating === true) r.floating++
            if (o.floating !== true || coversIsland(o)) r.covered = true
        }
        return r
    }
    readonly property bool autoHidden: workspaceWindows.covered

    // Bordo alto (island/EdgeReveal.qml): l'isola scende e le finestre le
    // fanno spazio; resta finché il puntatore è sopra le finestre (fascia
    // del bordo o isola), poi torna su
    property bool edgeStripHovered: false
    property bool peek: false
    onEdgeStripHoveredChanged: {
        if (edgeStripHovered) {
            peekEnd.stop()
            peek = true
        } else if (peek) {
            peekEnd.restart()
        }
    }
    onAutoHiddenChanged: if (!autoHidden) peek = false
    Timer {
        id: peekEnd
        // Breve: solo per non contare il passaggio tra fascia e isola
        interval: 150
        onTriggered: if (!win.edgeStripHovered && !win.pointerNear) win.peek = false
    }

    // Le finestre flottanti spostate col mouse non mandano eventi: finché ce
    // ne sono sul desktop si ricontrolla spesso (una richiesta IPC, niente
    // processi), così l'isola segue subito la finestra trascinata
    Timer {
        interval: 200
        repeat: true
        running: win.autoHide && win.workspaceWindows.floating > 0
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name
            if (n === "fullscreen" || n === "workspacev2"
                || n === "activewindowv2" || n === "focusedmon"
                || n === "movewindowv2" || n === "closewindow"
                || n === "openwindow" || n === "changefloatingmode"
                || n === "activespecial"
                || n === "monitoradded" || n === "monitorremoved")
                fsDebounce.restart()
        }
    }

    Component.onCompleted: {
        // Da qui in poi lo schermo lo cambia solo checkScreen(): niente
        // binding (vedi preferredScreen)
        preferredScreen = pickScreen()
        lastScreen = preferredScreen
        fsDebounce.restart()
    }
    onAutoHideChanged: fsDebounce.restart()

    // Striscia sempre attiva in alto al centro (hover in fullscreen)
    readonly property int hotspotWidth: Theme.s(300)
    Item {
        id: hotspot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: win.hotspotWidth
        height: Math.max(4, Theme.s(4))

        HoverHandler { id: hotspotHover }
    }

    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.targetW
        height: win.targetH

        // Staccata: in fullscreen sale fuori dallo schermo invece di ritirarsi
        y: !win.appeared || (win.floating && win.hiddenMode)
           ? -(height + win.topGap + Theme.s(6)) : win.topGap
        Behavior on y {
            NumberAnimation {
                // Discesa all'avvio un po' più morbida, con un leggero rimbalzo
                duration: win.startupDrop ? 420 : 280
                easing.type: win.startupDrop ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 0.8
            }
        }

        // Quando è completamente ritirata non disegna nulla sul bordo
        visible: height > 1 && y + height > 0

        // In ritirata verso il bordo: curva morbida senza rimbalzo.
        // Apertura: rimbalzo marcato; ritorno all'orologio: rimbalzo appena
        // accennato. Si decide dalla misura di arrivo (targetValue): owner
        // cambia nello stesso momento e l'animazione lo leggerebbe in ritardo
        Behavior on width {
            id: widthBehavior
            NumberAnimation {
                readonly property bool closing: widthBehavior.targetValue <= win.idleW
                duration: win.hiddenMode ? 280 : (closing ? 320 : 380)
                easing.type: win.hiddenMode ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: closing ? 0.5 : 1.1
            }
        }
        Behavior on height {
            id: heightBehavior
            NumberAnimation {
                readonly property bool closing: heightBehavior.targetValue <= win.idleH
                duration: win.hiddenMode ? 280 : (closing ? 320 : 380)
                easing.type: win.hiddenMode ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: closing ? 0.5 : 1.1
            }
        }

        HoverHandler { id: hoverHandler }

        // Attaccata al bordo
        IslandShape {
            visible: !win.floating
            // Alone al posto del bordo (se attivo in theme.json)
            outline: !Theme.shadowEnabled || Theme.glass
            layer.enabled: Theme.shadowEnabled
            layer.effect: SoftGlow {}
            anchors.fill: parent
            anchors.topMargin: -2
            topRadius: win.topRadius
            bottomRadius: win.cornerRadius
        }

        // Staccata: pillola arrotondata (stessa area visibile della forma
        // attaccata, così i moduli non cambiano)
        Rectangle {
            visible: win.floating
            x: win.topRadius
            width: parent.width - 2 * win.topRadius
            height: parent.height
            radius: Math.min(height / 2, win.cornerRadius)
            color: Theme.panel
            // Alone al posto del bordo (se attivo in theme.json); vetro: bordo chiaro
            border.width: Theme.glass ? 1 : (Theme.shadowEnabled ? 0 : 1)
            border.color: Theme.glass ? Theme.glassEdge : Theme.border
            layer.enabled: Theme.shadowEnabled
            layer.effect: SoftGlow {}

            // Vetro: riflesso chiaro in alto che sfuma
            Rectangle {
                visible: Theme.glass
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassSheen }
                    GradientStop { position: 0.45; color: "transparent" }
                }
            }
        }

        // Qui dentro vengono inseriti i moduli
        Item {
            id: contentHost
            anchors.fill: parent
            clip: true
        }

        // Striscia sul bordo alto dello schermo (attaccata: apre il centro di
        // controllo anche sopra le icone). Dentro la pillola: fuori non
        // riceve il puntatore
        Item {
            width: parent.width
            height: win.edgeH
            z: 10
            // Solo a riposo: da aperta coprirebbe i moduli e ne ruberebbe
            // l'hover (pulsanti che non si illuminano)
            enabled: win.owner === ""
            HoverHandler { id: edgeHover }
        }

        // Attaccata: zona dell'orologio, tra le due icone
        Item {
            x: win.topRadius + win.inlineIconPad + win.idleH
            width: Math.max(0, parent.width - 2 * x)
            height: parent.height
            // Solo a riposo, come la striscia sopra
            enabled: win.owner === ""
            HoverHandler { id: clockHover }
        }

        // Minimal: click sull'orario -> centro di controllo. Sotto le icone,
        // che hanno il loro click
        MouseArea {
            anchors.fill: parent
            enabled: win.minimal && win.owner === ""
            visible: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: win.clockClicked()
        }

        // ---- Attaccata: audio e batteria dentro la pillola, ai lati ----
        // Visibili solo a riposo (come l'orologio); il click apre il modulo
        Item {
            id: inlineIcons
            readonly property bool shown: !win.floating && win.owner === "" && !win.concealed
                                          && win.iconsShown
            anchors.fill: parent
            visible: shown
            // Si nasconde subito, ricompare in dissolvenza dopo una pausa
            FadeIn { active: inlineIcons.shown; pause: 100; duration: 250 }

            Item {
                x: win.topRadius + win.inlineIconPad
                y: -Theme.s(1)      // come l'orologio: il bordo alto è nascosto
                width: win.idleH
                height: win.idleH
                AudioIndicator {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.85
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.leftClicked()
                }
            }

            Item {
                x: parent.width - win.topRadius - win.inlineIconPad - width
                y: -Theme.s(1)
                width: win.idleH
                height: win.idleH
                BatteryIndicator {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.85
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.rightClicked()
                }
            }
        }
    }

    // ---- Quadratini ai lati ----
    // Seguono i bordi della pillola: quando l'isola si allarga si spostano
    // con lei (stessa animazione), quando si richiude tornano vicini.
    // Spostamento verso il cursore: proporzionale alla distanza dal centro
    function sideOffset(hover, zone, center) {
        if (!hover.hovered) return 0
        var d = (hover.point.position[zone] - center) * 0.15
        return Math.max(-sideShift, Math.min(sideShift, d))
    }

    // Zone (invisibili) in cui il quadratino "sente" il mouse
    Item {
        id: leftZone
        x: leftSide.anchorX - win.sideSize - win.sideReach
        width: win.sideSize + 2 * win.sideReach
        height: win.sideZoneH
        HoverHandler { id: leftNear }
    }

    Item {
        id: rightZone
        x: rightSide.anchorX - win.sideReach
        width: win.sideSize + 2 * win.sideReach
        height: win.sideZoneH
        HoverHandler { id: rightNear }
    }

    IslandSide {
        id: leftSide
        shown: win.sidesShown
        size: win.sideSize
        restY: win.topGap + (win.idleH - win.sideSize) / 2      // centrato sull'orologio
        round: win.floating
        // Bordo destro attaccato a sinistra della pillola
        growLeft: true
        anchorX: pill.x + win.topRadius - win.sideGap
        offsetX: win.sideOffset(leftNear, "x", leftZone.width / 2)
        offsetY: win.sideOffset(leftNear, "y", restY + size / 2)

        // Audio: muto / basso / alto / cuffie
        AudioIndicator {
            anchors.centerIn: parent
            width: parent.width * win.sideIconScale
            height: parent.height * win.sideIconScale
        }

        // Click: player al centro dell'isola
        onClicked: win.leftClicked()
    }

    IslandSide {
        id: rightSide
        shown: win.sidesShown
        size: win.sideSize
        restY: win.topGap + (win.idleH - win.sideSize) / 2
        round: win.floating
        // Bordo sinistro attaccato a destra della pillola
        anchorX: pill.x + pill.width - win.topRadius + win.sideGap
        offsetX: win.sideOffset(rightNear, "x", rightZone.width / 2)
        offsetY: win.sideOffset(rightNear, "y", restY + size / 2)

        // Batteria del portatile
        BatteryIndicator {
            anchors.centerIn: parent
            width: parent.width * win.sideIconScale
            height: parent.height * win.sideIconScale
        }

        // Click: monitor di sistema al centro dell'isola
        onClicked: win.rightClicked()
    }


    // ---- Moduli aperti dai cerchi: si chiudono cliccando fuori ----
    // Il modulo imposta grabOwner = suo id dopo island.open(); il focus grab
    // di Hyprland si attiva un attimo dopo (come nel launcher)
    property string grabOwner: ""
    property bool grabReady: false
    onOwnerChanged: {
        if (owner !== grabOwner) grabOwner = ""
        grabReady = false
        // Minimal: aprendo qualcosa le icone spariscono subito
        if (owner !== "") {
            revealBlocked = true
            hideIcons.stop()
            revealed = false
        } else if (!pointerNear) {
            revealBlocked = false
        }
    }
    onGrabOwnerChanged: grabReady = false
    Timer {
        interval: 200
        running: win.grabOwner !== "" && win.owner === win.grabOwner && !win.grabReady
        onTriggered: win.grabReady = true
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.grabReady && win.grabOwner !== "" && win.owner === win.grabOwner
        // Finestra ricreata (cambio di schermo): non è un click fuori
        onCleared: if (!remapGuard.running) win.close(win.grabOwner)
    }
}
