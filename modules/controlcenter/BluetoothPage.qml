import QtQuick
import Quickshell.Bluetooth
import qs.services
import qs.widgets

// Pagina Bluetooth: dispositivi connessi, associati e trovati nelle vicinanze
SubPage {
    id: page

    title: "Bluetooth"
    showSwitch: true
    switchOn: !!(adapter && adapter.enabled)
    onSwitchToggled: if (adapter) adapter.enabled = !adapter.enabled

    readonly property var adapter: Bluetooth.defaultAdapter
    // Non "enabled": nasconderebbe la proprietà standard degli Item
    readonly property bool btOn: !!(adapter && adapter.enabled)

    // Ricerca di nuovi dispositivi solo mentre la pagina è aperta
    Binding {
        when: page.adapter !== null
        target: page.adapter
        property: "discovering"
        value: page.visible && page.btOn
    }

    // Dispositivo appena associato da qui: va connesso quando l'associazione finisce
    property var pairingDevice: null

    onVisibleChanged: rebuild()

    // ---------- Liste ----------
    property var connectedList: []
    property var pairedList: []
    property var availableList: []
    property string signature: ""

    function rebuild() {
        var devs = adapter && btOn ? adapter.devices.values : []
        var c = [], p = [], a = []
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (d.connected) c.push(d)
            else if (d.paired || d.bonded) p.push(d)
            else if (d.deviceName !== "") a.push(d)   // senza nome: rumore
        }
        var byName = function (x, y) { return x.name.localeCompare(y.name) }
        p.sort(byName)
        a.sort(byName)

        var sig = [c, p, a].map(function (list) {
            return list.map(function (d) {
                return d.address + ":" + d.name + ":" + d.state + ":" + d.pairing + ":" + battery(d)
            }).join(",")
        }).join("|")
        if (sig === signature) return
        signature = sig
        connectedList = c
        pairedList = p
        availableList = a
    }

    Timer {
        interval: 1000
        repeat: true
        running: page.visible
        onTriggered: page.rebuild()
    }

    Connections {
        target: page.adapter ? page.adapter.devices : null
        function onValuesChanged() { page.rebuild() }
    }

    // Finita l'associazione: rende il dispositivo fidato e lo connette
    Connections {
        target: page.pairingDevice
        function onPairedChanged() {
            var d = page.pairingDevice
            if (d && d.paired) {
                d.trusted = true
                BluetoothAuto.markManual(d.address)   // niente notifica
                d.connect()
                page.pairingDevice = null
            }
        }
    }

    function battery(d) {
        if (!d.batteryAvailable) return -1
        var b = d.battery
        return Math.round(b <= 1 ? b * 100 : b)
    }

    function statusText(d, fallback) {
        if (d.pairing) return "Pairing…"
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
        var b = battery(d)
        return b >= 0 ? fallback + " · " + b + "%" : fallback
    }

    function activate(d) {
        if (d.connected) {
            // Scollegato da te: niente riconnessione automatica
            BluetoothAuto.markDisconnected(d.address)
            d.disconnect()
        } else if (d.paired || d.bonded) {
            BluetoothAuto.markManual(d.address)       // niente notifica
            d.connect()
        } else {
            pairingDevice = d
            d.pair()
        }
        rebuild()
    }

    // ---------- Contenuto ----------
    Text {
        visible: !page.btOn
        width: parent.width
        topPadding: page.u(30)
        horizontalAlignment: Text.AlignHCenter
        text: page.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
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
        delegate: ListRow {
            required property var modelData
            sizeFactor: page.sizeFactor
            icon: "bluetooth"
            title: modelData.name
            subtitle: page.statusText(modelData, "Connected")
            selected: true
            onClicked: page.activate(modelData)
        }
    }

    SectionTitle {
        visible: page.pairedList.length > 0
        sizeFactor: page.sizeFactor
        text: "Paired"
    }
    Repeater {
        model: page.pairedList
        delegate: ListRow {
            required property var modelData
            sizeFactor: page.sizeFactor
            icon: "bluetooth"
            title: modelData.name
            subtitle: page.statusText(modelData, "Not connected")
            showRemove: true
            onClicked: page.activate(modelData)
            onRemoveClicked: modelData.forget()
        }
    }

    SectionTitle {
        visible: page.btOn
        sizeFactor: page.sizeFactor
        text: "Available"
    }
    Repeater {
        model: page.availableList
        delegate: ListRow {
            required property var modelData
            sizeFactor: page.sizeFactor
            icon: "bluetooth"
            title: modelData.name
            subtitle: page.statusText(modelData, "Tap to pair")
            onClicked: page.activate(modelData)
        }
    }
    Text {
        visible: page.btOn && page.availableList.length === 0
        width: parent.width
        topPadding: page.u(6)
        horizontalAlignment: Text.AlignHCenter
        text: "Searching…"
        color: Theme.textMuted
        font.pixelSize: page.u(10)
        font.family: Theme.fontFamily
    }
}
