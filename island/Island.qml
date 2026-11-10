import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.widgets

PanelWindow {
    id: win
    function pickScreen() {
        var list = Quickshell.screens
        var wanted = Theme.monitor
        if (wanted !== "")
            for (var j = 0; j < list.length; j++)
                if (list[j].name === wanted) return list[j]
        for (var i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i]
        return list.length > 0 ? list[0] : null
    }
    property var preferredScreen: pickScreen()
    screen: preferredScreen
    reloadableId: "island-" + (preferredScreen ? preferredScreen.name : "none")
    anchors.top: true

    property bool remapping: false
    visible: !remapping
    property var lastScreen: null
    Connections {
        target: Quickshell
        function onScreensChanged() { screenCheck.restart() }
    }
    Connections {
        target: Theme
        function onMonitorChanged() { screenCheck.restart() }
    }
    Timer {
        id: screenCheck
        interval: 50
        onTriggered: win.checkScreen()
    }
    function checkScreen() {
        var list = Quickshell.screens, present = false
        for (var i = 0; i < list.length; i++)
            if (list[i] === win.lastScreen) present = true
        var next = pickScreen()
        var moved = !present || next !== win.lastScreen
        win.lastScreen = next
        if (!moved) return
        remapGuard.restart()
        win.grabReady = false
        win.remapping = true
        win.preferredScreen = next
        Qt.callLater(function () { win.remapping = false })
    }
    Timer {
        id: remapGuard
        interval: 800
    }

    default property alias content: contentHost.data

    readonly property int idleW: floating ? Theme.s(112)
        : minimal && !revealed ? Theme.s(150) : Theme.s(172)
    readonly property int idleH: Theme.s(30)
    readonly property int maxW: Theme.s(800)
    readonly property int maxH: Theme.s(480)

    readonly property bool floating: Theme.floatingIsland

    readonly property bool minimal: Theme.minimalIsland
    readonly property bool pointerNear: hoverHandler.hovered || leftNear.hovered || rightNear.hovered
    property bool revealBlocked: false
    onPointerNearChanged: {
        if (!pointerNear && owner === "") revealBlocked = false
        if (pointerNear) peekEnd.stop()
        else if (peek) peekEnd.restart()
    }
    readonly property bool revealWanted: minimal && owner === "" && !concealed
        && pointerNear && !revealBlocked
    property bool revealed: false
    onRevealWantedChanged: {
        if (revealWanted) {
            hideIcons.stop()
            revealed = true
        } else {
            hideIcons.restart()
        }
    }
    Timer {
        id: hideIcons
        interval: 350
        onTriggered: win.revealed = false
    }
    readonly property bool iconsShown: !minimal || revealed

    signal clockClicked()
    readonly property int topGap: floating ? Theme.s(5) : 0

    readonly property int topRadius: Theme.s(10)
    readonly property int sideSize: floating ? idleH - Theme.s(4) : Theme.s(28)
    readonly property real sideIconScale: floating ? 0.82 : 1
    readonly property int sideGap: Theme.s(11)
    readonly property int sideReach: Theme.s(28)
    readonly property int sideShift: Theme.s(4)
    readonly property int sideZoneH: topGap + idleH + Theme.s(6)
    readonly property bool sidesShown: floating && !concealed && iconsShown && appeared

    property bool appeared: false
    property bool startupDrop: false
    Timer {
        interval: 450
        running: true
        onTriggered: {
            win.startupDrop = true
            win.appeared = true
            dropDone.start()
        }
    }
    Timer {
        id: dropDone
        interval: 500
        onTriggered: win.startupDrop = false
    }

    signal leftClicked()
    signal rightClicked()

    property string owner: ""
    property int requestW: 0
    property int requestH: 0
    property bool wantsKeyboard: false
    property bool fullscreen

    readonly property bool concealed: fullscreen || (autoHidden && !peek)
    readonly property bool hotspotActive: fullscreen || (autoHidden && !minimal)

    readonly property bool hiddenMode: concealed && owner === ""

    readonly property int targetW: owner === "" ? idleW : Math.min(requestW, maxW)
    readonly property int targetH: owner === ""
        ? (hiddenMode && !floating ? 0 : idleH)
        : Math.min(requestH, maxH)

    property bool hovered: hoverHandler.hovered || (hotspotActive && hotspotHover.hovered)

    readonly property int edgeH: Math.max(3, Theme.s(4))
    readonly property bool edgeHovered: edgeHover.hovered || (hotspotActive && hotspotHover.hovered)
    readonly property bool openHovered: minimal ? false
        : floating ? hovered : (edgeHovered || clockHover.hovered)
    readonly property int inlineIconPad: Theme.s(8)

    readonly property int defaultRadius: Theme.s(15)
    property int requestRadius: 0
    readonly property int cornerRadius: owner !== "" && requestRadius > 0 ? requestRadius : defaultRadius

    function open(id, w, h, keyboard, radius) {
        var isNew = owner !== id
        owner = id
        requestW = w
        requestH = h
        wantsKeyboard = keyboard === true
        if (radius !== undefined) requestRadius = radius
        else if (isNew) requestRadius = 0
        if (isNew) escCatcher.forceActiveFocus()
    }

    function close(id) {
        if (owner !== id) return
        owner = ""
        wantsKeyboard = false
    }

    implicitWidth: maxW
    implicitHeight: maxH
    color: "transparent"
    readonly property int reservedHeight: topGap + idleH
    exclusiveZone: !concealed && (!autoHide || peek) ? reservedHeight : 0

    mask: Region {
        item: pill
        Region { item: win.hotspotActive ? hotspot : null }
        Region { item: win.sidesShown ? leftZone : null }
        Region { item: win.sidesShown ? rightZone : null }
        Region { item: win.sidesShown ? leftSide : null }
        Region { item: win.sidesShown ? rightSide : null }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: wantsKeyboard ? WlrKeyboardFocus.Exclusive
                               : owner !== "" ? WlrKeyboardFocus.OnDemand
                               : WlrKeyboardFocus.None

    Item {
        id: escCatcher
        focus: true
        Keys.onEscapePressed: if (win.owner !== "") win.close(win.owner)
    }

    readonly property var hyprMonitor: Hyprland.monitorFor(win.screen)
    fullscreen: !!(hyprMonitor && hyprMonitor.activeWorkspace
                   && hyprMonitor.activeWorkspace.hasFullscreen)

    Timer {
        id: fsDebounce
        interval: 50
        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            if (win.autoHide) Hyprland.refreshToplevels()
        }
    }

    readonly property bool autoHide: Theme.autoHide

    function coversIsland(o) {
        if (!o.at || !o.size || !hyprMonitor) return false
        var screenW = win.screen ? win.screen.width : win.width
        var reach = (floating ? (Theme.s(112) / 2 - topRadius + sideGap + sideSize + sideReach)
                              : Theme.s(172) / 2 - topRadius) + Theme.s(6)
        var left = screenW / 2 - reach, right = screenW / 2 + reach
        var bottom = sideZoneH
        var x = o.at[0] - hyprMonitor.x, y = o.at[1] - hyprMonitor.y
        return x < right && x + o.size[0] > left && y < bottom && y + o.size[1] > 0
    }

    readonly property var workspaceWindows: {
        var r = { covered: false, floating: 0 }
        var ws = hyprMonitor ? hyprMonitor.activeWorkspace : null
        if (!autoHide || !ws) return r
        var mi = hyprMonitor.lastIpcObject || {}
        var special = mi.specialWorkspace && mi.specialWorkspace.name ? mi.specialWorkspace.name : ""
        var list = Hyprland.toplevels.values
        for (var i = 0; i < list.length; i++) {
            var w = list[i].workspace
            if (w !== ws && !(special !== "" && w && w.name === special)) continue
            var o = list[i].lastIpcObject || {}
            if (o.floating === true) r.floating++
            if (o.floating !== true || coversIsland(o)) r.covered = true
        }
        return r
    }
    readonly property bool autoHidden: workspaceWindows.covered

    property bool edgeStripHovered: false
    property bool peek: false
    onEdgeStripHoveredChanged: {
        if (edgeStripHovered) {
            peekEnd.stop()
            peek = true
        } else if (peek) {
            peekEnd.restart()
        }
    }
    onAutoHiddenChanged: if (!autoHidden) peek = false
    Timer {
        id: peekEnd
        interval: 150
        onTriggered: if (!win.edgeStripHovered && !win.pointerNear) win.peek = false
    }

    Timer {
        interval: 200
        repeat: true
        running: win.autoHide && win.workspaceWindows.floating > 0
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name
            if (n === "fullscreen" || n === "workspacev2"
                || n === "activewindowv2" || n === "focusedmon"
                || n === "movewindowv2" || n === "closewindow"
                || n === "openwindow" || n === "changefloatingmode"
                || n === "activespecial"
                || n === "monitoradded" || n === "monitorremoved")
                fsDebounce.restart()
        }
    }

    Component.onCompleted: {
        preferredScreen = pickScreen()
        lastScreen = preferredScreen
        fsDebounce.restart()
    }
    onAutoHideChanged: fsDebounce.restart()

    readonly property int hotspotWidth: Theme.s(300)
    Item {
        id: hotspot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: win.hotspotWidth
        height: Math.max(4, Theme.s(4))

        HoverHandler { id: hotspotHover }
    }

    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.targetW
        height: win.targetH

        y: !win.appeared || (win.floating && win.hiddenMode)
           ? -(height + win.topGap + Theme.s(6)) : win.topGap
        Behavior on y {
            NumberAnimation {
                duration: win.startupDrop ? 420 : 280
                easing.type: win.startupDrop ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 0.8
            }
        }

        visible: height > 1 && y + height > 0

        Behavior on width {
            id: widthBehavior
            NumberAnimation {
                readonly property bool closing: widthBehavior.targetValue <= win.idleW
                duration: win.hiddenMode ? 280 : (closing ? 320 : 380)
                easing.type: win.hiddenMode ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: closing ? 0.5 : 1.1
            }
        }
        Behavior on height {
            id: heightBehavior
            NumberAnimation {
                readonly property bool closing: heightBehavior.targetValue <= win.idleH
                duration: win.hiddenMode ? 280 : (closing ? 320 : 380)
                easing.type: win.hiddenMode ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: closing ? 0.5 : 1.1
            }
        }

        HoverHandler { id: hoverHandler }

        IslandShape {
            visible: !win.floating
            outline: !Theme.shadowEnabled || Theme.glass
            layer.enabled: Theme.shadowEnabled
            layer.effect: SoftGlow {}
            anchors.fill: parent
            anchors.topMargin: -2
            topRadius: win.topRadius
            bottomRadius: win.cornerRadius
        }

        Rectangle {
            visible: win.floating
            x: win.topRadius
            width: parent.width - 2 * win.topRadius
            height: parent.height
            radius: Math.min(height / 2, win.cornerRadius)
            color: Theme.panel
            border.width: Theme.glass ? 1 : (Theme.shadowEnabled ? 0 : 1)
            border.color: Theme.glass ? Theme.glassEdge : Theme.border
            layer.enabled: Theme.shadowEnabled
            layer.effect: SoftGlow {}

            Rectangle {
                visible: Theme.glass
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.glassSheen }
                    GradientStop { position: 0.45; color: "transparent" }
                }
            }
        }

        Item {
            id: contentHost
            anchors.fill: parent
            clip: true
        }

        Item {
            width: parent.width
            height: win.edgeH
            z: 10
            enabled: win.owner === ""
            HoverHandler { id: edgeHover }
        }

        Item {
            x: win.topRadius + win.inlineIconPad + win.idleH
            width: Math.max(0, parent.width - 2 * x)
            height: parent.height
            enabled: win.owner === ""
            HoverHandler { id: clockHover }
        }

        MouseArea {
            anchors.fill: parent
            enabled: win.minimal && win.owner === ""
            visible: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: win.clockClicked()
        }

        Item {
            id: inlineIcons
            readonly property bool shown: !win.floating && win.owner === "" && !win.concealed
                                          && win.iconsShown
            anchors.fill: parent
            visible: shown
            FadeIn { active: inlineIcons.shown; pause: 100; duration: 250 }

            Item {
                x: win.topRadius + win.inlineIconPad
                y: -Theme.s(1)
                width: win.idleH
                height: win.idleH
                AudioIndicator {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.85
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.leftClicked()
                }
            }

            Item {
                x: parent.width - win.topRadius - win.inlineIconPad - width
                y: -Theme.s(1)
                width: win.idleH
                height: win.idleH
                BatteryIndicator {
                    anchors.centerIn: parent
                    width: parent.width * 0.85
                    height: parent.height * 0.85
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.rightClicked()
                }
            }
        }
    }

    function sideOffset(hover, zone, center) {
        if (!hover.hovered) return 0
        var d = (hover.point.position[zone] - center) * 0.15
        return Math.max(-sideShift, Math.min(sideShift, d))
    }

    Item {
        id: leftZone
        x: leftSide.anchorX - win.sideSize - win.sideReach
        width: win.sideSize + 2 * win.sideReach
        height: win.sideZoneH
        HoverHandler { id: leftNear }
    }

    Item {
        id: rightZone
        x: rightSide.anchorX - win.sideReach
        width: win.sideSize + 2 * win.sideReach
        height: win.sideZoneH
        HoverHandler { id: rightNear }
    }

    IslandSide {
        id: leftSide
        shown: win.sidesShown
        size: win.sideSize
        restY: win.topGap + (win.idleH - win.sideSize) / 2
        round: win.floating
        growLeft: true
        anchorX: pill.x + win.topRadius - win.sideGap
        offsetX: win.sideOffset(leftNear, "x", leftZone.width / 2)
        offsetY: win.sideOffset(leftNear, "y", restY + size / 2)

        AudioIndicator {
            anchors.centerIn: parent
            width: parent.width * win.sideIconScale
            height: parent.height * win.sideIconScale
        }

        onClicked: win.leftClicked()
    }

    IslandSide {
        id: rightSide
        shown: win.sidesShown
        size: win.sideSize
        restY: win.topGap + (win.idleH - win.sideSize) / 2
        round: win.floating
        anchorX: pill.x + pill.width - win.topRadius + win.sideGap
        offsetX: win.sideOffset(rightNear, "x", rightZone.width / 2)
        offsetY: win.sideOffset(rightNear, "y", restY + size / 2)

        BatteryIndicator {
            anchors.centerIn: parent
            width: parent.width * win.sideIconScale
            height: parent.height * win.sideIconScale
        }

        onClicked: win.rightClicked()
    }

    property string grabOwner: ""
    property bool grabReady: false
    onOwnerChanged: {
        if (owner !== grabOwner) grabOwner = ""
        grabReady = false
        if (owner !== "") {
            revealBlocked = true
            hideIcons.stop()
            revealed = false
        } else if (!pointerNear) {
            revealBlocked = false
        }
    }
    onGrabOwnerChanged: grabReady = false
    Timer {
        interval: 200
        running: win.grabOwner !== "" && win.owner === win.grabOwner && !win.grabReady
        onTriggered: win.grabReady = true
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.grabReady && win.grabOwner !== "" && win.owner === win.grabOwner
        onCleared: if (!remapGuard.running) win.close(win.grabOwner)
    }
}
