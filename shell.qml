//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
import QtQuick
import Quickshell
import qs.island
import qs.bar
import qs.services
import qs.lock
import qs.settings

ShellRoot {
    id: root

    HyprShadowSync {}

    readonly property var themes: ThemeManager
    readonly property var greeterSync: GreeterSync

    StartupSettings {}

    AudioAutoSwitch {}

    readonly property var bluetoothAuto: BluetoothAuto
    readonly property var settings: Settings
    readonly property var updater: Updater

    SettingsWindow {}

    Lock { id: lockModule }

    readonly property string wantedMode: Theme.barMode ? "bar" : "island"
    property string loadedMode: wantedMode
    onWantedModeChanged: {
        loadedMode = ""
        modeSwitch.restart()
    }
    Timer {
        id: modeSwitch
        interval: 250
        onTriggered: root.loadedMode = root.wantedMode
    }

    LazyLoader {
        active: root.loadedMode === "island"
        IslandShell { lock: lockModule }
    }

    LazyLoader {
        active: root.loadedMode === "bar"
        BarShell { lock: lockModule }
    }
}
