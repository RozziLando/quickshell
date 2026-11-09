import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    required property var launcher
    required property var notifications
    required property var power
    anchors.fill: parent

    readonly property string ownerId: "control"
    readonly property bool shown: island.owner === ownerId

    // ---------- Impostazioni ----------
    // true: il pannello prende la tastiera quando si apre, così basta iniziare
    // a scrivere per passare al launcher. false: serve prima un click su Search
    property bool typeToSearch: true
    // Screenshot di una regione, solo negli appunti (nessun file salvato).
    // grim + slurp + wl-copy: repo ufficiali di Arch e Fedora.
    property string screenshotCommand:
        'g="$(slurp)" || exit 0; grim -g "$g" - | wl-copy --type image/png'

    // ---------- Dimensioni (scalate) ----------
    // Dimensione del pannello: 1 = misura originale, 0.8 = 20% più piccolo
    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int openWidth: root.u(436)   // era 472, poi 456
    // Stesso spazio tra contenuto e bordo su tutti i lati. Ai lati si aggiunge
    // la parte trasparente della pillola (topRadius), che non si vede
    readonly property int edgePad: root.u(14)
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int topPad: edgePad
    readonly property int bottomPad: edgePad
    readonly property int gap: root.u(10)
    readonly property int tileH: root.u(54)
    // Cerchi screenshot / power: un pelo più piccoli delle tile
    readonly property int circleSize: root.u(48)
    readonly property int sliderCardH: root.u(60)
    // Senza notifiche il riquadro è solo la riga del titolo
    readonly property bool hasNotifications: notifications.history.count > 0
    readonly property int notifItemH: root.u(56)
    readonly property int notifSpacing: root.u(6)
    // Notifiche visibili: 1, 2, poi al massimo due e mezza (la mezza fa capire
    // che si può scorrere per le altre)
    readonly property real notifVisible: Math.min(notifications.history.count, 2.5)
    readonly property int notifListH: Math.round(notifVisible * notifItemH
        + Math.max(0, Math.ceil(notifVisible) - 1) * notifSpacing)
    // Riquadro: titolo + lista (con una notifica è alto come prima, u(100))
    readonly property int notifCardH: hasNotifications ? root.u(100) - notifItemH + notifListH
                                                       : root.u(38)
    // Alta il doppio del raggio dei riquadri: stessa curva di tutto il resto
    readonly property int searchH: 2 * cardRadius
    readonly property int cardRadius: root.u(22)
    // Angoli dell'isola concentrici con i riquadri: raggio interno + margine
    readonly property int panelRadius: cardRadius + edgePad

    // ---------- Computer fisso o portatile (riconosciuto da solo) ----------
    // Fisso = nessuna batteria. Sul fisso solo la barra del volume (niente
    // luminosità di schermo e tastiera); senza Bluetooth, al posto della sua
    // tile i cerchi App e Temi
    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool desktop: !(batteryDevice && batteryDevice.ready
                                      && batteryDevice.isLaptopBattery && batteryDevice.isPresent)
    readonly property bool hasBluetooth: !!btAdapter
    readonly property bool showDisplay: !desktop
    readonly property bool showKeyboard: !desktop && keyboardAvailable

    // tile + barre + notifiche + search, con uno spazio tra ogni elemento
    readonly property int sliderCount: 1 + (showDisplay ? 1 : 0) + (showKeyboard ? 1 : 0)
    readonly property int openHeight: topPad + tileH + sliderCount * sliderCardH
        + notifCardH + searchH + (sliderCount + 2) * gap + bottomPad

    // Se cambia l'altezza mentre il pannello è aperto, adatta l'isola
    // (senza togliere la tastiera se l'aveva chiesta una pagina, es. la password Wi-Fi)
    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight,
                                                typeToSearch || island.wantsKeyboard)

    // ---------- Stato ----------
    // Wi-Fi e Bluetooth: moduli nativi di Quickshell (D-Bus), niente polling
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: !!(btAdapter && btAdapter.enabled)

    // Scheda Wi-Fi presente? Su un fisso senza Wi-Fi si mostra la rete cablata
    readonly property bool hasWifi: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return true
        return false
    }
    readonly property bool wiredConnected: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wired && devices[i].connected) return true
        return false
    }
    readonly property string wiredStatus: {
        if (Networking.backend === NetworkBackendType.None) return "Unknown"
        return wiredConnected ? "Connected" : "Offline"
    }

    // Testo sotto i titoli delle tile
    readonly property string wifiStatus: {
        if (!wifiOn) return "Off"
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wifi) continue
            var nets = devices[i].networks.values
            for (var j = 0; j < nets.length; j++)
                if (nets[j].connected) return nets[j].name
        }
        return "On"
    }
    readonly property string bluetoothStatus: {
        if (!bluetoothOn) return "Off"
        var devices = btAdapter.devices.values
        var names = []
        for (var i = 0; i < devices.length; i++)
            if (devices[i].connected) names.push(devices[i].name)
        if (names.length === 0) return "On"
        return names.length === 1 ? names[0] : names[0] + " +" + (names.length - 1)
    }
    // Luminosità: condivisa con l'OSD (vedi Brightness.qml)
    readonly property real displayLevel: Brightness.displayLevel
    readonly property bool displayAvailable: Brightness.displayAvailable
    readonly property real keyboardLevel: Brightness.keyboardLevel
    readonly property bool keyboardAvailable: Brightness.keyboardAvailable

    // Audio (PipeWire, nativo in Quickshell)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // Non chiudere mentre stai trascinando una barra
    readonly property bool busy: volumeSlider.dragging
        || displaySlider.dragging || keyboardSlider.dragging
        || wifiPage.busy || audioPage.busy || displayPage.busy

    // ---------- Pagine di dettaglio ----------
    // "" = pagina principale, oppure "wifi", "bluetooth", "audio", "display"
    property string page: ""

    function openPage(name) {
        page = name
        pageFocusTimer.restart()
    }

    function closePage() {
        page = ""
        focusTimer.restart()
    }

    // La pagina prende la tastiera, così Esc torna indietro
    Timer {
        id: pageFocusTimer
        interval: 60
        onTriggered: {
            if (root.page === "wifi") wifiPage.forceActiveFocus()
            else if (root.page === "bluetooth") bluetoothPage.forceActiveFocus()
            else if (root.page === "audio") audioPage.forceActiveFocus()
            else if (root.page === "display") displayPage.forceActiveFocus()
        }
    }

    // Per scrivere la password serve la tastiera anche se typeToSearch è false
    function requestKeyboard() {
        if (shown) island.open(ownerId, openWidth, openHeight, true)
    }

    // ---------- Lettura dello stato ----------
    // Ricontrolla i dispositivi a ogni apertura (nel caso cambino)
    function refresh() {
        Brightness.refresh()
    }

    onShownChanged: {
        if (shown) {
            refresh()
            focusTimer.restart()
        } else {
            // Alla prossima apertura si riparte dalla pagina principale
            page = ""
            // Chiuso (Esc, click, scorciatoia) col puntatore ancora sopra:
            // non si riapre finché il puntatore non esce e rientra
            if (island.openHovered) reopenBlocked = true
        }
    }

    property bool reopenBlocked: false

    // ---------- Azioni ----------
    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleBluetooth() {
        if (btAdapter) btAdapter.enabled = !btAdapter.enabled
    }

    function takeScreenshot() {
        island.close(ownerId)
        // Piccolo ritardo: l'isola deve sparire prima dello scatto
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; " + screenshotCommand])
    }

    function setVolume(value) {
        if (audioAvailable)
            sink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute() {
        if (audioAvailable) sink.audio.muted = !sink.audio.muted
    }

    function setDisplay(value) {
        Brightness.setDisplay(value)
    }

    function setKeyboard(value) {
        Brightness.setKeyboard(value)
    }

    // ---------- Apertura/chiusura con l'hover ----------
    Connections {
        target: root.island
        // Restare sopra l'isola la tiene aperta, uscirne la chiude
        function onHoveredChanged() {
            if (root.island.hovered) {
                closeTimer.stop()
            } else {
                openTimer.stop()
                if (root.shown) closeTimer.restart()
            }
        }
        // Apertura: tutta la pillola (staccata) o solo il bordo alto (attaccata)
        function onOpenHoveredChanged() {
            if (!root.island.openHovered) root.reopenBlocked = false
            else if (root.island.owner === "" && !root.reopenBlocked) openTimer.restart()
        }
        // L'isola torna libera (es. finito l'OSD) mentre sei già sul bordo:
        // senza questo non si aprirebbe finché non ti sposti
        function onOwnerChanged() {
            if (root.island.owner === "" && root.island.openHovered && !root.reopenBlocked)
                openTimer.restart()
        }
    }

    // ---------- Apertura da comando (bind di Hyprland) ----------
    // qs ipc call controlcenter toggle
    // Aperto così si chiude con Esc, cliccando fuori o ripetendo il comando
    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        island.open(ownerId, openWidth, openHeight, typeToSearch, panelRadius)
        island.grabOwner = ownerId
    }

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { root.toggle() }
    }

    // Screenshot da comando (es. scorciatoia di Hyprland), negli appunti:
    //   qs ipc call screenshot region   regione scelta col mouse (come il pulsante)
    //   qs ipc call screenshot screen   tutto lo schermo sotto il mouse
    IpcHandler {
        target: "screenshot"
        function region(): void { root.takeScreenshot() }
        function screen(): void {
            root.island.close(root.ownerId)
            var mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            Quickshell.execDetached(["sh", "-c",
                'sleep 0.5; grim ' + (mon !== "" ? '-o "$1" ' : '') + '- | wl-copy --type image/png',
                "sh", mon])
        }
    }

    // Piccola attesa per evitare aperture accidentali
    Timer {
        id: openTimer
        interval: 250
        onTriggered: {
            if (root.island.openHovered && root.island.owner === "" && !root.reopenBlocked)
                root.island.open(root.ownerId, root.openWidth, root.openHeight,
                                 root.typeToSearch, root.panelRadius)
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: {
            if (root.busy) restart()
            else root.island.close(root.ownerId)
        }
    }

    // La tastiera arriva alla barra Search dopo che il compositor ha dato il focus
    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.typeToSearch) searchInput.forceActiveFocus()
    }

    // ---------- Interfaccia ----------
    Column {
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        spacing: root.gap

        // Si nasconde di colpo, compare in dissolvenza
        visible: root.shown && root.page === ""
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
        FadeIn { active: (root.shown && root.page === ""); pause: 160; duration: 220 }

        // ----- Tile Wi-Fi / Bluetooth + cerchi screenshot / power -----
        Row {
            id: topRow
            width: parent.width
            height: root.tileH
            spacing: root.gap

            // Tile (rete, Bluetooth se c'è) e cerchi tutti alla stessa distanza
            readonly property int tiles: root.hasBluetooth ? 2 : 1
            readonly property int circles: root.hasBluetooth ? 2 : 4
            readonly property int tileW: (width - circles * root.circleSize
                                          - (tiles + circles - 1) * spacing) / tiles

            // Wi-Fi, oppure rete cablata se il computer non ha il Wi-Fi
            ToggleTile {
                sizeFactor: root.sizeFactor
                cornerRadius: root.cardRadius
                width: topRow.tileW
                height: root.tileH
                kind: root.hasWifi ? "wifi" : "ethernet"
                title: root.hasWifi ? "Wi-Fi" : "Ethernet"
                subtitle: root.hasWifi ? root.wifiStatus : root.wiredStatus
                active: root.hasWifi ? root.wifiOn : root.wiredConnected
                onToggled: if (root.hasWifi) root.toggleWifi()
                onClicked: if (root.hasWifi) root.openPage("wifi")
            }
            ToggleTile {
                visible: root.hasBluetooth
                sizeFactor: root.sizeFactor
                cornerRadius: root.cardRadius
                width: topRow.tileW
                height: root.tileH
                kind: "bluetooth"
                title: "Bluetooth"
                subtitle: root.bluetoothStatus
                active: root.bluetoothOn
                onToggled: root.toggleBluetooth()
                onClicked: root.openPage("bluetooth")
            }
            // Senza Bluetooth: scorciatoie al launcher (app) e all'aspetto (temi)
            CircleButton {
                visible: !root.hasBluetooth
                kind: "grid"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.launcher.openMode(0)
            }
            CircleButton {
                visible: !root.hasBluetooth
                kind: "palette"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.launcher.openMode(1)
            }
            CircleButton {
                kind: "screenshot"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.takeScreenshot()
            }
            CircleButton {
                kind: "power"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.power.open()
            }
        }

        // ----- Barre -----
        ControlSlider {
            sizeFactor: root.sizeFactor
            id: volumeSlider
            width: parent.width
            height: root.sliderCardH
            title: "Audio"
            icon: root.audioAvailable && root.sink.audio.muted ? "volume-mute" : "volume"
            value: root.audioAvailable ? root.sink.audio.volume : 0
            muted: root.audioAvailable && root.sink.audio.muted
            available: root.audioAvailable
            iconClickable: true
            onMoved: value => root.setVolume(value)
            onIconClicked: root.toggleMute()
            onDetailsClicked: root.openPage("audio")
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: displaySlider
            visible: root.showDisplay
            onDetailsClicked: root.openPage("display")
            width: parent.width
            height: root.sliderCardH
            title: "Display"
            icon: "sun"
            value: root.displayLevel
            available: root.displayAvailable
            onMoved: value => root.setDisplay(value)
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: keyboardSlider
            showDetails: false
            visible: root.showKeyboard
            width: parent.width
            height: root.sliderCardH
            title: "Keyboard"
            icon: "keyboard"
            value: root.keyboardLevel
            available: root.keyboardAvailable
            onMoved: value => root.setKeyboard(value)
        }

        // ----- Centro notifiche (compatto) -----
        Card {
            width: parent.width
            height: root.notifCardH
            radius: root.cardRadius

            Item {
                id: notifTop
                anchors {
                    top: parent.top
                    topMargin: root.u(10)
                    left: parent.left
                    right: parent.right
                    leftMargin: root.u(16)
                    rightMargin: root.u(16)
                }
                height: root.u(18)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications" + (root.notifications.history.count > 1
                                         ? "  ·  " + root.notifications.history.count : "")
                    color: Theme.textSecondary
                    font.pixelSize: root.u(10)
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.notifications.history.count > 0
                    text: "Clear all"
                    color: Theme.textMuted
                    font.pixelSize: root.u(10)
                    font.family: Theme.fontFamily

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.u(6)
                        onClicked: root.notifications.history.clear()
                    }
                }
            }

            // Mostra una notifica alla volta, le altre si scorrono con la rotella
            ListView {
                id: notifList
                visible: root.hasNotifications
                anchors {
                    top: notifTop.bottom
                    topMargin: root.u(6)
                    left: parent.left
                    right: parent.right
                    leftMargin: root.u(10)
                    rightMargin: root.u(10)
                }
                height: root.notifListH
                clip: true
                spacing: root.notifSpacing
                model: root.notifications.history
                boundsBehavior: Flickable.StopAtBounds

                delegate: Card {
                    id: entry
                    required property int index
                    required property string app
                    required property string summary
                    required property string body
                    required property string icon
                    required property string desktopEntry
                    required property bool rounded

                    width: ListView.view.width
                    height: root.notifItemH
                    // Concentrico con il riquadro delle notifiche (margine u(10))
                    radius: root.cardRadius - root.u(10)
                    color: entryArea.containsMouse ? Theme.highlight : Theme.surface
                    border.color: "transparent"

                    // Click sulla voce: torna all'app che l'ha mandata
                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.notifications.focusApp(entry.desktopEntry, entry.app)
                            root.island.close(root.ownerId)
                        }
                    }

                    // Avatar: icona dell'app, oppure la lettera iniziale
                    Item {
                        id: avatar
                        width: root.u(30)
                        height: root.u(30)
                        anchors {
                            left: parent.left
                            leftMargin: root.u(12)
                            verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: !iconBox.visible
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: entry.app !== "" ? entry.app.charAt(0).toUpperCase() : "?"
                                color: Theme.accent
                                font.pixelSize: root.u(11)
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                        }

                        // Avatar (immagine della notifica) ritagliato a
                        // cerchio; logo dell'app così com'è
                        ClippingRectangle {
                            id: iconBox
                            anchors.fill: parent
                            radius: entry.rounded ? width / 2 : 0
                            color: "transparent"
                            visible: entry.icon !== "" && iconImage.status === Image.Ready

                            Image {
                                id: iconImage
                                anchors.fill: parent
                                source: entry.icon
                                // Pixel veri del riquadro (u(30)) sul monitor
                                sourceSize.width: Theme.px(root.u(30), iconImage)
                                sourceSize.height: Theme.px(root.u(30), iconImage)
                                fillMode: entry.rounded ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                    }

                    Column {
                        anchors {
                            left: avatar.right
                            leftMargin: root.u(10)
                            right: closeButton.left
                            rightMargin: root.u(6)
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width
                            text: entry.app
                            color: Theme.textMuted
                            font.pixelSize: root.u(9)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: entry.summary
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.pixelSize: root.u(11)
                            font.bold: true
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: entry.body !== ""
                            text: entry.body.replace(/\n/g, " ")
                            textFormat: Text.PlainText
                            color: Theme.textSoft
                            font.pixelSize: root.u(10)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    // X: toglie questa notifica dall'elenco
                    Item {
                        id: closeButton
                        width: root.u(16)
                        height: root.u(16)
                        anchors {
                            right: parent.right
                            rightMargin: root.u(14)
                            verticalCenter: parent.verticalCenter
                        }

                        LineIcon {
                            anchors.centerIn: parent
                            kind: "close"
                            size: root.u(10)
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -root.u(5)
                            onClicked: root.notifications.history.remove(entry.index)
                        }
                    }
                }
            }

            // Senza notifiche: scritta a destra nella riga del titolo
            Text {
                anchors.right: notifTop.right
                anchors.verticalCenter: notifTop.verticalCenter
                visible: !root.hasNotifications
                text: "No notifications"
                color: Theme.textMuted
                font.pixelSize: root.u(10)
                font.family: Theme.fontFamily
            }
        }

        // ----- Barra Search (passa al launcher) -----
        Card {
            width: parent.width
            height: root.searchH
            radius: root.cardRadius

            LineIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: root.u(14)
                anchors.verticalCenter: parent.verticalCenter
                kind: "search"
                size: root.u(16)
                color: Theme.textMuted
            }

            TextInput {
                id: searchInput
                anchors {
                    fill: parent
                    leftMargin: root.u(40)
                    rightMargin: root.u(16)
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.selection
                font.pixelSize: root.u(14)
                font.family: Theme.fontFamily
                clip: true

                // Appena scrivi qualcosa, passa al launcher con il testo già inserito
                onTextChanged: {
                    if (text !== "") {
                        var typed = text
                        text = ""
                        root.launcher.openWithText(typed)
                    }
                }

                Keys.onEscapePressed: root.island.close(root.ownerId)
            }

            Text {
                anchors.left: searchInput.left
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                text: "Search"
                color: Theme.textMuted
                font.pixelSize: root.u(14)
                font.family: Theme.fontFamily
            }

            // Click: passa al launcher
            MouseArea {
                anchors.fill: parent
                onClicked: root.launcher.openWithText("")
            }
        }
    }

    // ---------- Pagine (stessa area della pagina principale) ----------
    WifiPage {
        id: wifiPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "wifi"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
        onKeyboardWanted: root.requestKeyboard()
    }

    BluetoothPage {
        id: bluetoothPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "bluetooth"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }

    AudioPage {
        id: audioPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "audio"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }

    DisplayPage {
        id: displayPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "display"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }
}
