pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    property bool powerDaemon: false
    property bool hasPowerProfiles: false
    Process {
        running: true
        command: ["sh", "-c",
            'command -v gdbus >/dev/null 2>&1 || exit 1;'
            + ' gdbus introspect --system --dest org.freedesktop.UPower.PowerProfiles'
            + ' --object-path /org/freedesktop/UPower/PowerProfiles >/dev/null 2>&1'
            + ' || gdbus introspect --system --dest net.hadess.PowerProfiles'
            + ' --object-path /net/hadess/PowerProfiles >/dev/null 2>&1']
        onExited: code => {
            root.powerDaemon = code === 0
            root.hasPowerProfiles = code === 0
        }
    }

    LazyLoader {
        id: powerBridge
        active: root.powerDaemon
        PowerBridge {}
    }

    readonly property var powerModes: [
        { label: "Saver", icon: "leaf" },
        { label: "Balanced", icon: "scales" },
        { label: "Performance", icon: "lightning" }
    ]
    property int previewProfile: 1
    readonly property int powerProfile: powerBridge.item ? powerBridge.item.profile : previewProfile
    readonly property var powerMode: powerModes[Math.max(0, Math.min(2, powerProfile))]

    function cyclePower() {
        var next = (powerProfile + 1) % 3
        if (powerBridge.item && !powerBridge.item.hasPerformance && next === 2) next = 0
        if (powerBridge.item) powerBridge.item.set(next)
        else previewProfile = next
    }

    readonly property var tileInfo: ({
        "network": { slots: 2, label: hasWifi ? "Wi-Fi" : "Ethernet", icon: hasWifi ? "wifi" : "ethernet" },
        "bluetooth": { slots: 2, label: "Bluetooth", icon: "bluetooth" },
        "launcher": { slots: 1, label: "Apps", icon: "grid" },
        "themes": { slots: 1, label: "Themes", icon: "palette" },
        "screenshot": { slots: 1, label: "Screenshot", icon: "screenshot" },
        "power": { slots: 1, label: "Power", icon: "power" },
        "settings": { slots: 1, label: "Settings", icon: "gear" },
        "powermode": { slots: 2, label: "Power mode", icon: "gauge" }
    })
    readonly property var tileOrder: ["network", "bluetooth", "powermode", "launcher", "themes", "screenshot", "power", "settings"]

    readonly property var sectionInfo: ({
        "audio": { label: "Audio", icon: "volume" },
        "display": { label: "Display", icon: "sun" },
        "keyboard": { label: "Keyboard", icon: "keyboard" },
        "notifications": { label: "Notifications", icon: "bell" },
        "search": { label: "Search", icon: "search" },
        "apps": { label: "Background apps", icon: "app" },
        "clock": { label: "Clock", icon: "calendar" }
    })
    readonly property var sectionOrder: ["audio", "display", "keyboard", "clock", "notifications", "search", "apps"]

    readonly property int maxRows: 6
    readonly property var gridOrder: ["clock", "network", "bluetooth", "powermode", "audio", "display", "keyboard",
                                      "launcher", "themes", "screenshot", "power", "settings"]
    readonly property var bottomOrder: ["notifications", "search", "apps"]
    readonly property var resizable: ["audio", "display", "keyboard", "clock"]

    function isTile(id) { return !!tileInfo[id] }
    function isSection(id) { return !!sectionInfo[id] }
    function isGrid(id) { return gridOrder.indexOf(id) >= 0 }
    function isBottom(id) { return bottomOrder.indexOf(id) >= 0 }

    function minSpan(id) {
        if (id === "clock") return 2
        if (resizable.indexOf(id) >= 0) return 3
        return spanOf(id, {})
    }

    function defaultSpan(id) {
        if (tileInfo[id]) return tileInfo[id].slots
        return id === "clock" && laptop ? 4 : maxSlots
    }

    function spanOf(id, widths) {
        if (tileInfo[id]) return tileInfo[id].slots
        if (resizable.indexOf(id) < 0) return maxSlots
        var map = widths !== undefined ? widths : Theme.controlWidths
        var v = map && typeof map === "object" ? Number(map[id]) : NaN
        if (isNaN(v)) return defaultSpan(id)
        return Math.max(minSpan(id), Math.min(maxSlots, Math.round(v)))
    }

    function itemAvailable(id) {
        if (id === "bluetooth") return hasBluetooth
        if (id === "powermode") return powerModeShown
        if (id === "display") return hasDisplay
        if (id === "keyboard") return hasKeyboardLight
        if (id === "apps") return Theme.backgroundApps
        return isGrid(id) || isBottom(id)
    }
    function tileAvailable(id) { return isTile(id) && itemAvailable(id) }
    function sectionAvailable(id) { return isSection(id) && itemAvailable(id) }

    function spanWidth(total, slots, gap) {
        return (total + gap) * slots / maxSlots - gap
    }

    function toList(value) {
        if (value && typeof value === "object" && typeof value.length === "number")
            return Array.prototype.slice.call(value).map(String)
        return null
    }

    function fits(cells, row, col, span) {
        if (row < 0 || row >= maxRows || col < 0 || col + span > maxSlots) return false
        for (var c = col; c < col + span; c++) if (cells[row * maxSlots + c]) return false
        return true
    }

    function occupy(cells, row, col, span, id) {
        for (var c = col; c < col + span; c++) cells[row * maxSlots + c] = id
    }

    function packGrid(list, widths) {
        var out = [], cells = {}, row = 0, col = 0
        list.forEach(function (id) {
            var span = root.spanOf(id, widths)
            if (col + span > root.maxSlots) {
                row++
                col = 0
            }
            if (row >= root.maxRows) return
            root.occupy(cells, row, col, span, id)
            out.push({ id: id, row: row, col: col })
            col += span
        })
        return out
    }

    function placeGrid(entries, widths, available) {
        var out = [], cells = {}, seen = {}
        entries.forEach(function (e) {
            if (!e || !root.isGrid(e.id) || seen[e.id]) return
            if (available && !root.itemAvailable(e.id)) return
            var span = root.spanOf(e.id, widths)
            var row = Math.round(Number(e.row)), col = Math.round(Number(e.col))
            if (isNaN(row) || isNaN(col)) return
            col = Math.max(0, Math.min(root.maxSlots - span, col))
            if (!root.fits(cells, row, col, span)) return
            seen[e.id] = true
            root.occupy(cells, row, col, span, e.id)
            out.push({ id: e.id, row: row, col: col, span: span })
        })
        return out
    }

    function firstFree(entries, id, widths) {
        var cells = {}, span = spanOf(id, widths)
        entries.forEach(function (e) { if (e.id !== id) root.occupy(cells, e.row, e.col, root.spanOf(e.id, widths), e.id) })
        for (var r = 0; r < maxRows; r++)
            for (var c = 0; c + span <= maxSlots; c++)
                if (fits(cells, r, c, span)) return { row: r, col: c }
        return null
    }

    function gridLayout(entries, total, gap, heightOf, rowsShown, emptyH) {
        var rows = {}, maxRow = -1
        entries.forEach(function (e) {
            rows[e.row] = Math.max(rows[e.row] || 0, heightOf(e.id))
            maxRow = Math.max(maxRow, e.row)
        })
        var last = rowsShown !== undefined ? Math.max(maxRow, rowsShown - 1) : maxRow
        var ys = {}, hs = {}, y = 0
        for (var r = 0; r <= last; r++) {
            var h = rows[r] !== undefined ? rows[r] : (rowsShown !== undefined ? emptyH : -1)
            if (h < 0) continue
            ys[r] = y
            hs[r] = h
            y += h + gap
        }
        var unit = (total + gap) / maxSlots, out = { rows: ys, heights: hs }
        entries.forEach(function (e) {
            var ih = heightOf(e.id)
            out[e.id] = { x: e.col * unit, y: ys[e.row] + (hs[e.row] - ih) / 2,
                          w: (e.span || root.spanOf(e.id)) * unit - gap, h: ih, row: e.row, col: e.col }
        })
        out.total = Math.max(0, y - gap)
        return out
    }

    readonly property var defaultTiles: hasBluetooth
        ? ["network", "bluetooth", "screenshot", "power"]
        : ["network", "launcher", "themes", "screenshot", "power"]
    readonly property var defaultSections: ["audio", "display", "keyboard", "notifications", "search"]

    readonly property var legacyItems: {
        var list = toList(Theme.controlItems)
        if (!list) list = (toList(Theme.controlTiles) || defaultTiles).concat(toList(Theme.controlSections) || defaultSections)
        return list
    }

    function gridEntries(value) {
        if (value && typeof value === "object" && typeof value.length === "number") {
            var out = []
            for (var i = 0; i < value.length; i++) {
                var e = value[i]
                if (e && typeof e === "object" && e.id !== undefined)
                    out.push({ id: String(e.id), row: Number(e.row), col: Number(e.col) })
            }
            return out
        }
        return null
    }

    readonly property bool customized: !!(toList(Theme.controlItems) || toList(Theme.controlTiles) || toList(Theme.controlSections))
    readonly property var laptopRows: [["clock", "settings", "power"], ["network", "bluetooth", "powermode"],
                                       ["audio"], ["display"], ["keyboard"]]
    readonly property var desktopRows: [["clock"],
        ["network"].concat(hasBluetooth ? ["bluetooth"] : ["themes", "screenshot"]).concat(["settings", "power"]),
        ["audio"], ["display"]]

    function packRows(rows) {
        var out = [], row = 0
        rows.forEach(function (ids) {
            var col = 0
            ids.forEach(function (id) {
                if (!root.itemAvailable(id)) return
                var span = root.spanOf(id)
                if (col + span > root.maxSlots) return
                out.push({ id: id, row: row, col: col })
                col += span
            })
            if (col > 0) row++
        })
        return out
    }

    readonly property var chosenGrid: gridEntries(Theme.controlGrid)
        || (customized ? packGrid(legacyItems.filter(function (id, i, l) { return root.isGrid(id) && l.indexOf(id) === i && root.itemAvailable(id) }))
            : packRows(laptop ? laptopRows : desktopRows))
    readonly property var grid: placeGrid(chosenGrid, undefined, true)
    readonly property var chosenBottom: {
        var list = toList(Theme.controlBottom) || (customized ? legacyItems : ["notifications", "search"])
        var out = []
        list.forEach(function (id) { if (root.isBottom(id) && out.indexOf(id) < 0) out.push(id) })
        return out
    }
    readonly property var bottom: chosenBottom.filter(itemAvailable)

    readonly property var items: grid.map(function (e) { return e.id }).concat(bottom)
    readonly property var tiles: items.filter(isTile)
    readonly property var sections: items.filter(isSection)

    function clockParts(full) {
        if (full) return ["time", "weekday", "day", "month"]
        var out = []
        if (!Theme.clockWeekday) out.push("weekday")
        if (!Theme.clockDay) out.push("day")
        if (!Theme.clockMonth) out.push("month")
        return out
    }

    readonly property bool appsInControl: Theme.backgroundApps && bottom.indexOf("apps") >= 0
    readonly property bool powerModeShown: hasPowerProfiles && Theme.powerMode
    readonly property bool powerInControl: powerModeShown && items.indexOf("powermode") >= 0

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
