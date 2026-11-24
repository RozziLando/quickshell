import QtQuick
import qs.services

Item {
    id: section

    required property var stage
    property var kinds: []

    implicitWidth: stage.vertical ? stage.itemSize : grid.implicitWidth
    implicitHeight: stage.vertical ? grid.implicitHeight : stage.itemSize
    visible: kinds.length > 0

    Grid {
        id: grid
        anchors.centerIn: parent
        columns: section.stage.vertical ? 1 : Math.max(1, section.kinds.length)
        spacing: Theme.s(2)
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: section.kinds
            delegate: BarItem {
                required property string modelData
                kind: modelData
                stage: section.stage
            }
        }
    }
}
