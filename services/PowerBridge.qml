import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    readonly property int profile: PowerProfiles.profile === PowerProfile.PowerSaver ? 0
        : PowerProfiles.profile === PowerProfile.Performance ? 2 : 1
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function set(index) {
        PowerProfiles.profile = index === 0 ? PowerProfile.PowerSaver
            : index === 2 ? PowerProfile.Performance : PowerProfile.Balanced
    }
}
