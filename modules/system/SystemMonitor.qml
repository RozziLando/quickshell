import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.services

// Monitor di sistema: batteria (tempo alla carica / rimanente), CPU, RAM,
// GPU e temperature. Legge solo file del kernel (/proc, /sys), presenti su ogni
// distro, e solo mentre è visibile.
Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    // Aggiorna i valori solo mentre è aperto
    property bool active: visible

    implicitHeight: column.implicitHeight

    // ---------- Batteria (UPower) ----------
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: !!(dev && dev.ready && dev.isLaptopBattery && dev.isPresent)
    readonly property int batteryPercent: {
        if (!hasBattery) return 0
        var p = dev.percentage
        return Math.round(p > 1 ? p : p * 100)
    }
    readonly property bool plugged: hasBattery && !UPower.onBattery
    readonly property bool charging: hasBattery && (dev.state === UPowerDeviceState.Charging
                                                    || dev.state === UPowerDeviceState.PendingCharge)

    function duration(seconds) {
        var m = Math.round(seconds / 60)
        var h = Math.floor(m / 60)
        m = m % 60
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }

    // ---------- Consumo medio a batteria ----------
    // Da collegato la batteria non si scarica, quindi UPower non può stimare
    // la durata. Mentre sei a batteria la shell registra il consumo medio
    // (media mobile, ogni 30 s) e lo salva; da collegato la stima è
    // energia nella batteria / consumo medio.
    FileView {
        id: usageFile
        path: Quickshell.statePath("battery.json")
        onLoadFailed: error => writeAdapter()
        adapter: JsonAdapter {
            id: usage
            property real avgRate: 0    // watt
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.hasBattery && UPower.onBattery
        onTriggered: {
            var rate = Math.abs(root.dev.changeRate)
            if (rate < 0.5) return      // letture non affidabili
            usage.avgRate = usage.avgRate > 0 ? usage.avgRate * 0.9 + rate * 0.1 : rate
            usageFile.writeAdapter()
        }
    }

    readonly property string pluggedEstimate: {
        if (!hasBattery || usage.avgRate < 0.5 || dev.energy <= 0) return ""
        return "~" + duration(dev.energy / usage.avgRate * 3600) + " on battery"
    }

    readonly property string batteryText: {
        if (!hasBattery) return ""
        if (charging)
            return dev.timeToFull > 0 ? "Full in " + duration(dev.timeToFull) : "Charging"
        if (plugged) return pluggedEstimate !== "" ? pluggedEstimate : "Plugged in"
        // Stime oltre 2 giorni non sono affidabili
        if (dev.timeToEmpty > 0 && dev.timeToEmpty < 2 * 24 * 3600)
            return duration(dev.timeToEmpty)
        return "On battery"
    }

    // ---------- Sensori di temperatura (hwmon) ----------
    // Riconosce i driver standard: CPU Intel/AMD/ARM, GPU, batteria
    property var sensors: []   // [{ label, path }]

    Process {
        id: sensorProc
        running: true
        command: ["sh", "-c",
            'for h in /sys/class/hwmon/hwmon*; do'
            + ' n=$(cat "$h/name" 2>/dev/null) || continue; f="$h/temp1_input";'
            + ' [ -f "$f" ] || continue;'
            + ' case "$n" in'
            + '  coretemp|k10temp|zenpower|cpu_thermal|soc_thermal) echo "CPU\t$f";;'
            + '  amdgpu|nouveau|radeon) echo "GPU\t$f";;'
            + '  BAT*) echo "Battery\t$f";;'
            + ' esac; done']
        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {}, out = []
                text.split("\n").forEach(function (line) {
                    var p = line.split("\t")
                    if (p.length < 2 || seen[p[0]]) return
                    seen[p[0]] = true
                    out.push({ label: p[0], path: p[1] })
                })
                // Ordine fisso: CPU, GPU, batteria
                var order = ["CPU", "GPU", "Battery"]
                out.sort(function (a, b) { return order.indexOf(a.label) - order.indexOf(b.label) })
                root.sensors = out
            }
        }
    }

    // ---------- Fisso o portatile ----------
    // Portatile: batteria + temperature di CPU e batteria.
    // Fisso: uso della GPU + temperature di CPU e GPU.
    readonly property bool desktop: !hasBattery

    // ---------- GPU (solo fisso; una sola: prima la dedicata) ----------
    // "nvidia": nvidia-smi (driver proprietario)
    // "busy":   AMD, percentuale del kernel (gpu_busy_percent)
    // "rc6":    Intel, tempo a riposo (rc6/idle residency): uso = 1 - riposo
    // ""        nessuna fonte: la riga non compare
    property string gpuKind: ""
    property string gpuPath: ""

    Process {
        id: gpuProc
        running: true
        command: ["sh", "-c",
            'if nvidia-smi -L >/dev/null 2>&1; then echo nvidia; exit; fi;'
            + ' for c in /sys/class/drm/card[0-9]*; do'
            + '  f="$c/device/gpu_busy_percent"; [ -f "$f" ] && { echo "busy\t$f"; exit; };'
            + ' done;'
            + ' for c in /sys/class/drm/card[0-9]*; do'
            + '  for f in "$c/gt/gt0/rc6_residency_ms" "$c/device/tile0/gt0/gtidle/idle_residency_ms"; do'
            + '   [ -f "$f" ] && { echo "rc6\t$f"; exit; };'
            + '  done;'
            + ' done']
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split("\t")
                root.gpuKind = p[0] || ""
                root.gpuPath = p[1] || ""
            }
        }
    }

    // Comando che stampa "gpu:<valore>" (in coda alle altre letture)
    readonly property string gpuCmd: !desktop ? ''
        : gpuKind === "nvidia"
        ? ' echo "gpu:$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)";'
        : gpuKind !== "" ? ' echo "gpu:$(cat \'' + gpuPath + '\' 2>/dev/null)";' : ''

    property real gpu: 0            // 0..1
    property bool gpuReady: false
    property int gpuTemp: -1        // solo NVIDIA (le altre hanno il sensore hwmon)
    property var lastRc6: null      // { value, time } per Intel

    // ---------- CPU, RAM e temperature ----------
    property real cpu: 0          // 0..1
    property bool cpuReady: false // servono due letture per calcolarla
    property real ramUsed: 0      // GB
    property real ramTotal: 0     // GB
    property var temps: ({})      // { etichetta: gradi }
    property var lastCpu: null    // ultima lettura di /proc/stat

    Process {
        id: statProc
        command: ["sh", "-c",
            'head -n 1 /proc/stat; grep -E "^(MemTotal|MemAvailable):" /proc/meminfo;'
            + ' for f in "$@"; do cat "$f" 2>/dev/null || echo -; done;' + root.gpuCmd, "sh"]
            .concat(root.sensors.map(function (s) { return s.path }))
        stdout: StdioCollector {
            onStreamFinished: root.parseStats(text)
        }
    }

    function parseStats(text) {
        var lines = text.trim().split("\n")
        if (lines.length < 3) return

        // CPU: differenza tra due letture di /proc/stat
        var f = lines[0].trim().split(/\s+/).slice(1).map(Number)
        var idle = f[3] + (f[4] || 0)
        var total = f.reduce(function (a, b) { return a + b }, 0)
        if (lastCpu && total > lastCpu.total) {
            cpu = 1 - (idle - lastCpu.idle) / (total - lastCpu.total)
            cpuReady = true
        }
        lastCpu = { idle: idle, total: total }

        // RAM: usata = totale - disponibile
        var memTotal = parseInt(lines[1].split(/\s+/)[1])
        var memAvail = parseInt(lines[2].split(/\s+/)[1])
        ramTotal = memTotal / 1048576
        ramUsed = (memTotal - memAvail) / 1048576

        // Temperature (millesimi di grado), per etichetta
        var t = {}
        for (var i = 0; i < sensors.length; i++) {
            var v = parseInt(lines[3 + i])
            if (!isNaN(v)) t[sensors[i].label] = Math.round(v / 1000)
        }

        // GPU (ultima riga, "gpu:...")
        var g = lines.filter(function (l) { return l.indexOf("gpu:") === 0 })[0]
        if (g !== undefined) {
            g = g.substring(4).trim()
            if (gpuKind === "nvidia") {
                var parts = g.split(",")
                var util = parseFloat(parts[0]), temp = parseInt(parts[1])
                if (!isNaN(util)) { gpu = util / 100; gpuReady = true }
                gpuTemp = isNaN(temp) ? -1 : temp
            } else if (gpuKind === "busy") {
                var b = parseFloat(g)
                if (!isNaN(b)) { gpu = b / 100; gpuReady = true }
            } else if (gpuKind === "rc6") {
                var rc6Idle = parseFloat(g), now = Date.now()
                if (!isNaN(rc6Idle)) {
                    if (lastRc6 && now > lastRc6.time) {
                        var busy = 1 - (rc6Idle - lastRc6.value) / (now - lastRc6.time)
                        gpu = Math.max(0, Math.min(1, busy))
                        gpuReady = true
                    }
                    lastRc6 = { value: rc6Idle, time: now }
                }
            }
        }
        temps = t
    }

    // Riquadri delle temperature: sensori hwmon + GPU NVIDIA (che non ne ha)
    readonly property var tempCards: {
        var out = sensors.map(function (s) {
            return { label: s.label, value: temps[s.label] !== undefined ? temps[s.label] : null }
        })
        // Portatile: CPU e batteria; fisso: CPU e GPU
        out = out.filter(function (c) { return c.label !== (desktop ? "Battery" : "GPU") })
        var hasGpu = out.some(function (c) { return c.label === "GPU" })
        if (desktop && gpuKind === "nvidia" && !hasGpu)
            out.push({ label: "GPU", value: gpuTemp >= 0 ? gpuTemp : null })
        var order = ["CPU", "GPU", "Battery"]
        out.sort(function (a, b) { return order.indexOf(a.label) - order.indexOf(b.label) })
        return out
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: statProc.running = true
    }

    // ---------- Interfaccia ----------
    // Riga: titolo a sinistra, valore a destra, barra sotto (opzionale)
    component StatRow: Column {
        id: stat
        property string title: ""
        property string value: ""
        property real fraction: -1    // -1 = niente barra
        property bool warn: false
        width: parent ? parent.width : 0
        spacing: Theme.s(4)

        Item {
            width: parent.width
            height: titleText.implicitHeight

            Text {
                id: titleText
                text: stat.title
                color: Theme.textSecondary
                font.pixelSize: Theme.s(10)
                font.family: Theme.fontFamily
            }
            Text {
                anchors.right: parent.right
                text: stat.value
                color: stat.warn ? Theme.warning : Theme.text
                font.pixelSize: Theme.s(10)
                font.bold: true
                font.family: Theme.fontFamily
            }
        }

        Rectangle {
            visible: stat.fraction >= 0
            width: parent.width
            height: Theme.s(5)
            radius: height / 2
            color: Theme.track

            Rectangle {
                height: parent.height
                radius: height / 2
                width: parent.width * Math.max(0, Math.min(1, stat.fraction))
                color: stat.warn ? Theme.warning : Theme.accent
                Behavior on width { NumberAnimation { duration: 400 } }
            }
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: root.u(10)

        StatRow {
            visible: root.hasBattery
            title: "Battery"
            value: root.batteryPercent + "% · " + root.batteryText
            fraction: root.batteryPercent / 100
            warn: root.batteryPercent <= 15 && !root.plugged
        }

        StatRow {
            title: "CPU"
            value: root.cpuReady ? Math.round(root.cpu * 100) + "%" : "--"
            fraction: root.cpu
            warn: root.cpu > 0.9
        }

        StatRow {
            visible: root.desktop && root.gpuKind !== ""
            title: "GPU"
            value: root.gpuReady ? Math.round(root.gpu * 100) + "%" : "--"
            fraction: root.gpu
            warn: root.gpu > 0.9
        }

        StatRow {
            title: "RAM"
            value: root.ramUsed.toFixed(1) + " / " + root.ramTotal.toFixed(1) + " GB"
            fraction: root.ramTotal > 0 ? root.ramUsed / root.ramTotal : 0
            warn: root.ramTotal > 0 && root.ramUsed / root.ramTotal > 0.9
        }

        // Temperature, una accanto all'altra
        Row {
            visible: root.tempCards.length > 0
            width: parent.width
            spacing: root.u(8)

            Repeater {
                model: root.tempCards
                delegate: Rectangle {
                    required property var modelData
                    // Valore letto (null finché non arriva la prima lettura)
                    readonly property bool hot: modelData.value !== null && modelData.value >= 85
                    width: (parent.width - root.u(8) * (root.tempCards.length - 1)) / root.tempCards.length
                    height: root.u(34)
                    radius: root.u(10)
                    color: Theme.card
                    border.width: 1
                    border.color: Theme.cardBorder

                    Column {
                        anchors.centerIn: parent
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Theme.textSecondary
                            font.pixelSize: Theme.s(8)
                            font.family: Theme.fontFamily
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.value !== null ? modelData.value + "°C" : "--"
                            color: hot ? Theme.warning : Theme.text
                            font.pixelSize: Theme.s(11)
                            font.bold: true
                            font.family: Theme.fontFamily
                        }
                    }
                }
            }
        }
    }
}
