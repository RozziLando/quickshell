import QtQuick
import qs.services
import qs.widgets

OptionRow {
    id: row

    property string key: ""
    property bool checked: false

    Switch {
        sizeFactor: SettingsUi.factor
        checked: row.checked
        onToggled: if (row.key !== "") Settings.set(row.key, !row.checked)
    }
}
