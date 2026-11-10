pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: !!(adapter && adapter.enabled)

    function devices() {
        return adapter && adapter.devices ? adapter.devices.values : []
    }

    property var manual: ({})
    function markManual(address) {
        var m = Object.assign({}, manual)
        m[address] = Date.now()
        manual = m
    }
    function isManual(address) {
        return manual[address] !== undefined && Date.now() - manual[address] < 30000
    }

    property var userDisconnected: ({})
    function markDisconnected(address) {
        var m = Object.assign({}, userDisconnected)
        m[address] = true
        userDisconnected = m
    }

    property int nextIndex: 0

    function tryOne() {
        if (!enabled) return
        var list = devices().filter(function (d) {
            return (d.paired || d.bonded) && !d.connected && !d.blocked
                && d.state !== BluetoothDeviceState.Connecting
                && !root.userDisconnected[d.address]
        })
        if (list.length === 0) return
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

    onEnabledChanged: {
        userDisconnected = ({})
        if (enabled) firstTry.restart()
    }
    Timer {
        id: firstTry
        interval: 3000
        onTriggered: root.tryOne()
    }

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
