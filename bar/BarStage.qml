import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs.services
import qs.widgets
import qs.modules
import qs.modules.controlcenter
import qs.modules.media
import qs.modules.system

PanelWindow {
    id: stage

    property var lock: null

    function pickScreen() {
        var list = Quickshell.screens
        for (var j = 0; j < list.length; j++)
            if (Theme.isMonitor(list[j])) return list[j]
        for (var i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i]
        return list.length > 0 ? list[0] : null
    }
    screen: pickScreen()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: panel.wantsKeyboard ? WlrKeyboardFocus.Exclusive
                               : panel.owner !== "" ? WlrKeyboardFocus.OnDemand
                               : WlrKeyboardFocus.None

    readonly property string barEdge: Theme.barPosition
    readonly property bool vertical: Theme.barVertical
    readonly property string style: Theme.barStyle
    readonly property bool floatingBar: style === "floating"
    readonly property bool attachedBar: style === "attached"
    readonly property bool integratedBar: style === "integrated"
    readonly property bool transparentBar: style === "transparent"
    readonly property bool pillsBar: style === "pills" || style === "pillsAttached"
    readonly property bool pillsAttached: style === "pillsAttached"
    readonly property int pillFillet: pillsAttached ? Math.round(Theme.s(10) * Theme.roundness) : 0
    readonly property int pillSpace: Theme.s(8) + 2 * pillFillet
    readonly property bool bareBar: transparentBar || pillsBar
    readonly property bool frameOn: Theme.barFrame
    readonly property int thick: Theme.s(34)
    readonly property int gap: floatingBar || (pillsBar && !pillsAttached) ? Theme.edgeGap
                             : pillsAttached && frameOn && !fullscreen ? frameSize : 0
    readonly property int attachFillet: attachedBar ? Math.round(Theme.s(10) * Theme.roundness) : 0
    readonly property int popupFillet: Math.round(Theme.s(22) * Theme.roundness)
    property int hyprGaps: 0
    property int hyprRounding: 0
    readonly property int windowGaps: Theme.hyprGaps ? Theme.edgeGap : hyprGaps
    readonly property int windowRounding: Theme.hyprRounding ? Theme.radius : hyprRounding
    readonly property int concentric: Math.max(0, windowRounding + windowGaps)
    readonly property int ear: integratedBar && Theme.barCurves && !frameOn ? concentric : 0
    readonly property int frameRadius: Math.min(concentric, alongSize / 4)

    Process {
        id: hyprRead
        command: ["sh", "-c", "hyprctl -j getoption general:gaps_out; echo '---'; hyprctl -j getoption decoration:rounding"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.split("---")
                try {
                    var g = JSON.parse(parts[0])
                    var v = g.int !== undefined ? g.int : parseInt(String(g.css || "0").trim().split(/\s+/)[0])
                    stage.hyprGaps = isNaN(v) ? 0 : v
                } catch (e) {}
                try {
                    var r = JSON.parse(parts[1])
                    stage.hyprRounding = r.int !== undefined ? r.int : 0
                } catch (e) {}
            }
        }
    }
    Timer {
        id: hyprReadLater
        interval: 500
        onTriggered: hyprRead.running = true
    }
    Connections {
        target: Theme
        function onHyprRoundingChanged() { hyprReadLater.restart() }
        function onHyprGapsChanged() { hyprReadLater.restart() }
        function onRadiusChanged() { hyprReadLater.restart() }
        function onEdgeGapChanged() { hyprReadLater.restart() }
    }
    readonly property int itemSize: thick
    readonly property int extent: gap + thick
    readonly property int frameSize: frameOn ? Theme.s(6) : 0

    readonly property var hyprMonitor: Hyprland.monitorFor(stage.screen)
    readonly property bool fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace
                                          && hyprMonitor.activeWorkspace.hasFullscreen)

    function coversBar(o) {
        if (!o.at || !o.size || !hyprMonitor) return false
        var x = o.at[0] - hyprMonitor.x, y = o.at[1] - hyprMonitor.y, w = o.size[0], h = o.size[1]
        var a0 = barStart, a1 = barStart + barLength, d = extent + Theme.s(6)
        var lo = vertical ? y : x, hi = vertical ? y + h : x + w
        if (hi <= a0 || lo >= a1) return false
        if (barEdge === "top") return y < d
        if (barEdge === "bottom") return y + h > height - d
        if (barEdge === "left") return x < d
        return x + w > width - d
    }

    readonly property var workspaceWindows: {
        var r = { covered: false, floating: 0 }
        var ws = hyprMonitor ? hyprMonitor.activeWorkspace : null
        if (!Theme.autoHide || !ws) return r
        var mi = hyprMonitor.lastIpcObject || {}
        var special = mi.specialWorkspace && mi.specialWorkspace.name ? mi.specialWorkspace.name : ""
        var list = Hyprland.toplevels.values
        for (var i = 0; i < list.length; i++) {
            var w = list[i].workspace
            if (w !== ws && !(special !== "" && w && w.name === special)) continue
            var o = list[i].lastIpcObject || {}
            if (o.floating === true) r.floating++
            if (o.floating !== true || coversBar(o)) r.covered = true
        }
        return r
    }
    readonly property bool hasWindows: workspaceWindows.covered

    Timer {
        interval: 200
        repeat: true
        running: Theme.autoHide && stage.workspaceWindows.floating > 0
        onTriggered: Hyprland.refreshToplevels()
    }

    property bool peek: false
    readonly property bool busy: panel.owner !== ""
    readonly property bool revealed: peek || (busy && !panel.place.solo) || (!fullscreen && (!Theme.autoHide || !hasWindows))
    readonly property bool reserving: !fullscreen && !Theme.autoHide

    Timer {
        id: refresh
        interval: 60
        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            if (Theme.autoHide) Hyprland.refreshToplevels()
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name
            if (n === "fullscreen" || n === "workspacev2" || n === "focusedmon" || n === "openwindow"
                || n === "closewindow" || n === "movewindowv2" || n === "activespecial"
                || n === "changefloatingmode" || n === "activewindowv2"
                || n === "createworkspacev2" || n === "destroyworkspacev2"
                || n === "monitoradded" || n === "monitorremoved")
                refresh.restart()
            if (n === "configreloaded") hyprReadLater.restart()
        }
    }
    Component.onCompleted: {
        refresh.restart()
        hyprRead.running = true
    }

    property bool settled: false
    Timer {
        running: true
        interval: 800
        onTriggered: stage.settled = true
    }

    Timer {
        id: peekEnd
        interval: 400
        onTriggered: if (!barHover.hovered && !edgeHover.hovered && !stage.busy) stage.peek = false
    }

    onBusyChanged: if (!busy && peek) peekEnd.restart()

    Timer {
        interval: 500
        repeat: true
        running: stage.peek && !stage.busy
        onTriggered: if (!cursorProc.running) cursorProc.running = true
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!stage.peek || stage.busy || !stage.hyprMonitor) return
                var p
                try { p = JSON.parse(text) } catch (e) { return }
                var x = p.x - stage.hyprMonitor.x, y = p.y - stage.hyprMonitor.y
                var reach = stage.extent + Theme.s(12)
                var inside = x >= 0 && y >= 0 && x < stage.width && y < stage.height
                var near = stage.barEdge === "top" ? y < reach
                         : stage.barEdge === "bottom" ? y > stage.height - reach
                         : stage.barEdge === "left" ? x < reach : x > stage.width - reach
                if (!inside || !near) stage.peek = false
            }
        }
    }

    readonly property real shift: revealed ? 0 : extent + Theme.s(8)
    property real slide: shift
    Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    readonly property real alongSize: vertical ? height : width
    readonly property int sectionPad: Theme.s(6)
    readonly property real contentLength: {
        var l = vertical
            ? startSection.height + centerSection.height + endSection.height
            : startSection.width + centerSection.width + endSection.width
        return l + 4 * sectionPad + 2 * cornerInset + Theme.s(24)
    }
    readonly property real cornerInset: floatingBar ? Math.min(Theme.radius, thick / 2)
                                      : attachedBar ? Math.min(Theme.radius, thick) : 0
    readonly property real barLength: {
        if (integratedBar || transparentBar) return alongSize
        if (pillsAttached) return alongSize - 2 * (frameOn && !fullscreen ? frameSize : 0)
        if (pillsBar) return alongSize - 2 * gap
        var max = alongSize - 2 * (floatingBar ? gap : attachFillet)
        return Math.max(Math.min(contentLength, max), Math.min(max, max * Theme.barLength))
    }
    readonly property real barStart: (alongSize - barLength) / 2

    readonly property rect barRect: {
        var W = width, H = height, t = thick, g = gap, s = slide, a = barStart, l = barLength
        if (barEdge === "top") return Qt.rect(a, g - s, l, t)
        if (barEdge === "bottom") return Qt.rect(a, H - g - t + s, l, t)
        if (barEdge === "left") return Qt.rect(g - s, a, t, l)
        return Qt.rect(W - g - t + s, a, t, l)
    }

    readonly property var alongRange: {
        var inset = cornerInset
        if (integratedBar) inset = frameOn ? frameSize + frameRadius : ear
        return { lo: barStart + inset + popupFillet, hi: barStart + barLength - inset - popupFillet }
    }

    readonly property rect paintBox: {
        var W = width, H = height
        if ((frameOn && !fullscreen) || (Theme.barFused && !bareBar)) return Qt.rect(0, 0, W, H)
        var depth = Math.min(vertical ? W : H, extent + Math.max(attachFillet, ear, Theme.radius) + Theme.s(8))
        if (barEdge === "top") return Qt.rect(0, 0, W, depth)
        if (barEdge === "bottom") return Qt.rect(0, H - depth, W, depth)
        if (barEdge === "left") return Qt.rect(0, 0, depth, H)
        return Qt.rect(W - depth, 0, depth, H)
    }

    readonly property real barInner: barEdge === "top" ? barRect.y + barRect.height
                                   : barEdge === "bottom" ? barRect.y
                                   : barEdge === "left" ? barRect.x + barRect.width
                                   : barRect.x

    readonly property var sections: Controls.barItemsFlat
    readonly property var pillGroups: {
        if (!pillsAttached) return Controls.barPills
        var f = Controls.barItemsFlat
        function one(l) { return l.length > 0 ? [l] : [] }
        return { start: one(f.start), center: one(f.center), end: one(f.end) }
    }

    property var pills: []
    function registerPill(p) {
        var l = pills.slice()
        l.push(p)
        pills = l
    }
    function unregisterPill(p) {
        pills = pills.filter(function (x) { return x !== p })
        hosts.forEach(function (h) {
            if (h.place.pill !== p) return
            if (h.active) h.close(h.owner)
            h.place = { mode: "center" }
        })
    }
    function pillAt(zone, which) {
        var l = pills.filter(function (x) { return x.zone === zone })
        if (l.length === 0) return null
        l.sort(function (a, b) { return a.slot - b.slot })
        if (which === "first") return l[0]
        if (which === "last") return l[l.length - 1]
        return l[Math.floor((l.length - 1) / 2)]
    }
    readonly property var toastHosts: [toastHost, mediaHost, osdHost]
    readonly property var hosts: [panel, toastHost, mediaHost, osdHost]
    function pillBloomed(p) {
        return hosts.some(function (h) { return h.bloomShown && h.place.pill === p })
    }
    function pillOwner(p) {
        for (var i = 0; i < hosts.length; i++) {
            var h = hosts[i]
            if (h.bloomShown && h.place.pill === p) return h.owner !== "" ? h.owner : h.lastOwner
        }
        return ""
    }
    function pillActiveOwner(p) {
        for (var i = 0; i < hosts.length; i++) {
            var h = hosts[i]
            if (h.active && h.pillMode && h.place.pill === p) return h.owner
        }
        return ""
    }
    function pillTakenBy(p, list, except) {
        return list.some(function (h) { return h !== except && pillTaken(p, h) })
    }
    function toastPositionOf(host) {
        if (!Theme.toastSeparate || host === toastHost) return Theme.toastPosition
        return host === mediaHost ? Theme.mediaPosition : Theme.osdPosition
    }
    Connections {
        target: Theme
        function onToastSeparateChanged() {
            stage.toastHosts.forEach(function (h) { if (h.owner !== "") h.close(h.owner) })
        }
    }
    readonly property var mainPanel: panel

    function pillBase(q) {
        var g = q.parent && q.parent.parent ? q.parent.parent : null
        return vertical ? barRect.y + (g ? g.y : 0) + q.y : barRect.x + (g ? g.x : 0) + q.x
    }
    function pillRoom(p) {
        var space = pillSpace, before = 0, after = 0, base = pillBase(p)
        pills.forEach(function (q) {
            if (q === p) return
            var len = (vertical ? q.height : q.width) + space
            if (pillBase(q) < base) before += len
            else after += len
        })
        return { before: before, after: after }
    }
    function pillShift(p) {
        if (pillTakenBy(p, hosts, null)) return 0
        var total = 0, space = pillSpace
        var list = pills.slice().sort(function (a, b) { return pillBase(a) - pillBase(b) })
        hosts.forEach(function (h) {
            if (!(h.active && h.pillMode) || !h.place.pill) return
            var b = h.place.pill, bi = list.indexOf(b), i = list.indexOf(p)
            if (bi < 0 || i < 0) return
            var f = h.bloomFull
            var a0 = vertical ? f.y : f.x, a1 = a0 + (vertical ? f.height : f.width)
            var limit, k, q, qs, qe, sh
            if (i < bi) {
                limit = a0 - space
                for (k = bi - 1; k >= i; k--) {
                    q = list[k]
                    qs = pillBase(q)
                    qe = qs + (vertical ? q.height : q.width)
                    sh = Math.min(0, limit - qe)
                    if (k === i) total += sh
                    limit = qs + sh - space
                }
            } else {
                limit = a1 + space
                for (k = bi + 1; k <= i; k++) {
                    q = list[k]
                    qs = pillBase(q)
                    qe = qs + (vertical ? q.height : q.width)
                    sh = Math.max(0, limit - qs)
                    if (k === i) total += sh
                    limit = qe + sh + space
                }
            }
        })
        return total
    }
    function pillTaken(p, host) {
        return host.active && host.pillMode && host.place.pill === p
    }
    function toastPill(host) {
        var it = registry["notifications"]
        if (it && it.pill && (!Theme.toastSeparate || host === toastHost)) return it.pill
        var pos = toastPositionOf(host)
        var v = pos.indexOf("bottom") === 0 ? "bottom" : "top"
        var h = pos.indexOf("left") >= 0 ? "left" : pos.indexOf("right") >= 0 ? "right" : "center"
        if (!vertical) {
            if (v !== barEdge) return null
            return h === "left" ? pillAt("start", "first") : h === "right" ? pillAt("end", "last") : pillAt("center", "middle")
        }
        if (h !== barEdge) return null
        return v === "top" ? pillAt("start", "first") : pillAt("end", "last")
    }
    readonly property string flushSide: panel.shownBox && panel.place.mode === "fused" ? panel.flush : ""
    readonly property bool squareStart: flushSide === "start"
    readonly property bool squareEnd: flushSide === "end"
    readonly property bool powerOpen: panel.owner === "power" && panel.place.mode === "fused"
    readonly property int notificationCount: notifications.history.count

    property var registry: ({})
    function registerItem(kind, item) {
        var r = Object.assign({}, registry)
        r[kind] = item
        registry = r
    }
    function unregisterItem(kind, item) {
        if (registry[kind] !== item) return
        var r = Object.assign({}, registry)
        delete r[kind]
        registry = r
    }

    readonly property var kindOf: ({
        "control": "clock", "audio": "audio", "wifi": "network", "bluetooth": "bluetooth",
        "display": "display", "sysmon": "sysmon", "inbox": "notifications", "power": "power"
    })

    function anchorHovered(owner) {
        var it = registry[kindOf[owner]]
        return !!(it && it.hovered)
    }

    property var pending: null

    function alongOf(item) {
        var p = item.mapToItem(stage.contentItem, item.width / 2, item.height / 2)
        return vertical ? p.y : p.x
    }

    function placementFor(id, toast, host) {
        if (toast && pillsBar && revealed) {
            var tp = toastPill(host)
            if (tp && !pillTakenBy(tp, hosts, host)) return { mode: "pill", pill: tp }
        }
        if (toast) {
            var pos = toastPositionOf(host)
            var m = windowGaps + Theme.s(14)
            var ins = { top: m + frameSize, bottom: m + frameSize, left: m + frameSize, right: m + frameSize }
            ins[barEdge] = m + extent
            var v = pos.indexOf("bottom") === 0 ? "bottom" : "top"
            var hz = pos.indexOf("left") >= 0 ? "left" : pos.indexOf("right") >= 0 ? "right" : "center"
            toastHosts.forEach(function (o) {
                if (o === host || !o.active || o.place.mode !== "corner" || o.place.v !== v || o.place.h !== hz) return
                ins[v] += o.requestH + Theme.s(10)
            })
            return { mode: "corner", v: v, h: hz,
                     top: ins.top, bottom: ins.bottom, left: ins.left, right: ins.right }
        }
        var hidden = !revealed
        if (pillsBar && id === "launcher") {
            var cp = !vertical && !hidden ? pillAt("center", "middle") : null
            if (cp && !pillTakenBy(cp, toastHosts, null)) return { mode: "pill", pill: cp, keep: false }
            return { mode: "center", solo: hidden }
        }
        if (id === "launcher" && (!Theme.barFused || vertical)) return { mode: "center", solo: hidden }
        var item = pending && pending.id === id ? pending.item : registry[kindOf[id]]
        pending = null
        var along = item && id !== "launcher" ? alongOf(item) : barStart + barLength / 2
        if (vertical && id === "inbox") along = along < barStart + barLength / 2 ? -alongSize : 2 * alongSize
        if (hidden) {
            var rim = fullscreen ? 0 : frameSize
            var edgePos = barEdge === "bottom" ? height - rim : barEdge === "right" ? width - rim : rim
            if (!Theme.barFused)
                return { mode: "anchored", along: along, origin: edgePos, solo: true, gap: Theme.s(8) }
            var rimmed = rim > 0
            return { mode: "fused", origin: edgePos, along: along, solo: true,
                     lo: (rimmed ? rim + frameRadius : 0) + popupFillet,
                     hi: alongSize - (rimmed ? rim + frameRadius : 0) - popupFillet,
                     start: rimmed ? rim - 2 : 0, end: rimmed ? alongSize - rim + 2 : alongSize,
                     ears: rimmed, earSize: rimmed ? frameRadius : 0, straight: !rimmed }
        }
        if (pillsBar && item && item.pill && !pillTakenBy(item.pill, toastHosts, null))
            return { mode: "pill", pill: item.pill, keep: id === "control" }
        if (!Theme.barFused)
            return { mode: "anchored", along: along, origin: barInner, gap: Theme.s(8) }
        var framed = integratedBar && frameOn
        return { mode: "fused", origin: barInner, along: along,
                 lo: alongRange.lo, hi: alongRange.hi,
                 start: framed ? barStart + frameSize - 2 : barStart,
                 end: framed ? barStart + barLength - frameSize + 2 : barStart + barLength,
                 ears: ear > 0 || framed, earSize: framed ? frameRadius : ear,
                 straight: integratedBar && !Theme.barCurves }
    }

    function activate(kind, item) {
        var owners = { "clock": "control", "audio": "audio", "network": Controls.hasWifi ? "wifi" : "control",
                       "bluetooth": "bluetooth", "display": "display", "sysmon": "sysmon",
                       "notifications": "inbox", "power": "power" }
        if (owners[kind]) pending = { id: owners[kind], item: item }
        if (kind === "clock" || (kind === "network" && !Controls.hasWifi)) controlCenter.toggle()
        else if (kind === "audio") audioPanel.toggle()
        else if (kind === "network") wifiPanel.toggle()
        else if (kind === "bluetooth") bluetoothPanel.toggle()
        else if (kind === "display") displayPanel.toggle()
        else if (kind === "sysmon") sysmonPanel.toggle()
        else if (kind === "notifications") inboxPanel.toggle()
        else if (kind === "search") launcher.openMode(0)
        else if (kind === "themes") launcher.openMode(1)
        else if (kind === "power") power.open()
        else if (kind === "logo") Controls.settingsRequested("system")
        if (pending && panel.owner === pending.id) pending = null
    }

    function goToWorkspace(id) {
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
    }

    mask: Region {
        item: barHit
        Region { item: panel.active || panel.shownBox ? panel.frameItem : null }
        Region { item: toastHost.active ? toastHost.frameItem : null }
        Region { item: mediaHost.active ? mediaHost.frameItem : null }
        Region { item: osdHost.active ? osdHost.frameItem : null }
        Region { item: !stage.revealed || stage.peek ? edgeStrip : null }
    }

    Item {
        id: escCatcher
        focus: true
        Keys.onEscapePressed: if (panel.owner !== "") panel.close(panel.owner)
    }

    Item {
        id: pillBlooms
        anchors.fill: parent
        visible: stage.pillsBar

        PillBloom { host: panel; stage: stage }
        PillBloom { host: toastHost; stage: stage }
        PillBloom { host: mediaHost; stage: stage }
        PillBloom { host: osdHost; stage: stage }
    }

    Item {
        id: body
        visible: !stage.bareBar || stage.frameOn
        x: stage.paintBox.x
        y: stage.paintBox.y
        width: stage.paintBox.width
        height: stage.paintBox.height
        layer.enabled: Theme.shadowEnabled && visible
        layer.effect: SoftGlow { drop: !stage.floatingBar }

        Item {
            id: surface
            anchors.fill: parent
            layer.enabled: Theme.glass && visible
            layer.effect: LiquidGlass {
                outside: Qt.vector4d(body.x <= 0 ? 1 : 0, body.y <= 0 ? 1 : 0,
                                     body.x + body.width >= stage.width ? 1 : 0,
                                     body.y + body.height >= stage.height ? 1 : 0)
            }

            Item {
                id: shapes
                x: -body.x
                y: -body.y
                width: stage.width
                height: stage.height

                Item {
                    id: frameShape
                    anchors.fill: parent
                    visible: stage.frameOn && !stage.fullscreen
                    readonly property var ins: {
                        var o = { top: stage.frameSize, bottom: stage.frameSize, left: stage.frameSize, right: stage.frameSize }
                        o[stage.barEdge] = stage.pillsAttached ? stage.frameSize : Math.max(stage.frameSize, stage.thick - stage.slide)
                        return o
                    }
                    readonly property real hole: Math.max(0, Math.min(stage.frameRadius, width / 4, height / 4))
                    readonly property real band: Math.max(width, height)

                    Rectangle {
                        x: frameShape.ins.left - frameShape.band
                        y: frameShape.ins.top - frameShape.band
                        width: frameShape.width - frameShape.ins.left - frameShape.ins.right + 2 * frameShape.band
                        height: frameShape.height - frameShape.ins.top - frameShape.ins.bottom + 2 * frameShape.band
                        radius: frameShape.hole + frameShape.band
                        readonly property real flat: frameShape.band
                        readonly property bool squareTop: stage.pillsAttached && stage.barEdge === "top"
                        readonly property bool squareBottom: stage.pillsAttached && stage.barEdge === "bottom"
                        readonly property bool squareLeft: stage.pillsAttached && stage.barEdge === "left"
                        readonly property bool squareRight: stage.pillsAttached && stage.barEdge === "right"
                        topLeftRadius: squareTop || squareLeft ? flat : radius
                        topRightRadius: squareTop || squareRight ? flat : radius
                        bottomLeftRadius: squareBottom || squareLeft ? flat : radius
                        bottomRightRadius: squareBottom || squareRight ? flat : radius
                        color: "transparent"
                        border.width: frameShape.band
                        border.color: Theme.panel
                    }
                }

                Rectangle {
                    id: barShape
                    visible: stage.floatingBar
                    x: stage.barRect.x
                    y: stage.barRect.y
                    width: stage.barRect.width
                    height: stage.barRect.height
                    radius: Math.min(Theme.radius, height / 2, width / 2)
                    readonly property bool innerStartSquare: stage.squareStart
                    readonly property bool innerEndSquare: stage.squareEnd
                    topLeftRadius: (stage.barEdge === "bottom" || stage.barEdge === "right") && innerStartSquare ? 0 : radius
                    topRightRadius: (stage.barEdge === "bottom" && innerEndSquare) || (stage.barEdge === "left" && innerStartSquare) ? 0 : radius
                    bottomLeftRadius: (stage.barEdge === "top" && innerStartSquare) || (stage.barEdge === "right" && innerEndSquare) ? 0 : radius
                    bottomRightRadius: (stage.barEdge === "top" && innerEndSquare) || (stage.barEdge === "left" && innerEndSquare) ? 0 : radius
                    color: Theme.panel
                    border.width: Theme.glass || Theme.shadowEnabled ? 0 : 1
                    border.color: Theme.border
                }

                FusedShape {
                    visible: stage.attachedBar
                    radiusStart: stage.squareStart ? 0 : Theme.radius
                    radiusEnd: stage.squareEnd ? 0 : Theme.radius
                    edge: stage.barEdge
                    fillet: stage.attachFillet
                    radius: Theme.radius
                    outline: !Theme.shadowEnabled && !Theme.glass
                    x: stage.vertical ? stage.barRect.x - (stage.barEdge === "left" ? 1 : 0) : stage.barRect.x - stage.attachFillet
                    y: stage.vertical ? stage.barRect.y - stage.attachFillet : stage.barRect.y - (stage.barEdge === "top" ? 1 : 0)
                    width: stage.vertical ? stage.barRect.width + 1 : stage.barRect.width + 2 * stage.attachFillet
                    height: stage.vertical ? stage.barRect.height + 2 * stage.attachFillet : stage.barRect.height + 1
                }

                IntegratedShape {
                    visible: stage.integratedBar && (!stage.frameOn || stage.fullscreen)
                    edge: stage.barEdge
                    depth: stage.thick
                    ear: stage.ear
                    earStart: stage.squareStart ? 0 : stage.ear
                    earEnd: stage.squareEnd ? 0 : stage.ear
                    outline: !Theme.shadowEnabled && !Theme.glass
                    readonly property real reach: stage.thick + stage.ear
                    x: stage.barEdge === "right" ? stage.barRect.x + stage.thick - reach : (stage.vertical ? stage.barRect.x : 0)
                    y: stage.barEdge === "bottom" ? stage.barRect.y + stage.thick - reach : (stage.vertical ? 0 : stage.barRect.y)
                    width: stage.vertical ? reach : stage.width
                    height: stage.vertical ? stage.height : reach
                }

                FusedShape {
                    visible: panel.attach !== "none" && panel.shownBox
                    flare: true
                    edge: panel.attach
                    fillet: panel.fillet
                    filletStart: panel.filletStart
                    filletEnd: panel.filletEnd
                    ear: panel.ear
                    earStart: panel.earStart
                    earEnd: panel.earEnd
                    radius: panel.cornerRadius
                    radiusStart: panel.flush === "start" && panel.place.straight ? 0 : panel.cornerRadius
                    radiusEnd: panel.flush === "end" && panel.place.straight ? 0 : panel.cornerRadius
                    outline: !Theme.shadowEnabled && !Theme.glass
                    x: panel.shapeX
                    y: panel.shapeY
                    width: panel.shapeW
                    height: panel.shapeH
                }
            }
        }
    }

    Item {
        id: barHit
        x: stage.barRect.x
        y: stage.barRect.y
        width: stage.barRect.width
        height: stage.barRect.height

        HoverHandler {
            id: barHover
            onHoveredChanged: {
                if (hovered) peekEnd.stop()
                else if (stage.peek) peekEnd.restart()
            }
        }

        Item {
            id: inner
            anchors.fill: parent
            readonly property int pad: stage.pillsBar ? 0 : stage.sectionPad + Math.round(stage.cornerInset * 0.35)

            BarSection {
                id: startSection
                stage: stage
                kinds: stage.pillsBar ? [] : stage.sections.start
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: stage.vertical ? 0 : inner.pad
                y: stage.vertical ? inner.pad : 0
            }
            BarSection {
                id: centerSection
                stage: stage
                kinds: stage.pillsBar ? [] : stage.sections.center
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: stage.vertical ? 0 : (inner.width - width) / 2
                y: stage.vertical ? (inner.height - height) / 2 : 0
            }
            BarSection {
                id: endSection
                stage: stage
                kinds: stage.pillsBar ? [] : stage.sections.end
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: stage.vertical ? 0 : inner.width - width - inner.pad
                y: stage.vertical ? inner.height - height - inner.pad : 0
            }

            BarPills {
                stage: stage
                zone: "start"
                pills: stage.pillsBar ? stage.pillGroups.start : []
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: 0
                y: 0
            }
            BarPills {
                stage: stage
                zone: "center"
                pills: stage.pillsBar ? stage.pillGroups.center : []
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: stage.vertical ? 0 : (inner.width - width) / 2
                y: stage.vertical ? (inner.height - height) / 2 : 0
            }
            BarPills {
                stage: stage
                zone: "end"
                pills: stage.pillsBar ? stage.pillGroups.end : []
                Behavior on x { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: stage.settled; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                x: stage.vertical ? 0 : inner.width - width
                y: stage.vertical ? inner.height - height : 0
            }
        }
    }

    Item {
        id: edgeStrip
        z: -1
        x: stage.barEdge === "right" ? stage.width - width : 0
        y: stage.barEdge === "bottom" ? stage.height - height : 0
        readonly property int depth: stage.peek ? stage.extent : Math.max(3, Theme.s(3))
        width: stage.vertical ? depth : stage.width
        height: stage.vertical ? stage.height : depth
        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (hovered) {
                    peekEnd.stop()
                    stage.peek = true
                } else if (stage.peek) {
                    peekEnd.restart()
                }
            }
        }
    }

    BarPopup {
        id: panel
        anchors.fill: parent
        stage: stage

        Launcher { id: launcher; island: panel }
        PowerMenu { id: power; island: panel; lock: stage.lock }
        SystemMonitorPanel { id: sysmonPanel; island: panel }
        AudioPanel { id: audioPanel; island: panel }
        NotificationsPanel { id: inboxPanel; island: panel; notifications: notifications }
        PagePanel {
            id: wifiPanel
            island: panel
            ownerId: "wifi"
            page: Component { WifiPage {} }
        }
        PagePanel {
            id: bluetoothPanel
            island: panel
            ownerId: "bluetooth"
            page: Component { BluetoothPage {} }
        }
        PagePanel {
            id: displayPanel
            island: panel
            ownerId: "display"
            page: Component { DisplayPage {} }
        }
        ControlCenter {
            id: controlCenter
            island: panel
            launcher: launcher
            notifications: notifications
            power: power
        }
    }

    BarPopup {
        id: toastHost
        anchors.fill: parent
        stage: stage
        toast: true

        Notifications { id: notifications; island: toastHost }
    }

    BarPopup {
        id: mediaHost
        anchors.fill: parent
        stage: stage
        toast: true
    }

    BarPopup {
        id: osdHost
        anchors.fill: parent
        stage: stage
        toast: true
    }

    MediaPlayer {
        island: Theme.toastSeparate ? mediaHost : toastHost
        parent: island.holder
    }

    Osd {
        island: Theme.toastSeparate ? osdHost : toastHost
        parent: island.holder
    }

    HyprlandFocusGrab {
        windows: [stage]
        active: panel.grabReady && panel.grabOwner !== "" && panel.owner === panel.grabOwner
        onCleared: panel.close(panel.grabOwner)
    }
}
