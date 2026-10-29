pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var panel
    property var preferences: []
    property string message: ""
    readonly property bool busy: saver.running
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/network_preferences.py").toString().replace(/^file:\/\//, ""))
    spacing: Style.space(8)

    function valueFor(row) { return panel ? panel.getSetting(row.key, row.defaultValue) : row.defaultValue }
    function save(request) {
        if (busy) return
        message = "Saving setting…"
        saver.payload = JSON.stringify(request)
        saver.running = true
    }
    Repeater {
        model: root.preferences
        delegate: Column {
            id: row
            required property var modelData
            readonly property bool stringType: modelData.type === "string"
            readonly property string stored: stringType ? String(root.valueFor(modelData)) : ""
            property bool edited: false
            property string draft: stored
            onStoredChanged: if (!edited || draft === stored) { edited = false; draft = stored }
            width: parent.width
            spacing: Style.space(4)
            Kit.Toggle {
                width: parent.width
                visible: !row.stringType
                // State in words, from the saved value, not only the knob.
                label: row.modelData.label + (root.valueFor(row.modelData) === true ? ": On" : ": Off")
                checked: root.valueFor(row.modelData) === true
                enabled: !root.busy
                foreground: Commons.Color.popups.text
                Accessible.role: Accessible.CheckBox
                Accessible.name: row.modelData.label
                Accessible.checkable: true
                Accessible.checked: checked
                onClicked: root.save({key: row.modelData.key, enabled: !checked})
            }
            Text {
                width: parent.width
                visible: row.stringType
                text: row.modelData.label
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                visible: !!row.modelData.description
                text: row.modelData.description || ""
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }
            Kit.TextField {
                id: editor
                width: parent.width
                visible: row.stringType
                text: row.draft
                enabled: !root.busy
                maximumLength: 4096
                foreground: Commons.Color.popups.text
                Accessible.name: row.modelData.label
                onTextEdited: { row.edited = true; row.draft = text }
            }
            Text {
                width: parent.width
                visible: row.stringType && row.draft !== row.stored
                text: "Unsaved changes. Select Save to apply."
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }
            Kit.Button {
                width: parent.width
                visible: row.stringType
                text: "Save " + row.modelData.label
                Accessible.name: text
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: !root.busy && row.draft !== row.stored
                onClicked: root.save({key: row.modelData.key, value: row.draft})
            }
        }
    }
    Text {
        width: parent.width
        visible: text !== ""
        text: root.message
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Process {
        id: saver
        property string payload: ""
        property bool oversized: false
        command: ["/usr/bin/timeout", "5", "/usr/bin/python3", root.helperPath]
        stdinEnabled: true
        onStarted: { oversized = false; write(payload); stdinEnabled = false }
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if (text.length > 8192) { saver.oversized = true; saver.running = false }
        }
        onExited: function(code) {
            var result
            try { result = !oversized ? JSON.parse(reply.text) : null } catch (_) { result = null }
            root.message = result && typeof result.ok === "boolean" && typeof result.message === "string" && result.message.length < 512
                && (code === 0) === result.ok ? result.message : "Setting was not confirmed. Check the saved value and try again."
            stdinEnabled = true
        }
    }
}
