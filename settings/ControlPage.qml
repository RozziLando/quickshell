import QtQuick
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "sliders"
    title: "Control Center"
    description: "Build your control center: drag buttons and sections into it, move them around, drag them out to remove them."

    readonly property var tilePool: Controls.tileOrder.filter(function (id) {
        return Controls.tileAvailable(id) && Controls.tiles.indexOf(id) < 0
    })

    readonly property var shownSections: Controls.chosenSections.filter(Controls.sectionAvailable)
    readonly property var hiddenSections: Controls.chosenSections.filter(function (id) {
        return !Controls.sectionAvailable(id)
    })
    readonly property var sectionPool: Controls.sectionOrder.filter(function (id) {
        return Controls.sectionAvailable(id) && shownSections.indexOf(id) < 0
    })

    ToggleRow {
        title: "Control center"
        info: "Off: there is no control center. The clock only tells the time and does nothing when the mouse is over it or clicks it."
        key: "controlCenter"
        checked: Theme.controlCenter
    }

    ControlDesigner {
        visible: Theme.controlCenter
        tiles: Controls.tiles
        sections: page.shownSections
        tilePool: page.tilePool
        sectionPool: page.sectionPool
        onTilesEdited: list => Settings.set("controlTiles", list)
        onSectionsEdited: list => Settings.set("controlSections", list.concat(page.hiddenSections))
    }

    Text {
        visible: Theme.controlCenter && !Theme.backgroundApps
        width: parent.width
        leftPadding: SettingsUi.u(4)
        text: "Turn on Background apps in General to place them in the control center instead of the system monitor."
        color: Theme.textMuted
        font.pixelSize: SettingsUi.u(9)
        font.family: Theme.fontFamily
        wrapMode: Text.WordWrap
    }

    OptionRow {
        visible: Theme.controlCenter
        title: "Default layout"
        info: "Go back to the automatic layout: it adapts to the Wi-Fi and Bluetooth cards of this computer."

        PillButton {
            icon: "reboot"
            text: "Reset"
            onClicked: Settings.edit(function (s) {
                s.controlTiles = "auto"
                s.controlSections = "auto"
            })
        }
    }
}
