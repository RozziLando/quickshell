// Nessun tema di icone forzato: le app mostrano le loro icone native (hicolor)
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
    // Ombra delle finestre di Hyprland = alone della shell (theme.json)
    HyprShadowSync {}

    // Cambio tema (avvia il singleton: IPC "theme" sempre disponibile)
    readonly property var themes: ThemeManager
    // Login (greetd) sempre uguale al blocco schermo: tema, foto, sfondo
    readonly property var greeterSync: GreeterSync

    // Bluetooth all'avvio ("bluetoothOnStartup" in theme.json)
    StartupSettings {}

    // Cuffie collegate -> diventano l'uscita audio
    AudioAutoSwitch {}

    // Bluetooth: connessione automatica ai dispositivi noti, con notifica
    readonly property var bluetoothAuto: BluetoothAuto

    // Blocco schermo e blocco prima della sospensione
    Lock { id: lockModule }

    // autoHide: bordo alto dello schermo che fa scendere l'isola
    EdgeReveal { island: mainIsland }

    Island {
        id: mainIsland

        // Click sui cerchi: il modulo si apre al centro dell'isola
        onLeftClicked: mediaModule.toggle()
        onRightClicked: sysmonModule.toggle()
        // Minimal: click sull'orario
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
