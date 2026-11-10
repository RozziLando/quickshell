import QtQuick

Item {
    id: fade

    property bool active: false
    property int pause: 100
    property int duration: 250
    property bool instant: false

    visible: false
    width: 0
    height: 0

    SequentialAnimation {
        id: anim
        PauseAnimation { duration: fade.pause }
        NumberAnimation {
            target: fade.parent
            property: "opacity"
            to: 1
            duration: fade.duration
        }
    }

    onActiveChanged: {
        anim.stop()
        if (!fade.parent) return
        if (active && instant) {
            fade.parent.opacity = 1
            return
        }
        fade.parent.opacity = 0
        if (active) anim.start()
    }

    Component.onCompleted: if (fade.parent) fade.parent.opacity = active ? 1 : 0
}
