import QtQuick
import qs.services

ShaderEffect {
    property vector2d pixel: Qt.vector2d(1 / Math.max(1, width), 1 / Math.max(1, height))
    property real tint: Theme.glassOpacity
    property real rim: Theme.s(14)
    property real light: 1
    property vector4d outside: Qt.vector4d(0, 0, 0, 0)
    fragmentShader: Qt.resolvedUrl("shaders/surface.frag.qsb")
}
