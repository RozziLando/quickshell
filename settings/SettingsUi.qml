pragma Singleton
import QtQuick
import Quickshell
import qs.services

Singleton {
    id: root

    property real factor: 1.0
    function u(value) { return Theme.s(value * factor) }
    readonly property int radius: u(15)

    property var menu: null
    property var picker: null
    property var tip: null

    function openMenu(spec) {
        tip = null
        menu = spec
    }
    function closeMenu() { menu = null }

    function showTip(anchor, text) { tip = { anchor: anchor, text: text } }
    function hideTip(anchor) { if (tip && tip.anchor === anchor) tip = null }

    function home(path) {
        var h = Quickshell.env("HOME")
        return String(path).indexOf(h) === 0 ? "~" + String(path).substring(h.length) : String(path)
    }
}
