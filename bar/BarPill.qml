import QtQuick
import qs.services
import qs.widgets

Item {
    id: capsule

    required property var stage
    property var kinds: []
    property string zone: ""
    property int slot: 0

    readonly property bool islandLike: stage.pillsAttached && zone === "center"
    readonly property int pad: Theme.s(5) + (zone === "center" && !islandLike ? Theme.s(7) : 0)
    readonly property bool bloomed: stage.pillBloomed(capsule)
    readonly property string bloomOwner: stage.pillOwner(capsule)
    readonly property string activeOwner: stage.pillActiveOwner(capsule)

    property real shift: stage.pillShift(capsule)
    Behavior on shift {
        id: shiftBehavior
        NumberAnimation {
            readonly property bool closing: Math.abs(shiftBehavior.targetValue) < 0.5
            duration: closing ? 320 : 380
            easing.type: Easing.OutBack
            easing.overshoot: closing ? 0.5 : 1.1
        }
    }
    transform: Translate {
        x: capsule.stage.vertical ? 0 : capsule.shift
        y: capsule.stage.vertical ? capsule.shift : 0
    }

    implicitWidth: stage.vertical ? stage.itemSize
        : islandLike ? Math.max(Theme.s(130), grid.implicitWidth + 2 * pad) : grid.implicitWidth + 2 * pad
    implicitHeight: stage.vertical ? grid.implicitHeight + 2 * pad
        : islandLike ? Theme.s(30) : stage.itemSize
    width: implicitWidth
    height: implicitHeight
    Behavior on width { enabled: capsule.stage.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: capsule.stage.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Component.onCompleted: stage.registerPill(capsule)
    Component.onDestruction: stage.unregisterPill(capsule)

    Item {
        readonly property int m: capsule.stage.pillFillet + 2
        x: -m
        y: -m
        width: capsule.width + 2 * m
        height: capsule.height + 2 * m
        opacity: capsule.bloomed ? 0 : 1
        layer.enabled: Theme.shadowEnabled && visible && capsule.stage.pillsAttached
        layer.effect: SoftGlow { drop: capsule.stage.pillsAttached }

        RectShadow {
            visible: Theme.shadowEnabled && !capsule.stage.pillsAttached
            drop: false
            x: parent.m
            y: parent.m
            width: capsule.width
            height: capsule.height
            radius: pillRect.radius
        }

        GlassRect {
            id: pillRect
            visible: !capsule.stage.pillsAttached
            x: parent.m
            y: parent.m
            width: capsule.width
            height: capsule.height
            radius: Theme.round(Math.min(width, height))
        }

        EdgeShape {
            visible: capsule.stage.pillsAttached
            stage: capsule.stage
            box: Qt.rect(parent.m, parent.m, capsule.width, capsule.height)
            radius: Theme.radius
            flushStart: capsule.zone === "start"
            flushEnd: capsule.zone === "end"
        }
    }

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: capsule.stage.vertical ? 1 : Math.max(1, capsule.kinds.length)
        spacing: Theme.s(2)
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: capsule.kinds
            delegate: BarItem {
                required property string modelData
                kind: modelData
                stage: capsule.stage
                pill: capsule
            }
        }
    }
}
