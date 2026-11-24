import QtQuick
import qs.bar

Item {
    id: att

    property real start: 0
    property real span: 0
    property real thick: 0
    property real curve: 0
    property real fillet: 0
    property color ink: "white"
    property bool flushStart: false
    property bool flushEnd: false

    x: start
    width: span
    height: thick

    Rectangle {
        y: -att.curve
        width: parent.width
        height: parent.height + att.curve
        color: att.ink
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: att.flushStart ? 0 : att.curve
        bottomRightRadius: att.flushEnd ? 0 : att.curve
    }
    Fillet {
        visible: !att.flushStart
        x: -att.fillet
        size: att.fillet
        corner: "tr"
        fill: att.ink
    }
    Fillet {
        visible: !att.flushEnd
        x: att.width
        size: att.fillet
        corner: "tl"
        fill: att.ink
    }
    Fillet {
        visible: att.flushStart
        y: att.height
        size: att.fillet
        corner: "tl"
        fill: att.ink
    }
    Fillet {
        visible: att.flushEnd
        x: att.width - att.fillet
        y: att.height
        size: att.fillet
        corner: "tr"
        fill: att.ink
    }
}
