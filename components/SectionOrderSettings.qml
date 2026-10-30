pragma ComponentBehavior: Bound
import QtQuick
import QtQml.Models as Models
import qs.Commons
import qs.Commons as Commons
import "../SectionOrder.js" as SectionOrder

Column {
    id: root
    required property var panel
    readonly property var catalog: panel ? panel.sectionCatalog : null
    readonly property var order: catalog ? catalog.order : []
    readonly property bool busy: saver.busy
    readonly property string message: saver.message
    width: parent ? parent.width : 0
    spacing: Style.space(8)

    function moveSection(id, delta) {
        if (!catalog || !catalog.ready) return
        var next = SectionOrder.move(order, id, delta)
        if (next) saver.save({key: "sectionOrder", value: next.join(",")})
    }

    // Move live rows on readback so their controls keep identity and focus.
    function reconcileRows() {
        var focused = null, moved = false
        for (var i = 0; i < sectionRows.count; ++i) {
            var row = rowRepeater.itemAt(i)
            if (row && row.upControl.activeFocus) focused = {control: row.upControl, neighbor: row.downControl}
            if (row && row.downControl.activeFocus) focused = {control: row.downControl, neighbor: row.upControl}
        }
        for (var target = 0; target < order.length; ++target) {
            var from = target
            while (from < sectionRows.count && sectionRows.get(from).sectionId !== order[target]) ++from
            if (from === sectionRows.count) sectionRows.append({sectionId: order[target]})
            if (from !== target) { sectionRows.move(from, target, 1); moved = true }
        }
        if (focused && moved) {
            var next = focused.control.enabled ? focused.control : focused.neighbor
            if (next.enabled) next.forceActiveFocus()
        }
    }
    onOrderChanged: Qt.callLater(root.reconcileRows)
    Component.onCompleted: Qt.callLater(root.reconcileRows)
    Models.ListModel { id: sectionRows }

    Text {
        width: parent.width
        text: "Daily section order"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        width: parent.width
        text: "Use Up or Down to move a complete section in Devices. Hidden sections keep their position. The order applies to all devices. Visibility and start-expanded choices stay in each settings domain."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Repeater {
        id: rowRepeater
        model: sectionRows
        delegate: Column {
            required property string sectionId
            required property int index
            readonly property var entry: root.catalog.entry(sectionId)
            readonly property var upControl: moveUp
            readonly property var downControl: moveDown
            readonly property bool shown: !entry.visibilityKey || root.panel.getSetting(entry.visibilityKey, entry.defaultVisible) === true
            objectName: "section-order-row-" + sectionId
            width: parent.width
            spacing: Style.space(4)
            Text {
                width: parent.width
                text: (index + 1) + ". " + entry.label + " · " + (!entry.visibilityKey ? "Always shown" : shown ? "Show when available" : "Hidden")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Flow {
                width: parent.width
                spacing: Style.space(6)
                SettingsButton {
                    id: moveUp
                    text: "Up"
                    height: Math.max(44, implicitHeight)
                    Accessible.name: "Move " + entry.label + " up"
                    Accessible.description: "Move this complete section before the previous section. Hidden sections keep their position."
                    focusable: true
                    foreground: Commons.Color.popups.text
                    enabled: index > 0
                    onClicked: root.moveSection(sectionId, -1)
                }
                SettingsButton {
                    id: moveDown
                    text: "Down"
                    height: Math.max(44, implicitHeight)
                    Accessible.name: "Move " + entry.label + " down"
                    Accessible.description: "Move this complete section after the next section. Hidden sections keep their position."
                    focusable: true
                    foreground: Commons.Color.popups.text
                    enabled: index < root.order.length - 1
                    onClicked: root.moveSection(sectionId, 1)
                }
            }
        }
    }
    Text {
        width: parent.width
        text: root.catalog ? root.catalog.error : "Section settings are unavailable. Reopen Plus settings."
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        text: "Use default section order"
        width: parent.width
        height: Math.max(44, implicitHeight)
        Accessible.name: text
        Accessible.description: "Reset only section order. Visibility, collapse defaults and device settings stay saved."
        focusable: true
        foreground: Commons.Color.popups.text
        enabled: !!root.catalog && root.catalog.ready
        onClicked: saver.save({key: "sectionOrder", value: ""})
    }
    PreferenceControls {
        id: saver
        width: parent.width
        panel: root.panel
    }
}
