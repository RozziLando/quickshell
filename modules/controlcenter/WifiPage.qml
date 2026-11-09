import QtQuick
import Quickshell.Networking
import qs.services
import qs.widgets

// Pagina Wi-Fi: rete connessa, reti salvate e reti trovate, con password
SubPage {
    id: page

    title: "Wi-Fi"
    showSwitch: true
    switchOn: Networking.wifiEnabled
    onSwitchToggled: Networking.wifiEnabled = !Networking.wifiEnabled

    // Chiede la tastiera al centro di controllo (per la password)
    signal keyboardWanted()

    // Mentre si scrive la password il pannello non deve chiudersi
    readonly property bool busy: passwordFor !== null

    property var passwordFor: null    // rete per cui si sta scrivendo la password
    property var errorFor: null       // rete la cui connessione è fallita

    readonly property var device: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return devices[i]
        return null
    }

    // Scansione attiva solo mentre la pagina è aperta
    Binding {
        when: page.device !== null
        target: page.device
        property: "scannerEnabled"
        value: page.visible && Networking.wifiEnabled
    }

    onVisibleChanged: {
        if (!visible) {
            passwordFor = null
            errorFor = null
        }
        rebuild()
    }

    // ---------- Liste ----------
    property var connectedList: []
    property var savedList: []
    property var availableList: []
    property string signature: ""

    function level(n) {
        var s = n.signalStrength
        if (s > 1) s = s / 100
        return s > 0.66 ? 3 : (s > 0.33 ? 2 : 1)
    }

    function secured(n) {
        return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown
    }

    // Reti aziendali (802.1X: utente + password, certificati): una password
    // semplice (PSK) non basta. Già salvate (es. con nm-connection-editor)
    // si connettono normalmente; nuove vanno configurate fuori dalla shell
    function enterprise(n) {
        var s = n.security
        return s === WifiSecurityType.Wpa2Eap || s === WifiSecurityType.WpaEap
            || s === WifiSecurityType.Wpa3SuiteB192 || s === WifiSecurityType.Leap
            || s === WifiSecurityType.DynamicWep
    }

    // Ricostruisce le liste solo se qualcosa è davvero cambiato, e mai mentre
    // si scrive la password (altrimenti il campo verrebbe ricreato)
    function rebuild() {
        if (passwordFor !== null) return
        var nets = device && Networking.wifiEnabled ? device.networks.values : []
        var c = [], s = [], a = []
        for (var i = 0; i < nets.length; i++) {
            var n = nets[i]
            if (!n.name) continue
            if (n.connected) c.push(n)
            else if (n.known) s.push(n)
            else a.push(n)
        }
        var bySignal = function (x, y) { return y.signalStrength - x.signalStrength }
        s.sort(bySignal)
        a.sort(bySignal)

        var sig = [c, s, a].map(function (list) {
            return list.map(function (n) {
                return n.name + ":" + n.state + ":" + level(n)
            }).join(",")
        }).join("|")
        if (sig === signature) return
        signature = sig
        connectedList = c
        savedList = s
        availableList = a
    }

    Timer {
        interval: 1500
        repeat: true
        running: page.visible
        onTriggered: page.rebuild()
    }

    Connections {
        target: page.device ? page.device.networks : null
        function onValuesChanged() { page.rebuild() }
    }

    function stateText(n, fallback) {
        if (n.state === ConnectionState.Connecting) return "Connecting…"
        if (n.state === ConnectionState.Disconnecting) return "Disconnecting…"
        return fallback
    }

    function activate(n) {
        errorFor = null
        if (n.connected) {
            n.disconnect()
        } else if (n.known || !secured(n)) {
            n.connect()
        } else if (enterprise(n)) {
            return      // non si può fare da qui (vedi enterprise)
        } else {
            askPassword(n)
        }
    }

    function askPassword(n) {
        passwordFor = n
        keyboardWanted()
    }

    function submit(n, psk) {
        passwordFor = null
        errorFor = null
        if (psk !== "") n.connectWithPsk(psk)
        rebuild()
    }

    // ---------- Contenuto ----------
    Text {
        visible: !Networking.wifiEnabled
        width: parent.width
        topPadding: page.u(30)
        horizontalAlignment: Text.AlignHCenter
        text: page.device ? "Wi-Fi is off" : "No Wi-Fi adapter"
        color: Theme.textMuted
        font.pixelSize: page.u(11)
        font.family: Theme.fontFamily
    }

    SectionTitle {
        visible: page.connectedList.length > 0
        sizeFactor: page.sizeFactor
        text: "Connected"
    }
    Repeater {
        model: page.connectedList
        delegate: WifiNetworkRow {
            owner: page
            subtitle: page.stateText(net, "Connected")
        }
    }

    SectionTitle {
        visible: page.savedList.length > 0
        sizeFactor: page.sizeFactor
        text: "Saved"
    }
    Repeater {
        model: page.savedList
        delegate: WifiNetworkRow {
            owner: page
            subtitle: page.stateText(net, "Saved")
            showRemove: true
            onRemoveClicked: net.forget()
        }
    }

    SectionTitle {
        visible: Networking.wifiEnabled && page.device !== null
        sizeFactor: page.sizeFactor
        text: "Available"
    }
    Repeater {
        model: page.availableList
        delegate: WifiNetworkRow {
            owner: page
            subtitle: page.stateText(net, page.enterprise(net) ? "Enterprise · set up with nm-connection-editor"
                                         : page.secured(net) ? "Secured" : "Open")
        }
    }
    Text {
        visible: Networking.wifiEnabled && page.device !== null && page.availableList.length === 0
        width: parent.width
        topPadding: page.u(6)
        horizontalAlignment: Text.AlignHCenter
        text: "Searching…"
        color: Theme.textMuted
        font.pixelSize: page.u(10)
        font.family: Theme.fontFamily
    }
}
