import QtQuick
import qs.services
import qs.widgets

Item {
    id: shape

    property real topRadius: Theme.s(10)
    property real fillet: topRadius
    property real bottomRadius: Theme.s(15)
    property bool outline: true

    readonly property real f: Math.max(0, Math.min(fillet, topRadius))
    readonly property real rb: Math.max(0, Math.min(bottomRadius, (width - 2 * topRadius) / 2, height / 2))

    Item {
        visible: shape.outline
        anchors.fill: parent

        Rectangle {
            x: shape.topRadius - 1
            width: Math.max(0, shape.width - 2 * shape.topRadius + 2)
            height: shape.height + 1
            color: Theme.border
            bottomLeftRadius: shape.rb + 1
            bottomRightRadius: shape.rb + 1
        }
        Fillet {
            x: shape.topRadius - shape.f - 1
            y: -1
            size: shape.f + 1
            corner: "tr"
            fill: Theme.border
        }
        Fillet {
            x: shape.width - shape.topRadius
            y: -1
            size: shape.f + 1
            corner: "tl"
            fill: Theme.border
        }
    }

    Rectangle {
        x: shape.topRadius
        width: Math.max(0, shape.width - 2 * shape.topRadius)
        height: shape.height
        color: Theme.panel
        bottomLeftRadius: shape.rb
        bottomRightRadius: shape.rb
    }
    Fillet {
        x: shape.topRadius - shape.f
        size: shape.f
        corner: "tr"
        fill: Theme.panel
    }
    Fillet {
        x: shape.width - shape.topRadius
        size: shape.f
        corner: "tl"
        fill: Theme.panel
    }
}
