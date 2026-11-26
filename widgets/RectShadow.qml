import QtQuick
import qs.services

Item {
    id: root

    property bool drop: true
    property real radius: 0

    visible: Theme.shadowEnabled

    Loader {
        id: impl
        anchors.fill: parent
        active: root.visible
        source: "RectShadowNative.qml"
    }

    Binding {
        when: impl.status === Loader.Ready
        target: impl.item
        property: "radius"
        value: root.radius
    }
    Binding {
        when: impl.status === Loader.Ready
        target: impl.item
        property: "drop"
        value: root.drop
    }
}
