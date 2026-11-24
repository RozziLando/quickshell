import QtQuick
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    property string ownerId: ""
    property Component page: null
    property real heightUnits: 440

    anchors.fill: parent

    readonly property bool shown: island.owner === ownerId && ownerId !== ""

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int edgePad: u(14)
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int openWidth: u(436)
    readonly property int openHeight: loader.item
        ? Math.max(u(130), Math.min(u(heightUnits), loader.item.naturalHeight + 2 * edgePad + u(10)))
        : u(heightUnits)
    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, keyboard, panelRadius)
    readonly property int panelRadius: Theme.radius + edgePad * Theme.roundness

    readonly property bool busy: !!(loader.item && loader.item.busy === true)
    property bool keyboard: false

    function open() {
        keyboard = false
        island.open(ownerId, openWidth, openHeight, false, panelRadius)
        island.grabOwner = ownerId
    }

    function toggle() {
        if (shown) island.close(ownerId)
        else open()
    }

    onShownChanged: if (!shown) keyboard = false

    Connections {
        target: root.island
        function onHoveredChanged() {
            if (root.island.hovered) closeTimer.stop()
            else if (root.shown) closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 400
        onTriggered: {
            if (root.busy || root.keyboard) restart()
            else root.island.close(root.ownerId)
        }
    }

    Loader {
        id: loader
        anchors {
            fill: parent
            topMargin: root.edgePad
            bottomMargin: root.edgePad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        active: root.shown || status === Loader.Ready
        sourceComponent: root.page
        visible: root.shown
        onLoaded: {
            item.sizeFactor = root.sizeFactor
            item.showBack = false
            item.bottomGap = root.u(6)
        }
        FadeIn { active: root.shown; pause: 140; duration: 200 }
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onKeyboardWanted() {
            root.keyboard = true
            root.island.open(root.ownerId, root.openWidth, root.openHeight, true, root.panelRadius)
        }
        function onBack() { root.island.close(root.ownerId) }
    }
}
