import QtQuick
import Quickshell
import qs.island
import qs.modules
import qs.modules.controlcenter
import qs.modules.media
import qs.modules.system
import qs.services
import qs.lock

ShellRoot {
    HyprShadowSync {}

    readonly property var themes: ThemeManager
    readonly property var greeterSync: GreeterSync

    StartupSettings {}

    AudioAutoSwitch {}

    readonly property var bluetoothAuto: BluetoothAuto

    Lock { id: lockModule }

    EdgeReveal { island: mainIsland }

    Island {
        id: mainIsland

        onLeftClicked: mediaModule.toggle()
        onRightClicked: sysmonModule.toggle()
        onClockClicked: controlCenterModule.toggle()

        Clock { island: mainIsland }
        Notifications { id: notificationsModule; island: mainIsland }
        Launcher { id: launcherModule; island: mainIsland }
        MediaPlayer { id: mediaModule; island: mainIsland }
        SystemMonitorPanel { id: sysmonModule; island: mainIsland }
        Osd { island: mainIsland }
        PowerMenu { id: powerModule; island: mainIsland; lock: lockModule }
        ControlCenter {
            id: controlCenterModule
            island: mainIsland
            launcher: launcherModule
            notifications: notificationsModule
            power: powerModule
        }
    }
}
