import QtQuick
import qs.services
import qs.widgets

Item {
    id: bloom

    required property var host
    required property var stage

    readonly property int m: stage.pillFillet + 2

    visible: host.bloomShown
    x: host.bloomRect.x - m
    y: host.bloomRect.y - m
    width: host.bloomRect.width + 2 * m
    height: host.bloomRect.height + 2 * m
    layer.enabled: Theme.shadowEnabled
    layer.effect: SoftGlow {}

    GlassRect {
        visible: !bloom.stage.pillsAttached
        x: bloom.m
        y: bloom.m
        width: bloom.host.bloomRect.width
        height: bloom.host.bloomRect.height
        radius: Math.min(bloom.host.bloomRadius, width / 2, height / 2)
    }

    EdgeShape {
        visible: bloom.stage.pillsAttached
        stage: bloom.stage
        box: Qt.rect(bloom.m, bloom.m, bloom.host.bloomRect.width, bloom.host.bloomRect.height)
        radius: bloom.host.bloomRadius
        readonly property real a0: bloom.stage.vertical ? bloom.host.bloomRect.y : bloom.host.bloomRect.x
        readonly property real a1: a0 + (bloom.stage.vertical ? bloom.host.bloomRect.height : bloom.host.bloomRect.width)
        flushStart: a0 <= bloom.stage.barStart + 0.5
        flushEnd: a1 >= bloom.stage.barStart + bloom.stage.barLength - 0.5
    }
}
