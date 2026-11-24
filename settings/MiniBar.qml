import QtQuick
import qs.services
import qs.widgets
import qs.bar

Item {
    id: mini

    property string kind: "floating"
    property color ink: Theme.accent
    property color hole: Theme.track

    anchors.fill: parent

    readonly property real wide: width
    readonly property real t: SettingsUi.u(11)
    readonly property real g: SettingsUi.u(4)
    readonly property real f: Math.max(1, Math.round(SettingsUi.u(5) * Theme.roundness))
    readonly property real rr: Math.min(Theme.radius * 0.45, t / 2)
    readonly property real dot: SettingsUi.u(3)

    readonly property bool island: kind === "islandFloating" || kind === "islandAttached"
    readonly property bool floats: kind === "floating" || kind === "pills" || kind === "islandFloating"
    readonly property real barBottom: floats ? g + t : t

    Rectangle {
        x: 2 * mini.g
        y: mini.barBottom + 1.5 * mini.g
        width: mini.wide - 4 * mini.g
        height: Math.max(0, mini.height - y - 1.5 * mini.g)
        radius: Math.min(Theme.radius * 0.45, SettingsUi.u(6))
        color: Theme.textMuted
        opacity: 0.16
    }

    Rectangle {
        visible: mini.kind === "floating"
        x: mini.g
        y: mini.g
        width: mini.wide - 2 * mini.g
        height: mini.t
        radius: Math.min(Theme.radius * 0.45, height / 2)
        color: mini.ink

        MiniDots { x: mini.g * 1.5; anchors.verticalCenter: parent.verticalCenter; count: 2; tone: mini.hole }
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.hole }
        MiniDots { x: parent.width - width - mini.g * 1.5; anchors.verticalCenter: parent.verticalCenter; count: 3; tone: mini.hole }
    }

    MiniAttached {
        thick: mini.t
        curve: mini.rr
        fillet: mini.f
        ink: mini.ink
        visible: mini.kind === "attached"
        start: mini.wide * 0.1
        span: mini.wide * 0.8

        MiniDots { x: mini.g * 1.5; anchors.verticalCenter: parent.verticalCenter; count: 2; tone: mini.hole }
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.hole }
        MiniDots { x: parent.width - width - mini.g * 1.5; anchors.verticalCenter: parent.verticalCenter; count: 3; tone: mini.hole }
    }

    Item {
        visible: mini.kind === "integrated"
        width: mini.wide
        height: mini.t

        Rectangle {
            width: parent.width
            height: parent.height
            color: mini.ink
        }
        Fillet { y: mini.t; size: mini.f; corner: "tl"; fill: mini.ink }
        Fillet { x: mini.wide - mini.f; y: mini.t; size: mini.f; corner: "tr"; fill: mini.ink }

        MiniDots { x: mini.g * 2; anchors.verticalCenter: parent.verticalCenter; count: 2; tone: mini.hole }
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.hole }
        MiniDots { x: parent.width - width - mini.g * 2; anchors.verticalCenter: parent.verticalCenter; count: 3; tone: mini.hole }
    }

    Item {
        visible: mini.kind === "transparent"
        width: mini.wide
        height: mini.t

        MiniDots { x: mini.g * 2; anchors.verticalCenter: parent.verticalCenter; count: 2; tone: mini.ink }
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.ink }
        MiniDots { x: parent.width - width - mini.g * 2; anchors.verticalCenter: parent.verticalCenter; count: 3; tone: mini.ink }
    }

    Repeater {
        model: mini.kind === "pills" ? [
            { x: mini.g, w: mini.wide * 0.22, n: 2 },
            { x: (mini.wide - mini.wide * 0.2) / 2, w: mini.wide * 0.2, n: 1 },
            { x: mini.wide - mini.g - mini.wide * 0.16, w: mini.wide * 0.16, n: 2 },
            { x: mini.wide - mini.g - mini.wide * 0.16 - mini.g - mini.wide * 0.12, w: mini.wide * 0.12, n: 1 }
        ] : []
        delegate: Rectangle {
            required property var modelData
            x: modelData.x
            y: mini.g
            width: modelData.w
            height: mini.t
            radius: Theme.round(height)
            color: mini.ink
            MiniDots { anchors.centerIn: parent; count: modelData.n; tone: mini.hole }
        }
    }

    MiniAttached {
        thick: mini.t
        curve: mini.rr
        fillet: mini.f
        ink: mini.ink
        visible: mini.kind === "pillsAttached"
        start: 0
        span: mini.wide * 0.22
        flushStart: true
        MiniDots { anchors.centerIn: parent; count: 2; tone: mini.hole }
    }
    MiniAttached {
        thick: mini.t
        curve: mini.rr
        fillet: mini.f
        ink: mini.ink
        visible: mini.kind === "pillsAttached" || mini.kind === "islandAttached"
        start: (mini.wide - span) / 2
        span: mini.wide * (mini.kind === "islandAttached" ? 0.34 : 0.26)
        MiniDots { anchors.centerIn: parent; count: mini.kind === "islandAttached" ? 3 : 1; tone: mini.hole }
    }
    MiniAttached {
        thick: mini.t
        curve: mini.rr
        fillet: mini.f
        ink: mini.ink
        visible: mini.kind === "pillsAttached"
        start: mini.wide - span
        span: mini.wide * 0.26
        flushEnd: true
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.hole }
    }

    Rectangle {
        id: floatIsland
        visible: mini.kind === "islandFloating"
        x: (mini.wide - width) / 2
        y: mini.g
        width: mini.wide * 0.3
        height: mini.t
        radius: Theme.round(height)
        color: mini.ink
        MiniDots { anchors.centerIn: parent; count: 3; tone: mini.hole }
    }
    Repeater {
        model: mini.kind === "islandFloating" ? [-1, 1] : []
        delegate: Rectangle {
            required property int modelData
            width: mini.t
            height: width
            radius: Theme.round(width)
            y: mini.g
            x: mini.wide / 2 + modelData * (floatIsland.width / 2 + mini.g + width / 2) - width / 2
            color: mini.ink
            opacity: 0.75
        }
    }
}
