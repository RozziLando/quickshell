import QtQuick
import qs.services
import qs.widgets

// Cerchio (isola staccata) o quadratino (isola attaccata) ai lati
// dell'isola, con un'icona. Il click apre il modulo al centro dell'isola.
// Segue i bordi della pillola; si nasconde in fullscreen.
Rectangle {
    id: root

    property bool shown: true
    property int size: Theme.s(24)
    property int restY: Theme.s(3)      // distanza dal bordo alto dello schermo
    // true: cerchio (isola staccata), false: quadratino
    property bool round: false
    // true: anchorX è il bordo destro, altrimenti il sinistro
    property bool growLeft: false
    property real anchorX: 0

    // Icona
    default property alias content: host.data

    signal clicked()

    width: size
    height: size
    x: growLeft ? anchorX - width : anchorX
    radius: round ? size / 2 : Theme.s(7)
    color: Theme.panel
    // Alone leggero al posto del bordo (se attivo in theme.json); vetro: bordo chiaro
    border.width: Theme.glass ? 1 : (Theme.shadowEnabled ? 0 : 1)
    border.color: Theme.glass ? Theme.glassEdge : Theme.border

    // Vetro: riflesso chiaro in alto
    Rectangle {
        visible: Theme.glass
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glassSheen }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }
    layer.enabled: Theme.shadowEnabled
    layer.effect: SoftGlow {}

    // Spostamento verso il mouse quando è vicino (impostato dall'isola)
    property real offsetX: 0
    property real offsetY: 0
    transform: Translate { x: root.offsetX; y: root.offsetY }
    Behavior on offsetX { SpringAnimation { spring: 3; damping: 0.35 } }
    Behavior on offsetY { SpringAnimation { spring: 3; damping: 0.35 } }

    // Quando si nasconde (fullscreen, minimal) risale e svanisce; quando
    // compare scende dall'alto
    y: shown ? restY : -height
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200 } }

    Item {
        id: host
        anchors.fill: parent
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
