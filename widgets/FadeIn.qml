import QtQuick

// Comparsa del contenuto di un modulo: quando "active" diventa vero il
// genitore parte trasparente e compare in dissolvenza dopo una pausa (la
// pillola intanto si allarga); quando diventa falso sparisce subito.
//
//   FadeIn { active: root.shown; pause: 160; duration: 220 }
//
// Va messo dentro l'elemento da far comparire, al posto di
// "opacity: ... + Behavior on opacity". Con un Behavior l'esito dipendeva
// dall'ordine in cui Qt aggiorna i binding: a volte la durata era ancora 0
// e il contenuto compariva di colpo dentro la pillola ancora piccola.
// Qui l'animazione parte da un segnale, sempre con la sua durata.
// Invisibile e senza misura: Column e Row lo saltano.
Item {
    id: fade

    property bool active: false
    property int pause: 100
    property int duration: 250
    // true: compare subito, senza pausa né dissolvenza (es. passaggio
    // diretto da un altro pannello già aperto: il contenuto resta visibile)
    property bool instant: false

    visible: false
    width: 0
    height: 0

    SequentialAnimation {
        id: anim
        PauseAnimation { duration: fade.pause }
        NumberAnimation {
            target: fade.parent
            property: "opacity"
            to: 1
            duration: fade.duration
        }
    }

    onActiveChanged: {
        anim.stop()
        if (!fade.parent) return
        if (active && instant) {
            fade.parent.opacity = 1
            return
        }
        fade.parent.opacity = 0
        if (active) anim.start()
    }

    Component.onCompleted: if (fade.parent) fade.parent.opacity = active ? 1 : 0
}
