import QtQuick
import qs.services

OptionRow {
    id: row

    property alias from: slider.from
    property alias to: slider.to
    property alias step: slider.step
    property alias values: slider.values
    property alias value: slider.value
    property var format: function (v) { return String(v) }

    signal committed(real value)

    hasBelow: true

    Text {
        text: row.format(slider.shown)
        color: slider.dragging ? Theme.accent : Theme.textSecondary
        font.pixelSize: SettingsUi.u(10)
        font.weight: Font.DemiBold
        font.family: Theme.fontFamily
    }

    below: ValueSlider {
        id: slider
        onCommitted: v => row.committed(v)
    }
}
