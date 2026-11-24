//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island
import qs.bar
import qs.services
import qs.lock
import qs.settings

ShellRoot {
    id: root

    readonly property string memoryTuning: "narenas:2,dirty_decay_ms:1000,muzzy_decay_ms:0,background_thread:false"
    readonly property bool tuned: !!Quickshell.env("MALLOC_CONF") || !!Quickshell.env("QS_NO_RESPAWN")

    Component.onCompleted: {
        if (tuned) return
        Quickshell.execDetached(["env", "MALLOC_CONF=" + memoryTuning, "QS_NO_RESPAWN=1",
                                 "quickshell", "-p", Quickshell.shellDir])
        leave.running = true
    }

    Process {
        id: leave
        command: ["sh", "-c", "kill $PPID"]
    }

    LazyLoader {
        active: root.tuned

        Scope {
            id: shell

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
            property string loadedMode: ""
            Component.onCompleted: loadedMode = wantedMode
            onWantedModeChanged: if (wantedMode !== loadedMode) modeDelay.running = true
            Process {
                id: modeDelay
                command: ["sleep", "0.25"]
                onExited: {
                    shell.loadedMode = shell.wantedMode
                }
            }

            LazyLoader {
                active: shell.loadedMode === "island" && shell.wantedMode === "island"
                IslandShell { lock: lockModule }
            }

            LazyLoader {
                active: shell.loadedMode === "bar" && shell.wantedMode === "bar"
                BarShell { lock: lockModule }
            }
        }
    }
}
