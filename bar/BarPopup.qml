import QtQuick
import qs.services
import qs.widgets

Item {
    id: host

    property var stage: null
    property bool toast: false

    property string owner: ""
    property int requestW: 0
    property int requestH: 0
    property bool wantsKeyboard: false
    property int requestRadius: 0
    property string grabOwner: ""
    property bool grabReady: false
    property bool openHovered: false

    readonly property int topRadius: 0
    readonly property bool floating: true
    readonly property bool vertical: !!stage && stage.vertical && !toast
    readonly property int idleH: Theme.s(30)
    readonly property bool concealed: false
    readonly property bool remapping: false
    readonly property int defaultRadius: Theme.radius
    readonly property int cornerRadius: requestRadius > 0 ? requestRadius : defaultRadius
    readonly property bool hovered: frameHover.hovered || (!!stage && stage.anchorHovered(owner))

    default property alias content: contentHost.data

    property var place: ({ mode: "center", along: 0 })

    function open(id, w, h, keyboard, radius) {
        var isNew = owner !== id
        var fresh = !active
        if (fresh) snap = true
        if (isNew && stage) place = stage.placementFor(id, toast)
        requestW = w
        requestH = h
        lastW = w
        lastH = h
        snap = false
        wantsKeyboard = keyboard === true
        if (radius !== undefined) requestRadius = radius
        else if (isNew) requestRadius = 0
        owner = id
    }

    function close(id) {
        if (owner !== id) return
        owner = ""
        wantsKeyboard = false
    }

    onOwnerChanged: {
        if (owner !== "") lastOwner = owner
        if (owner !== grabOwner) grabOwner = ""
        grabReady = false
    }
    onGrabOwnerChanged: grabReady = false
    Timer {
        interval: 200
        running: host.grabOwner !== "" && host.owner === host.grabOwner && !host.grabReady
        onTriggered: host.grabReady = true
    }

    property int lastW: 0
    property int lastH: 0

    readonly property bool active: owner !== ""
    readonly property string attach: place.mode === "fused" ? stage.barEdge
                                   : place.mode === "top" ? "top" : "none"
    readonly property bool alongX: attach === "top" || attach === "bottom"
    readonly property int fillet: attach !== "none" ? Math.round(Theme.s(22) * Theme.roundness) : 0

    readonly property real alongSizeTarget: alongX ? lastW : lastH
    readonly property string flush: {
        if (place.mode !== "fused" || place.start === undefined) return ""
        if (alongSizeTarget + 2 * fillet > place.hi - place.lo) return ""
        if (place.along - alongSizeTarget / 2 < place.lo) return "start"
        if (place.along + alongSizeTarget / 2 > place.hi) return "end"
        return ""
    }
    readonly property int filletStart: flush === "start" ? 0 : fillet
    readonly property int filletEnd: flush === "end" ? 0 : fillet
    readonly property bool earStart: flush === "start" && !!place.ears
    readonly property bool earEnd: flush === "end" && !!place.ears
    readonly property int ear: earStart || earEnd ? (place.earSize || 0) : 0

    property real animW: active ? requestW : (attach === "left" || attach === "right" ? 0 : lastW)
    property real animH: active ? requestH : (attach === "top" || attach === "bottom" ? 0 : lastH)
    Behavior on animW {
        id: animWBehavior
        enabled: host.attach !== "none"
        NumberAnimation {
            readonly property bool closing: animWBehavior.targetValue <= 1
            duration: closing ? 260 : 340
            easing.type: closing ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 0.8
        }
    }
    Behavior on animH {
        id: animHBehavior
        enabled: host.attach !== "none"
        NumberAnimation {
            readonly property bool closing: animHBehavior.targetValue <= 1
            duration: closing ? 260 : 340
            easing.type: closing ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 0.8
        }
    }

    readonly property real stageW: stage ? stage.width : 0
    readonly property real stageH: stage ? stage.height : 0
    readonly property int margin: Theme.s(8)

    function alongPos(center, size, length) {
        if (flush === "start") return place.start
        if (flush === "end") return place.end - size
        return clampAlong(center, size, length)
    }

    function clampAlong(center, size, length) {
        var lo = margin + fillet, hi = length - margin - fillet
        if (place.lo !== undefined && place.hi !== undefined) {
            lo = place.lo
            hi = place.hi
        }
        if (hi - lo < size) return (lo + hi - size) / 2
        return Math.max(lo, Math.min(hi - size, center - size / 2))
    }

    function anchoredPos(size, length) {
        return Math.max(margin, Math.min(length - margin - size, place.along - size / 2))
    }

    readonly property bool pillMode: place.mode === "pill"
    property bool pillClosing: false
    onActiveChanged: {
        if (active && pillMode) lastFull = bloomFull
        if (!active && pillMode) {
            pillClosing = true
            pillCloseTimer.restart()
        }
    }
    Timer {
        id: pillCloseTimer
        interval: 340
        onTriggered: host.pillClosing = false
    }
    readonly property bool bloomAnimate: pillMode && (active || pillClosing)

    readonly property rect pillRect: {
        var p = place.pill
        if (!pillMode || !p || !stage || typeof p.mapToItem !== "function") return Qt.rect(0, 0, 0, 0)
        var dep = p.x + p.y + p.width + p.height + stage.barRect.x + stage.barRect.y
        if (p.parent) dep += p.parent.x + p.parent.y
        if (p.parent && p.parent.parent) dep += p.parent.parent.x + p.parent.parent.y
        var q = p.mapToItem(stage.contentItem, 0, 0)
        return Qt.rect(q.x, q.y, p.width, p.height)
    }

    readonly property rect pillBox: {
        var p = pillRect, w = lastW, h = lastH, e = stage ? stage.barEdge : "top"
        var keep = !!place.keep
        var room = keep || !place.pill ? { before: 0, after: 0 } : stage.pillRoom(place.pill)
        var gapAlong = stage.gap
        if (e === "top" || e === "bottom") {
            var lo = room.before > 0 ? gapAlong + room.before : margin
            var hi = stageW - (room.after > 0 ? gapAlong + room.after : margin)
            var x = Math.max(lo, Math.min(hi - w, p.x + p.width / 2 - w / 2))
            if (e === "top") return Qt.rect(x, keep ? p.y + p.height : p.y, w, h)
            return Qt.rect(x, keep ? p.y - h : p.y + p.height - h, w, h)
        }
        var lo2 = room.before > 0 ? gapAlong + room.before : margin
        var hi2 = stageH - (room.after > 0 ? gapAlong + room.after : margin)
        var y = Math.max(lo2, Math.min(hi2 - h, p.y + p.height / 2 - h / 2))
        if (e === "left") return Qt.rect(keep ? p.x + p.width : p.x, y, w, h)
        return Qt.rect(keep ? p.x - w : p.x + p.width - w, y, w, h)
    }

    readonly property rect bloomFull: {
        var p = pillRect, b = pillBox
        var x0 = Math.min(p.x, b.x), y0 = Math.min(p.y, b.y)
        return Qt.rect(x0, y0, Math.max(p.x + p.width, b.x + b.width) - x0, Math.max(p.y + p.height, b.y + b.height) - y0)
    }

    property bool snap: false
    property rect lastFull: Qt.rect(0, 0, 0, 0)
    property string lastOwner: ""
    onBloomFullChanged: if (active && pillMode) lastFull = bloomFull
    readonly property rect refFull: active && pillMode ? bloomFull : lastFull
    readonly property bool sizeAnimate: pillMode && !snap

    property real bw: active && pillMode ? bloomFull.width : pillRect.width
    property real bh: active && pillMode ? bloomFull.height : pillRect.height
    Behavior on bw {
        id: bwBehavior
        enabled: host.sizeAnimate
        NumberAnimation {
            readonly property bool closing: bwBehavior.targetValue <= host.pillRect.width + 0.5
            duration: closing ? 320 : 380
            easing.type: Easing.OutBack
            easing.overshoot: closing ? 0.5 : 1.1
        }
    }
    Behavior on bh {
        id: bhBehavior
        enabled: host.sizeAnimate
        NumberAnimation {
            readonly property bool closing: bhBehavior.targetValue <= host.pillRect.height + 0.5
            duration: closing ? 320 : 380
            easing.type: Easing.OutBack
            easing.overshoot: closing ? 0.5 : 1.1
        }
    }

    readonly property rect bloomRect: {
        var p = pillRect, f = refFull, e = stage ? stage.barEdge : "top"
        var w = Math.max(0, bw), h = Math.max(0, bh)
        if (e === "top" || e === "bottom") {
            var span = f.width - p.width
            var t = Math.abs(span) > 0.5 ? (w - p.width) / span : 1
            var pc = p.x + p.width / 2, fc = f.x + f.width / 2
            var cx = pc + (fc - pc) * t
            return Qt.rect(cx - w / 2, e === "top" ? p.y : p.y + p.height - h, w, h)
        }
        var span2 = f.height - p.height
        var t2 = Math.abs(span2) > 0.5 ? (h - p.height) / span2 : 1
        var pc2 = p.y + p.height / 2, fc2 = f.y + f.height / 2
        var cy = pc2 + (fc2 - pc2) * t2
        return Qt.rect(e === "left" ? p.x : p.x + p.width - w, cy - h / 2, w, h)
    }
    readonly property real pillRadius: stage && stage.pillsAttached ? Theme.radius : Theme.round(Math.min(pillRect.width, pillRect.height))
    readonly property real bloomRadius: active && pillMode ? cornerRadius : pillRadius
    readonly property bool bloomShown: bloomAnimate
    readonly property rect bloomFrame: {
        var r = bloomRect, p = pillRect, e = stage ? stage.barEdge : "top"
        if (!place.keep) return r
        if (e === "top") return Qt.rect(r.x, p.y + p.height, r.width, Math.max(0, r.y + r.height - p.y - p.height))
        if (e === "bottom") return Qt.rect(r.x, r.y, r.width, Math.max(0, p.y - r.y))
        if (e === "left") return Qt.rect(p.x + p.width, r.y, Math.max(0, r.x + r.width - p.x - p.width), r.height)
        return Qt.rect(r.x, r.y, Math.max(0, p.x - r.x), r.height)
    }

    readonly property real boxX: {
        if (pillMode) return pillBox.x
        if (place.mode === "center") return (stageW - animW) / 2
        if (place.mode === "anchored")
            return stage.barEdge === "left" ? place.origin + place.gap
                 : stage.barEdge === "right" ? place.origin - place.gap - lastW
                 : anchoredPos(lastW, stageW)
        if (place.mode === "corner")
            return place.h === "left" ? place.left
                 : place.h === "right" ? stageW - place.right - lastW
                 : (stageW - lastW) / 2
        if (attach === "left") return place.origin
        if (attach === "right") return place.origin - animW
        return alongPos(place.along, animW, stageW)
    }
    readonly property real boxY: {
        if (pillMode) return pillBox.y
        if (place.mode === "center") return Math.max(margin, (stageH - lastH) / 2 - stageH * 0.08)
        if (place.mode === "anchored")
            return stage.barEdge === "top" ? place.origin + place.gap
                 : stage.barEdge === "bottom" ? place.origin - place.gap - lastH
                 : anchoredPos(lastH, stageH)
        if (place.mode === "corner")
            return place.v === "top" ? place.top : stageH - place.bottom - lastH
        if (attach === "top") return place.origin
        if (attach === "bottom") return place.origin - animH
        return alongPos(place.along, animH, stageH)
    }

    readonly property bool shownBox: pillMode ? bloomShown : attach !== "none" ? animW > 1 && animH > 1 : active
    readonly property real shapeX: alongX ? boxX - filletStart
        : (attach === "right" ? boxX - ear : boxX - 1)
    readonly property real shapeY: alongX ? (attach === "bottom" ? boxY - ear : boxY - 1) : boxY - filletStart
    readonly property real shapeW: alongX ? animW + filletStart + filletEnd : animW + 1 + ear
    readonly property real shapeH: alongX ? animH + 1 + ear : animH + filletStart + filletEnd

    Item {
        id: plain
        visible: host.attach === "none" && !host.pillMode
        x: host.boxX
        y: host.boxY
        width: host.lastW
        height: host.lastH
        opacity: host.active ? 1 : 0
        scale: host.active ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        layer.enabled: Theme.shadowEnabled
        layer.effect: SoftGlow {}

        GlassRect {
            anchors.fill: parent
            radius: Math.min(host.cornerRadius, height / 2, width / 2)
        }
    }

    Item {
        id: frame
        x: host.pillMode ? host.bloomFrame.x : host.attach === "none" ? plain.x : host.boxX
        y: host.pillMode ? host.bloomFrame.y : host.attach === "none" ? plain.y : host.boxY
        width: host.pillMode ? host.bloomFrame.width : host.attach === "none" ? plain.width : host.animW
        height: host.pillMode ? host.bloomFrame.height : host.attach === "none" ? plain.height : host.animH
        visible: host.pillMode ? host.bloomShown : host.attach === "none" ? plain.opacity > 0 : host.shownBox
        scale: !host.pillMode && host.attach === "none" ? plain.scale : 1
        clip: host.pillMode

        HoverHandler { id: frameHover }

        Item {
            id: contentHost
            width: frame.width
            height: frame.height
            clip: true
        }
    }

    readonly property Item frameItem: frame
}
