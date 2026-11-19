import QtQuick
import qs.services
import qs.widgets

Item {
    id: menuLayer

    anchors.fill: parent
    readonly property var menu: SettingsUi.menu
    visible: menu !== null

    function u(v) { return SettingsUi.u(v) }

    property real boxX: 0
    property real edgeY: 0
    property bool upward: false
    property int boxW: 0
    property int maxH: 0
    property string query: ""
    property var selection: []
    readonly property bool multi: !!(menu && menu.multi)
    readonly property bool hasTitle: !!(menu && menu.title)
    readonly property int titleH: hasTitle ? titleColumn.implicitHeight + u(10) : 0

    function selected(value) {
        if (!menu) return false
        if (!multi) return value === menu.current
        return value === "" ? selection.length === 0 : selection.indexOf(value) >= 0
    }

    readonly property bool searchable: !!(menu && menu.searchable)
    readonly property var filtered: {
        if (!menu) return []
        var q = query.trim().toLowerCase()
        return menu.items.filter(function (it) {
            return q === "" || String(it.label).toLowerCase().indexOf(q) >= 0
                || String(it.detail || "").toLowerCase().indexOf(q) >= 0
        })
    }

    function rowHeight(it) { return it.image ? u(46) : u(32) }

    function place() {
        var a = menu.anchor
        if (!a) return
        var w = Math.max(u(170), menu.width || a.width)
        var p = a.mapToItem(menuLayer, 0, 0)
        boxW = Math.min(w, menuLayer.width - u(16))
        boxX = Math.max(u(8), Math.min(p.x + a.width - boxW, menuLayer.width - boxW - u(8)))
        var total = 2 * u(6) + (menu.searchable ? u(36) : 0) + (menu.title ? u(50) : 0)
        for (var i = 0; i < menu.items.length && total < u(340); i++) total += rowHeight(menu.items[i]) + u(2)
        var want = Math.min(total, u(320))
        var below = menuLayer.height - (p.y + a.height) - u(14)
        var above = p.y - u(14)
        upward = want > below && above > below
        maxH = Math.max(u(60), Math.min(want, upward ? above : below))
        edgeY = upward ? p.y - u(6) : p.y + a.height + u(6)
    }

    onMenuChanged: {
        query = ""
        search.text = ""
        if (!menu) {
            if (catcher.activeFocus || search.activeFocus) parent.forceActiveFocus()
            return
        }
        selection = menu.multi && Array.isArray(menu.current) ? menu.current.slice() : []
        place()
        var idx = 0
        for (var i = 0; i < menu.items.length; i++) {
            var v = menu.items[i].value
            if (menu.multi ? selection.indexOf(v) >= 0 : v === menu.current) { idx = i; break }
        }
        list.currentIndex = idx
        list.positionViewAtIndex(idx, ListView.Center)
        if (menu.searchable) search.forceActiveFocus()
        else catcher.forceActiveFocus()
    }

    function pick(it) {
        if (!it || !menu) return
        if (menu.multi) {
            var next = []
            if (it.value !== "") {
                next = selection.slice()
                var at = next.indexOf(it.value)
                if (at >= 0) next.splice(at, 1)
                else next.push(it.value)
            }
            selection = next
            if (menu.pick) menu.pick(next.slice())
            return
        }
        var fn = menu.pick
        SettingsUi.closeMenu()
        if (fn) fn(it.value)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: SettingsUi.closeMenu()
        onWheel: wheel => wheel.accepted = true
    }

    Item {
        id: catcher
        Keys.onEscapePressed: SettingsUi.closeMenu()
        Keys.onUpPressed: list.decrementCurrentIndex()
        Keys.onDownPressed: list.incrementCurrentIndex()
        Keys.onReturnPressed: menuLayer.pick(menuLayer.filtered[list.currentIndex])
    }

    Rectangle {
        id: box
        x: menuLayer.boxX
        y: menuLayer.upward ? menuLayer.edgeY - height : menuLayer.edgeY
        width: menuLayer.boxW
        height: Math.min(menuLayer.maxH, 2 * menuLayer.u(6) + menuLayer.titleH + (menuLayer.searchable ? menuLayer.u(36) : 0)
                                     + Math.max(menuLayer.u(32), list.contentHeight))
        radius: SettingsUi.radius
        color: Theme.background
        border.width: 1
        border.color: Theme.cardBorder

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => wheel.accepted = false
        }

        Column {
            id: titleColumn
            visible: menuLayer.hasTitle
            x: menuLayer.u(12)
            y: menuLayer.u(10)
            width: parent.width - 2 * menuLayer.u(12)
            spacing: menuLayer.u(2)

            Text {
                width: parent.width
                text: menuLayer.menu && menuLayer.menu.title ? menuLayer.menu.title : ""
                color: Theme.text
                font.pixelSize: menuLayer.u(11)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: menuLayer.menu && menuLayer.menu.hint ? menuLayer.menu.hint : ""
                color: Theme.textSecondary
                font.pixelSize: menuLayer.u(9)
                font.family: Theme.fontFamily
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            id: searchBox
            visible: menuLayer.searchable
            x: menuLayer.u(6)
            y: menuLayer.u(6) + menuLayer.titleH
            width: parent.width - 2 * menuLayer.u(6)
            height: menuLayer.u(30)
            radius: SettingsUi.radius
            color: Theme.highlight

            LineIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: menuLayer.u(10)
                anchors.verticalCenter: parent.verticalCenter
                kind: "search"
                size: menuLayer.u(12)
                color: Theme.textSecondary
            }

            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: menuLayer.u(8)
                anchors.right: parent.right
                anchors.rightMargin: menuLayer.u(10)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                selectionColor: Theme.selection
                font.pixelSize: menuLayer.u(10)
                font.family: Theme.fontFamily
                clip: true
                onTextChanged: {
                    menuLayer.query = text
                    list.currentIndex = 0
                }
                Keys.onEscapePressed: SettingsUi.closeMenu()
                Keys.onUpPressed: list.decrementCurrentIndex()
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onReturnPressed: menuLayer.pick(menuLayer.filtered[list.currentIndex])
                Keys.onEnterPressed: menuLayer.pick(menuLayer.filtered[list.currentIndex])

                Text {
                    visible: search.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Search..."
                    color: Theme.textMuted
                    font: search.font
                }
            }
        }

        ListView {
            id: list
            anchors {
                top: menuLayer.searchable ? searchBox.bottom : parent.top
                topMargin: menuLayer.u(6) + (menuLayer.searchable ? 0 : menuLayer.titleH)
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                leftMargin: menuLayer.u(6)
                rightMargin: menuLayer.u(6)
                bottomMargin: menuLayer.u(6)
            }
            clip: true
            spacing: menuLayer.u(2)
            boundsBehavior: Flickable.StopAtBounds
            model: menuLayer.filtered
            highlightMoveDuration: 0
            keyNavigationWraps: false

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool isCurrent: menuLayer.selected(modelData.value)
                readonly property bool lit: rowArea.containsMouse || ListView.isCurrentItem

                width: ListView.view.width
                height: menuLayer.rowHeight(modelData)
                radius: SettingsUi.radius
                color: lit ? Theme.surface : "transparent"

                WallpaperThumb {
                    id: thumb
                    visible: !!row.modelData.image
                    anchors.left: parent.left
                    anchors.leftMargin: menuLayer.u(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? menuLayer.u(60) : 0
                    height: menuLayer.u(34)
                    radius: SettingsUi.radius
                    wallpaper: row.modelData.image || ({})
                }

                Row {
                    id: dots
                    visible: !!row.modelData.dots
                    anchors.left: thumb.right
                    anchors.leftMargin: menuLayer.u(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: menuLayer.u(3)
                    width: visible ? implicitWidth : 0
                    Repeater {
                        model: row.modelData.dots || []
                        delegate: Rectangle {
                            required property var modelData
                            width: menuLayer.u(9)
                            height: width
                            radius: width / 2
                            color: modelData || "transparent"
                        }
                    }
                }

                Text {
                    id: label
                    anchors.left: dots.right
                    anchors.leftMargin: menuLayer.u(dots.visible || thumb.visible ? 10 : 6)
                    anchors.right: trailing.left
                    anchors.rightMargin: menuLayer.u(8)
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: row.isCurrent ? Theme.accent : Theme.text
                    font.pixelSize: menuLayer.u(10)
                    font.weight: row.isCurrent ? Font.DemiBold : Font.Normal
                    font.family: row.modelData.font || Theme.fontFamily
                    elide: Text.ElideRight
                }

                Row {
                    id: trailing
                    anchors.right: parent.right
                    anchors.rightMargin: menuLayer.u(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: menuLayer.u(8)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!row.modelData.sample
                        text: row.modelData.sample || ""
                        color: Theme.textSecondary
                        font.pixelSize: menuLayer.u(13)
                        font.family: row.modelData.sampleFont || Theme.fontFamily
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!row.modelData.detail
                        text: row.modelData.detail || ""
                        color: Theme.textMuted
                        font.pixelSize: menuLayer.u(9)
                        font.family: Theme.fontFamily
                    }
                    LineIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        kind: "check"
                        size: menuLayer.u(12)
                        color: Theme.accent
                        opacity: row.isCurrent ? 1 : 0
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menuLayer.pick(row.modelData)
                }
            }
        }

        Text {
            anchors.centerIn: list
            visible: list.count === 0
            text: "Nothing found"
            color: Theme.textMuted
            font.pixelSize: menuLayer.u(10)
            font.family: Theme.fontFamily
        }
    }
}
