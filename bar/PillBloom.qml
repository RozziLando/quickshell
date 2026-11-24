import QtQuick
import qs.services
import qs.widgets

Item {
    id: bloom

    required property var host
    required property var stage

    readonly property rect r: host.bloomRect

    visible: host.bloomShown
    x: 0
    y: 0
    width: stage.width
    height: stage.height
    layer.enabled: Theme.shadowEnabled && visible && bloom.stage.pillsAttached
    layer.effect: SoftGlow {}

    RectShadow {
        visible: Theme.shadowEnabled && !bloom.stage.pillsAttached
        x: bloom.r.x
        y: bloom.r.y
        width: bloom.r.width
        height: bloom.r.height
        radius: bloomGlass.radius
    }

    GlassRect {
        id: bloomGlass
        visible: !bloom.stage.pillsAttached
        x: bloom.r.x
        y: bloom.r.y
        width: bloom.r.width
        height: bloom.r.height
        radius: Math.min(bloom.host.bloomRadius, width / 2, height / 2)
    }

    EdgeShape {
        visible: bloom.stage.pillsAttached
        stage: bloom.stage
        box: bloom.r
        radius: bloom.host.bloomRadius
        readonly property real a0: bloom.stage.vertical ? bloom.r.y : bloom.r.x
        readonly property real a1: a0 + (bloom.stage.vertical ? bloom.r.height : bloom.r.width)
        flushStart: a0 <= bloom.stage.barStart + 0.5
        flushEnd: a1 >= bloom.stage.barStart + bloom.stage.barLength - 0.5
    }
}
