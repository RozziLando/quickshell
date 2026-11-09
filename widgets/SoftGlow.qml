import QtQuick
import QtQuick.Effects
import qs.services

// Effetto attorno a un elemento (al posto del bordo), così l'isola si stacca
// anche da sfondi scuri. Si usa come layer.effect.
//   - alone: colore "glow" del tema, centrato e stretto
//   - ombra scura ("darkShadow" in theme.json): nera, più ampia, spostata in
//     basso come quella delle finestre di Hyprland
MultiEffect {
    readonly property bool dark: Theme.darkShadow

    shadowEnabled: true
    shadowColor: dark ? "#90000000" : Theme.glow
    shadowBlur: dark ? 0.7 : 0.35
    blurMax: dark ? 24 : 12
    shadowHorizontalOffset: 0
    shadowVerticalOffset: dark ? Theme.s(3) : 0
    autoPaddingEnabled: true
}
