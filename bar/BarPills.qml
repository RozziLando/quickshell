import QtQuick
import qs.services

Item {
    id: group

    required property var stage
    property var pills: []
    property string zone: ""

    implicitWidth: stage.vertical ? stage.itemSize : row.implicitWidth
    implicitHeight: stage.vertical ? row.implicitHeight : stage.itemSize
    width: implicitWidth
    height: implicitHeight
    visible: pills.length > 0

    Grid {
        id: row
        x: group.stage.barEdge === "right" ? group.width - width : 0
        y: group.stage.barEdge === "bottom" ? group.height - height : 0
        verticalItemAlignment: group.stage.barEdge === "bottom" ? Grid.AlignBottom : Grid.AlignTop
        horizontalItemAlignment: group.stage.barEdge === "right" ? Grid.AlignRight : Grid.AlignLeft
        columns: group.stage.vertical ? 1 : Math.max(1, group.pills.length)
        spacing: group.stage.pillSpace
        move: Transition {
            NumberAnimation { properties: "x,y"; duration: 220; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: group.pills
            delegate: BarPill {
                required property var modelData
                required property int index
                stage: group.stage
                kinds: modelData
                zone: group.zone
                slot: index
            }
        }
    }
}
