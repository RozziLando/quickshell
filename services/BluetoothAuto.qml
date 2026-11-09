pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Bluetooth acceso -> si connette da solo ai dispositivi già associati
// quando sono a portata, e avvisa con una notifica.
//  - ogni 30 s prova a connettere, uno alla volta, gli associati non connessi
//    (se non sono a portata il tentativo fallisce in silenzio)
//  - notifica "Connected to …" per ogni connessione che NON viene dalla
//    pagina Bluetooth del centro di controllo (quella chiama markManual):
//    sia quelle fatte da qui sia i dispositivi che si ricollegano da soli
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: !!(adapter && adapter.enabled)

    function devices() {
        return adapter && adapter.devices ? adapter.devices.values : []
    }

    // ---------- Connessioni manuali (pagina Bluetooth) ----------
    // indirizzo -> momento del click: niente notifica per un po'
    property var manual: ({})
    function markManual(address) {
        var m = Object.assign({}, manual)
        m[address] = Date.now()
        manual = m
    }
    function isManual(address) {
        return manual[address] !== undefined && Date.now() - manual[address] < 30000
    }

    // ---------- Scollegati a mano (pagina Bluetooth) ----------
    // Non si ricollegano da soli finché non li ricolleghi tu (o finché il
    // Bluetooth non viene spento e riacceso): indirizzo -> true
    property var userDisconnected: ({})
    function markDisconnected(address) {
        var m = Object.assign({}, userDisconnected)
        m[address] = true
        userDisconnected = m
    }

    // ---------- Tentativi automatici ----------
    property int nextIndex: 0

    function tryOne() {
        if (!enabled) return
        var list = devices().filter(function (d) {
            return (d.paired || d.bonded) && !d.connected && !d.blocked
                && d.state !== BluetoothDeviceState.Connecting
                && !root.userDisconnected[d.address]
        })
        if (list.length === 0) return
        // A turno, così un dispositivo spento non blocca gli altri
        var d = list[nextIndex % list.length]
        nextIndex++
        d.connect()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.enabled
        onTriggered: root.tryOne()
    }

    // Appena acceso il Bluetooth (o all'avvio) prova subito
    onEnabledChanged: {
        userDisconnected = ({})
        if (enabled) firstTry.restart()
    }
    Timer {
        id: firstTry
        interval: 3000
        onTriggered: root.tryOne()
    }

    // ---------- Notifiche ----------
    // Connessi all'ultimo controllo (all'avvio: quelli già connessi, senza avviso)
    property var connectedBefore: ({})
    property bool baselineDone: false

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            var now = {}
            root.devices().forEach(function (d) {
                if (!d.connected) return
                now[d.address] = true
                // Ricollegato (da te o dal dispositivo): torna automatico.
                // Solo per una connessione nuova: subito dopo il click risulta
                // ancora connesso finché la disconnessione non finisce
                if (root.userDisconnected[d.address] && !root.connectedBefore[d.address]) {
                    const m = Object.assign({}, root.userDisconnected)
                    delete m[d.address]
                    root.userDisconnected = m
                }
                if (root.baselineDone && !root.connectedBefore[d.address]
                        && !root.isManual(d.address)) {
                    Quickshell.execDetached(["notify-send", "-a", "Bluetooth",
                        "Connected to " + (d.name || d.deviceName || d.address)])
                }
            })
            root.connectedBefore = now
            root.baselineDone = true
        }
    }
}
