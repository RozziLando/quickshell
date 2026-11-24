import QtQuick
import Quickshell
import qs.modules
import qs.modules.controlcenter
import qs.modules.media
import qs.modules.system
import qs.services

Scope {
    id: root

    property var lock: null

    EdgeReveal { island: mainIsland }

    Island {
        id: mainIsland

        onLeftClicked: Theme.audioPanel ? audioModule.toggle() : mediaModule.toggle()
        onRightClicked: sysmonModule.toggle()
        onClockClicked: controlCenterModule.toggle()

        Clock { island: mainIsland }
        Notifications { id: notificationsModule; island: mainIsland }
        Launcher { id: launcherModule; island: mainIsland }
        MediaPlayer { id: mediaModule; island: mainIsland }
        AudioPanel { id: audioModule; island: mainIsland }
        SystemMonitorPanel { id: sysmonModule; island: mainIsland }
        Osd { island: mainIsland }
        PowerMenu { id: powerModule; island: mainIsland; lock: root.lock }
        ControlCenter {
            id: controlCenterModule
            island: mainIsland
            launcher: launcherModule
            notifications: notificationsModule
            power: powerModule
        }
    }
}
