pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var panel
    required property string page
    readonly property var catalog: panel && "sectionCatalog" in panel ? panel.sectionCatalog : null
    width: parent ? parent.width : 0
    spacing: Style.space(12)
    Text {
        width: parent.width
        text: "Devices view"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        width: parent.width
        text: "These display choices apply to all devices. They do not change native permissions."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Repeater {
        model: root.catalog ? root.catalog.entries.filter(function(entry) { return entry.settingsPage === root.page }) : []
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: Style.space(6)
            Text {
                width: parent.width
                text: modelData.label
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }
            PreferenceControls {
                width: parent.width
                panel: root.panel
                preferences: {
                    var entry = parent.modelData
                    var fields = root.catalog.preferencesFor(root.page).filter(function(row) {
                        return row.key === entry.visibilityKey || row.key === entry.expandedKey
                    })
                    return fields.map(function(row) {
                        var result = Object.assign({}, row)
                        result.accessibleName = row.label
                        result.label = row.key === entry.visibilityKey ? "Show in Devices" : "Start expanded"
                        return result
                    })
                }
            }
        }
    }
}
