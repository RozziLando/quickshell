import QtQuick
import Quickshell
import qs.services

Scope {
    id: root

    property var lock: null

    BarStage {
        id: stage
        lock: root.lock
    }

    Variants {
        model: ["top", "bottom", "left", "right"]

        Reserve {
            required property string modelData
            edge: modelData
            screen: stage.screen
            size: modelData === stage.barEdge ? (stage.reserving ? stage.extent : 0)
                : (stage.frameOn && !stage.fullscreen ? stage.frameSize : 0)
        }
    }
}
