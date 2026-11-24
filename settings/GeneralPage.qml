import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "gear"
    title: "General"
    description: "Size of the shell, the main screen and the extra features."

    readonly property var battery: UPower.displayDevice
    readonly property bool desktop: !(battery && battery.ready && battery.isLaptopBattery && battery.isPresent)
    readonly property bool hasBluetooth: Bluetooth.adapters.values.length > 0

    function screenValue(s) {
        var model = String(s.model || "").trim()
        if (model === "") return s.name
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (list[i] !== s && String(list[i].model || "").trim() === model) return s.name
        return model
    }

    function screenLabel(s) {
        var model = String(s.model || "").trim()
        return model !== "" ? model : s.name
    }

    readonly property var autoScreen: {
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i]
        return list.length > 0 ? list[0] : null
    }

    readonly property var screenItems: {
        var out = [{ value: "", label: "Auto", detail: autoScreen ? screenLabel(autoScreen) : "" }]
        Quickshell.screens.forEach(function (s) {
            out.push({ value: page.screenValue(s), label: page.screenLabel(s),
                       detail: s.name + " · " + s.width + "×" + s.height })
        })
        return out
    }

    readonly property var currentScreen: {
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (Theme.isMonitor(list[i])) return list[i]
        return null
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Display"
    }

    SliderRow {
        title: "Scale"
        info: "Size of the whole shell: island, panels, lock screen and this window. 1.00 is the original size."
        from: 0.75
        to: 2
        step: 0.05
        value: Theme.scale
        format: function (v) { return v.toFixed(2) + "×" }
        onCommitted: v => Settings.set("scale", Math.round(v * 100) / 100)
    }

    OptionRow {
        title: "Main monitor"
        info: "Screen of the island, the lock screen and the login screen. Auto uses the laptop screen, otherwise the first one. The monitor is recognized by its model, so it stays the same on any port."
        subtitle: Theme.monitor !== "" && !page.currentScreen ? Theme.monitor + " is not connected, using Auto" : ""

        Dropdown {
            text: page.currentScreen ? page.screenLabel(page.currentScreen)
                : Theme.monitor !== "" ? Theme.monitor : "Auto"
            items: page.screenItems
            current: page.currentScreen ? page.screenValue(page.currentScreen)
                : Theme.monitor !== "" ? Theme.monitor : ""
            menuWidth: SettingsUi.u(260)
            onPicked: value => Settings.set("monitor", value)
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Features"
    }

    ToggleRow {
        visible: page.hasBluetooth
        title: "Bluetooth on startup"
        info: "Bluetooth is turned on at the first shell start after boot. Off: it starts turned off."
        key: "bluetoothOnStartup"
        checked: Theme.bluetoothOnStartup
    }

    ToggleRow {
        title: "Network monitor"
        info: "The system monitor (right click on the island) also shows the download and upload speed of all the network cards."
        key: "networkMonitor"
        checked: Theme.networkMonitor
    }

    ToggleRow {
        title: "Background apps"
        info: "The apps with open windows, in the system monitor under the temperatures, or in the control center if you add them there. A click opens the app, the × closes all its processes."
        key: "backgroundApps"
        checked: Theme.backgroundApps
    }

    ToggleRow {
        visible: page.desktop
        title: "Monitor brightness"
        info: "Shows the Display slider and page in the control center. The slider sets the brightness of the monitors through DDC/CI (ddcutil; DDC/CI must be on in the monitor menu)."
        key: "displayOnDesktop"
        checked: Theme.displayOnDesktop
    }

    ToggleRow {
        title: "VS Code theme sync"
        info: "VS Code (and VSCodium, Code - OSS) follows the shell theme. Needs the Quickshell Theme Sync extension. Off: the editor keeps its own theme."
        key: "vscodeThemeSync"
        checked: Theme.vscodeThemeSync
    }
}
