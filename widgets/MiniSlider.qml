import QtQuick
import qs.services

// Barra del volume compatta per le pagine di dettaglio
Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property real value: 0              // 0..1
    property bool muted: false
    property string icon: "volume"
    property bool showPercent: true

    signal moved(real value)
    signal iconClicked()

    property bool dragging: false
    property real dragValue: 0
    readonly property real shownValue: Math.max(0, Math.min(1, dragging ? dragValue : value))
    // Valore mostrato, animato: i cambi dai tasti scorrono fluidi. Si anima
    // il valore e non la larghezza, così all'apertura (barra che passa da
    // larghezza 0 a quella vera) non parte dal fondo. Trascinando o da
    // nascosta segue subito
    property real animValue: shownValue
    Behavior on animValue {
        enabled: !root.dragging && root.visible
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    width: parent ? parent.width : 0
    height: u(22)

    function setFromX(x) {
        dragValue = Math.max(0, Math.min(1, x / track.width))
        if (!throttle.running) throttle.start()
    }

    Timer {
        id: throttle
        interval: 100
        onTriggered: root.moved(root.dragValue)
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.track

        Rectangle {
            id: fill
            height: parent.height
            radius: height / 2
            width: root.animValue <= 0.001 ? 0 : Math.max(height, root.animValue * track.width)
            color: root.muted ? Theme.textDisabled : Theme.accent
        }

        LineIcon {
            anchors.left: parent.left
            anchors.leftMargin: root.u(7)
            anchors.verticalCenter: parent.verticalCenter
            size: root.u(12)
            kind: root.muted && root.icon === "volume" ? "volume-mute" : root.icon
            color: fill.width > root.u(24) ? Theme.background : Theme.text
        }

        Text {
            visible: root.showPercent
            anchors.right: parent.right
            anchors.rightMargin: root.u(9)
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.shownValue * 100) + "%"
            color: fill.width > track.width - root.u(36) ? Theme.background : Theme.textSecondary
            font.pixelSize: root.u(9)
            font.family: Theme.fontFamily
        }

        MouseArea {
            anchors.fill: parent
            // Il trascinamento orizzontale non deve far scorrere la lista
            preventStealing: true
            onPressed: mouse => {
                root.dragging = true
                root.setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed) root.setFromX(mouse.x)
            }
            onReleased: {
                throttle.stop()
                root.moved(root.dragValue)
                root.dragging = false
            }
            onCanceled: {
                throttle.stop()
                root.dragging = false
            }
        }

        // Click sull'icona: muto
        MouseArea {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root.u(26)
            onClicked: root.iconClicked()
        }
    }
}
