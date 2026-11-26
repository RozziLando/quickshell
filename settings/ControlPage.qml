import QtQuick
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "sliders"
    title: "Control Center"
    description: "Buttons, sliders and clock on top, lists below."

    readonly property var gridHidden: Controls.chosenGrid.filter(function (e) { return !Controls.itemAvailable(e.id) })
    readonly property var gridShown: Controls.grid
    readonly property var bottomHidden: Controls.chosenBottom.filter(function (id) { return !Controls.itemAvailable(id) })
    readonly property var gridPool: Controls.gridOrder.filter(function (id) {
        return Controls.itemAvailable(id) && !page.gridShown.some(function (e) { return e.id === id })
    })
    readonly property var bottomPool: Controls.bottomOrder.filter(function (id) {
        return Controls.itemAvailable(id) && Controls.bottom.indexOf(id) < 0
    })

    ToggleRow {
        title: "Control center"
        info: "Off: the clock opens only the date."
        key: "controlCenter"
        checked: Theme.controlCenter
    }

    ControlDesigner {
        visible: Theme.controlCenter
        grid: page.gridShown
        lower: Controls.bottom
        gridPool: page.gridPool
        bottomPool: page.bottomPool
        onGridEdited: list => Settings.set("controlGrid", list.concat(page.gridHidden.map(function (e) {
            return { id: e.id, row: e.row, col: e.col }
        })))
        onBottomEdited: list => Settings.set("controlBottom", list.concat(page.bottomHidden))
        onWidthsEdited: map => Settings.set("controlWidths", map)
    }

    Text {
        readonly property var off: (Theme.backgroundApps ? [] : ["Background apps"])
            .concat(Theme.powerMode || !Controls.hasPowerProfiles ? [] : ["Power mode"])
        visible: Theme.controlCenter && off.length > 0
        width: parent.width
        leftPadding: SettingsUi.u(4)
        text: "Turn on " + off.join(" and ") + " in General to add " + (off.length > 1 ? "them" : "it") + " here."
        color: Theme.textMuted
        font.pixelSize: SettingsUi.u(9)
        font.family: Theme.fontFamily
        wrapMode: Text.WordWrap
    }

    OptionRow {
        visible: Theme.controlCenter
        title: "Default layout"
        info: "Back to the default layout for this computer."

        PillButton {
            icon: "reboot"
            text: "Reset"
            onClicked: Settings.edit(function (s) {
                s.controlGrid = "auto"
                s.controlBottom = "auto"
                s.controlItems = "auto"
                s.controlTiles = "auto"
                s.controlSections = "auto"
                s.controlWidths = {}
            })
        }
    }
}
