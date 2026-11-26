import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "cpu"
    title: "System"
    showHeader: false

    property var info: ({})
    property var gpus: []
    property var ips: []

    Process {
        id: infoProc
        running: true
        command: ["sh", Quickshell.shellPath("scripts/sysinfo.sh"), Quickshell.shellDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = {}, gpus = [], ips = []
                text.split("\n").forEach(function (line) {
                    var tab = line.indexOf("\t")
                    if (tab < 0) return
                    var k = line.substring(0, tab), v = line.substring(tab + 1).trim()
                    if (v === "") return
                    if (k === "gpu") gpus.push(v)
                    else if (k === "ip") ips.push(v)
                    else out[k] = v
                })
                page.info = out
                page.gpus = gpus
                page.ips = ips
            }
        }
    }

    property real uptime: 0
    property var memory: ({ total: 0, used: 0 })
    property var swap: ({ total: 0, used: 0 })
    property var disks: []

    Process {
        id: usageProc
        command: ["sh", "-c",
            'grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree):" /proc/meminfo; cat /proc/uptime;'
            + ' df -B1 -P -T 2>/dev/null | tail -n +2']
        stdout: StdioCollector {
            onStreamFinished: page.parseUsage(text)
        }
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: page.visible
        onTriggered: if (!usageProc.running) usageProc.running = true
    }

    readonly property var diskTypes: ["ext2", "ext3", "ext4", "btrfs", "xfs", "f2fs", "zfs", "bcachefs",
                                      "jfs", "reiserfs", "ntfs", "ntfs3", "fuseblk", "exfat", "vfat"]

    function parseUsage(text) {
        var mem = {}, disks = [], seen = {}
        text.split("\n").forEach(function (line) {
            var m = line.match(/^(\w+):\s+(\d+)/)
            if (m) {
                mem[m[1]] = parseInt(m[2]) * 1024
                return
            }
            var f = line.trim().split(/\s+/)
            if (f.length === 2 && /^[\d.]+$/.test(f[0])) {
                page.uptime = parseFloat(f[0])
                return
            }
            if (f.length < 7) return
            var dev = f[0], type = f[1], mount = f.slice(6).join(" ")
            if (page.diskTypes.indexOf(type) < 0) return
            if (/^\/(boot|efi)(\/|$)/.test(mount) || /^\/(snap|var\/lib)\//.test(mount)) return
            if (seen[dev]) return
            seen[dev] = true
            disks.push({ mount: mount, type: type, total: parseFloat(f[2]), used: parseFloat(f[3]) })
        })
        disks.sort(function (a, b) { return a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount) })
        if (mem.MemTotal) memory = { total: mem.MemTotal, used: mem.MemTotal - (mem.MemAvailable || 0) }
        swap = { total: mem.SwapTotal || 0, used: (mem.SwapTotal || 0) - (mem.SwapFree || 0) }
        page.disks = disks
    }

    function size(bytes) {
        var units = ["B", "KB", "MB", "GB", "TB"], i = 0
        while (bytes >= 1024 && i < units.length - 1) { bytes /= 1024; i++ }
        return (i >= 3 ? bytes.toFixed(bytes >= 100 ? 0 : 1) : Math.round(bytes)) + " " + units[i]
    }

    function duration(seconds) {
        var m = Math.floor(seconds / 60), d = Math.floor(m / 1440), h = Math.floor(m % 1440 / 60)
        m = m % 60
        var time = (h > 0 ? h + " h" : "") + (d === 0 ? (h > 0 ? " " : "") + m + " min" : "")
        if (d === 0) return time
        return d + (d === 1 ? " day" : " days") + (time !== "" ? ", " + time : "")
    }

    readonly property string displays: {
        var mons = Hyprland.monitors.values
        return Quickshell.screens.map(function (s) {
            var hz = ""
            for (var i = 0; i < mons.length; i++) {
                var o = mons[i].lastIpcObject
                if (mons[i].name === s.name && o && o.refreshRate) hz = " @ " + Math.round(o.refreshRate) + " Hz"
            }
            var name = String(s.model || "").trim() || s.name
            return name + " · " + s.width + "×" + s.height + hz
        }).join("\n")
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: !!(battery && battery.ready && battery.isLaptopBattery && battery.isPresent)
    readonly property int batteryPercent: {
        if (!hasBattery) return 0
        var p = battery.percentage
        return Math.round(p > 1 ? p : p * 100)
    }

    readonly property var rows: {
        var t = ThemeManager.find(ThemeManager.current)
        var list = [
            ["OS", info.os],
            ["Host", info.host],
            ["Kernel", info.kernel],
            ["Uptime", uptime > 0 ? duration(uptime) : ""],
            ["Packages", info.packages],
            ["Shell", info.shell],
            ["WM", info.wm],
            [Quickshell.screens.length > 1 ? "Displays" : "Display", displays],
            ["Theme", t ? t.name : ThemeManager.current],
            ["Icons", info.icons],
            ["Font", Theme.fontFamily],
            ["Cursor", info.cursor],
            ["Terminal", info.terminal],
            ["CPU", info.cpu],
            [gpus.length > 1 ? "GPUs" : "GPU", gpus.join("\n")],
            ["Locale", info.locale],
            ["Local IP", ips.join("\n")]
        ]
        return list.filter(function (r) { return r[1] !== undefined && r[1] !== "" })
    }

    Item {
        width: parent.width
        height: hero.implicitHeight + SettingsUi.u(16)

        Column {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            y: SettingsUi.u(8)
            spacing: SettingsUi.u(6)

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: SettingsUi.u(84)
                height: width

                DistroLogo {
                    anchors.fill: parent
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (page.info.user || Quickshell.env("USER")) + "@" + (page.info.hostname || "")
                color: Theme.accent
                font.pixelSize: SettingsUi.u(15)
                font.bold: true
                font.family: Theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: page.info.os || ""
                color: Theme.textSecondary
                font.pixelSize: SettingsUi.u(10)
                font.family: Theme.fontFamily
            }
        }
    }

    Rectangle {
        width: parent.width
        height: infoColumn.implicitHeight + 2 * SettingsUi.u(14)
        radius: SettingsUi.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder

        Column {
            id: infoColumn
            x: SettingsUi.u(16)
            y: SettingsUi.u(14)
            width: parent.width - 2 * SettingsUi.u(16)
            spacing: SettingsUi.u(7)

            Repeater {
                model: page.rows
                delegate: Row {
                    required property var modelData
                    width: infoColumn.width
                    spacing: SettingsUi.u(12)

                    Text {
                        width: SettingsUi.u(78)
                        text: parent.modelData[0]
                        color: Theme.accent
                        font.pixelSize: SettingsUi.u(10)
                        font.weight: Font.DemiBold
                        font.family: Theme.fontFamily
                    }
                    Text {
                        width: parent.width - SettingsUi.u(90)
                        text: parent.modelData[1]
                        color: Theme.text
                        font.pixelSize: SettingsUi.u(10)
                        font.family: Theme.fontFamily
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        lineHeight: 1.1
                    }
                }
            }
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Usage"
    }

    Rectangle {
        width: parent.width
        height: usageColumn.implicitHeight + 2 * SettingsUi.u(14)
        radius: SettingsUi.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder

        Column {
            id: usageColumn
            x: SettingsUi.u(16)
            y: SettingsUi.u(14)
            width: parent.width - 2 * SettingsUi.u(16)
            spacing: SettingsUi.u(12)

            UsageBar {
                visible: page.hasBattery
                title: "Battery"
                value: page.batteryPercent + "%" + (UPower.onBattery ? "" : " · plugged in")
                fraction: page.batteryPercent / 100
                warn: page.batteryPercent <= 15 && UPower.onBattery
            }
            UsageBar {
                title: "Memory"
                value: page.size(page.memory.used) + " / " + page.size(page.memory.total)
                fraction: page.memory.total > 0 ? page.memory.used / page.memory.total : 0
            }
            UsageBar {
                visible: page.swap.total > 0
                title: "Swap"
                value: page.size(page.swap.used) + " / " + page.size(page.swap.total)
                fraction: page.swap.total > 0 ? page.swap.used / page.swap.total : 0
            }
            Repeater {
                model: page.disks
                delegate: UsageBar {
                    required property var modelData
                    title: "Disk (" + modelData.mount + ")"
                    value: page.size(modelData.used) + " / " + page.size(modelData.total) + " · " + modelData.type
                    fraction: modelData.total > 0 ? modelData.used / modelData.total : 0
                }
            }
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Quickshell"
    }

    OptionRow {
        title: Updater.available ? "Update available" : "Quickshell"
        subtitle: {
            var v = Updater.mode === "git" ? "git " + Updater.shortLocal
                : Updater.shortLocal !== "" ? "version " + Updater.shortLocal : "version unknown"
            if (Updater.localDate !== "") v += " · " + Updater.localDate
            if (page.info.quickshell) v += " · Quickshell " + page.info.quickshell
            if (Updater.running) return v + " · updating..."
            if (!Updater.enabled) return v
            if (Updater.state === "error") return v + " · " + Updater.message
            if (Updater.checking) return v + " · checking for updates..."
            if (Updater.checked && Updater.remote === "") return v + " · cannot reach GitHub"
            if (Updater.checked && !Updater.available) return v + " · up to date"
            return v
        }
        info: "Downloads the latest version. Settings, avatar, wallpapers and themes are kept."

        PillButton {
            visible: Updater.enabled || Updater.running
            primary: Updater.available
            busy: Updater.running || Updater.checking
            icon: Updater.available || Updater.running ? "update" : "reboot"
            text: Updater.running ? "Updating" : Updater.available ? "Update" : "Check"
            onClicked: Updater.available ? Updater.update() : Updater.check(true)
        }
    }

    ToggleRow {
        title: "Updates"
        info: "Check GitHub for new versions."
        key: "updates"
        checked: Theme.updates
    }
}
