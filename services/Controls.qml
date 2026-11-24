pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property int maxSlots: 6

    readonly property var battery: UPower.displayDevice
    readonly property bool laptop: !!(battery && battery.ready && battery.isLaptopBattery && battery.isPresent)
    readonly property bool hasBluetooth: Bluetooth.adapters.values.length > 0
    readonly property bool hasWifi: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return true
        return false
    }
    readonly property bool hasDisplay: laptop || Theme.displayOnDesktop
    readonly property bool hasKeyboardLight: laptop && Brightness.keyboardAvailable

    readonly property var tileInfo: ({
        "network": { slots: 2, label: hasWifi ? "Wi-Fi" : "Ethernet", icon: hasWifi ? "wifi" : "ethernet" },
        "bluetooth": { slots: 2, label: "Bluetooth", icon: "bluetooth" },
        "launcher": { slots: 1, label: "Apps", icon: "grid" },
        "themes": { slots: 1, label: "Themes", icon: "palette" },
        "screenshot": { slots: 1, label: "Screenshot", icon: "screenshot" },
        "power": { slots: 1, label: "Power", icon: "power" },
        "settings": { slots: 1, label: "Settings", icon: "gear" }
    })
    readonly property var tileOrder: ["network", "bluetooth", "launcher", "themes", "screenshot", "power", "settings"]

    readonly property var sectionInfo: ({
        "audio": { label: "Audio", icon: "volume" },
        "display": { label: "Display", icon: "sun" },
        "keyboard": { label: "Keyboard", icon: "keyboard" },
        "notifications": { label: "Notifications", icon: "bell" },
        "search": { label: "Search", icon: "search" },
        "apps": { label: "Background apps", icon: "app" }
    })
    readonly property var sectionOrder: ["audio", "display", "keyboard", "notifications", "search", "apps"]

    function tileAvailable(id) {
        if (!tileInfo[id]) return false
        if (id === "bluetooth") return hasBluetooth
        return true
    }

    function sectionAvailable(id) {
        if (!sectionInfo[id]) return false
        if (id === "display") return hasDisplay
        if (id === "keyboard") return hasKeyboardLight
        if (id === "apps") return Theme.backgroundApps
        return true
    }

    function toList(value) {
        if (value && typeof value === "object" && typeof value.length === "number")
            return Array.prototype.slice.call(value).map(String)
        return null
    }

    function slotsOf(list) {
        var n = 0
        list.forEach(function (id) { n += root.tileInfo[id] ? root.tileInfo[id].slots : 0 })
        return n
    }

    readonly property var defaultTiles: hasBluetooth
        ? ["network", "bluetooth", "screenshot", "power"]
        : ["network", "launcher", "themes", "screenshot", "power"]
    readonly property var defaultSections: ["audio", "display", "keyboard", "notifications", "search"]

    readonly property var tiles: {
        var list = toList(Theme.controlTiles) || defaultTiles
        var out = [], used = 0
        list.forEach(function (id) {
            if (!root.tileAvailable(id) || out.indexOf(id) >= 0) return
            var s = root.tileInfo[id].slots
            if (used + s > root.maxSlots) return
            out.push(id)
            used += s
        })
        return out
    }

    readonly property var chosenSections: {
        var list = toList(Theme.controlSections) || defaultSections
        var out = []
        list.forEach(function (id) {
            if (root.sectionInfo[id] && out.indexOf(id) < 0) out.push(id)
        })
        return out
    }

    readonly property var sections: chosenSections.filter(sectionAvailable)

    readonly property bool appsInControl: Theme.backgroundApps && sections.indexOf("apps") >= 0

    readonly property var barKinds: ["clock", "workspaces", "logo", "search", "themes", "power",
                                     "audio", "network", "bluetooth", "display", "sysmon", "notifications"]

    readonly property var barInfo: ({
        "clock": { label: "Clock", icon: "calendar" },
        "workspaces": { label: "Workspaces", icon: "layout" },
        "logo": { label: "Distro logo", icon: "app" },
        "search": { label: "Search", icon: "search" },
        "themes": { label: "Themes", icon: "palette" },
        "power": { label: "Power", icon: "power" },
        "audio": { label: "Audio", icon: "volume" },
        "network": { label: hasWifi ? "Wi-Fi" : "Ethernet", icon: hasWifi ? "wifi" : "ethernet" },
        "bluetooth": { label: "Bluetooth", icon: "bluetooth" },
        "display": { label: "Display", icon: "sun" },
        "sysmon": { label: laptop ? "Battery" : "System monitor", icon: "cpu" },
        "notifications": { label: "Notifications", icon: "bell" }
    })

    function barAvailable(kind) {
        if (barKinds.indexOf(kind) < 0) return false
        if (kind === "bluetooth") return hasBluetooth
        if (kind === "display") return hasDisplay
        return true
    }

    readonly property var barSections: {
        var raw = Theme.barItems || {}
        var start = toList(raw.start), center = toList(raw.center), end = toList(raw.end)
        if (!start && !center && !end) {
            start = ["logo", "workspaces", "search"]
            center = ["clock"]
            end = ["audio", "sysmon", "split1", "notifications", "power"]
        }
        var seen = {}
        function clean(list) {
            return (list || []).filter(function (k) {
                k = String(k)
                if ((!root.isSplit(k) && !root.barAvailable(k)) || seen[k]) return false
                seen[k] = true
                return true
            })
        }
        return { start: clean(start), center: clean(center), end: clean(end) }
    }

    function isSplit(k) { return /^split\d+$/.test(String(k)) }

    readonly property var barItemsFlat: {
        var s = barSections
        function flat(list) { return list.filter(function (k) { return !root.isSplit(k) }) }
        return { start: flat(s.start), center: flat(s.center), end: flat(s.end) }
    }

    readonly property var barPills: {
        var s = barSections
        function group(list) {
            var out = [], cur = []
            list.forEach(function (k) {
                if (root.isSplit(k)) {
                    if (cur.length > 0) out.push(cur)
                    cur = []
                } else {
                    cur.push(k)
                }
            })
            if (cur.length > 0) out.push(cur)
            return out
        }
        return { start: group(s.start), center: group(s.center), end: group(s.end) }
    }

    signal settingsRequested(string page)
}
