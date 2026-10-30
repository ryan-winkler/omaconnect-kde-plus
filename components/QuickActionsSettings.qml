pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../ActionCatalog.js" as Actions

Column {
    id: root
    required property var panel
    readonly property var device: panel ? panel.device : null
    readonly property var service: panel && "service" in panel ? panel.service : null
    readonly property string storedOrder: panel ? panel.getSetting("quickActionsOrder", Actions.DEFAULT_ORDER) : Actions.DEFAULT_ORDER
    readonly property var order: Actions.order(storedOrder)
    readonly property var addable: Actions.entries.filter(function(row) { return root.order.indexOf(row.id) < 0; }).map(function(row) { return {value:row.id,label:row.label,description:row.group + " · " + row.description}; })
    readonly property var selectedEntry: Actions.entry(selectedAction)
    property string selectedAction: ""
    property string message: ""
    readonly property bool busy: saver.running
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/network_preferences.py").toString().replace(/^file:\/\//, ""))
    spacing: Style.space(8)
    onOrderChanged: if (order.indexOf(selectedAction) >= 0) selectedAction = ""

    function saveOrder(ids) {
        if (busy || !Array.isArray(ids)) return false
        var csv=ids.join(",")
        if (Actions.parse(csv) === null) return false
        message = "Saving quick actions…"
        saver.payload=JSON.stringify({key:"quickActionsOrder",value:csv})
        saver.running=true
        return true
    }
    function addAction(id) {
        if (!Actions.entry(id) || order.indexOf(id) >= 0) return false
        return saveOrder(order.concat([id]))
    }
    function removeAction(id) { return saveOrder(order.filter(function(value) { return value !== id; })) }
    function moveAction(id,delta) {
        var ids=order.slice(), index=ids.indexOf(id), target=index+delta
        if (index<0 || (delta!==-1 && delta!==1) || target<0 || target>=ids.length) return false
        ids.splice(index,1);ids.splice(target,0,id)
        return saveOrder(ids)
    }
    Text {
        width: parent.width
        text: "Choose an action, then select Add selected action. Use Up, Down and Remove to arrange your toolbar."
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Text {
        width: parent.width
        visible: Actions.parse(root.storedOrder) === null
        text: "Your saved action list could not be read, so the defaults are shown. Select Use default actions to fix it."
        textFormat: Text.PlainText
        color: Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Kit.SearchableDropdown {
        width: parent.width
        label: "Add action"
        options: root.addable
        value: root.selectedAction
        triggerLabel: "Choose an action…"
        foreground: Commons.Color.popups.text
        enabled: !root.busy && root.addable.length > 0
        onChanged: function(value) { root.selectedAction = value }
    }
    Text {
        width: parent.width
        visible: !!root.selectedEntry
        text: root.selectedEntry ? root.selectedEntry.description + "\n" + Actions.availabilityText(root.selectedAction,root.device,root.service) : ""
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    SettingsButton {
        width: parent.width
        text: "Add selected action"
        Accessible.name: text
        focusable: true
        foreground: Commons.Color.popups.text
        enabled: !root.busy && root.selectedAction !== "" && root.order.indexOf(root.selectedAction) < 0
        onClicked: root.addAction(root.selectedAction)
    }
    Repeater {
        model: root.order
        delegate: Column {
            required property string modelData
            required property int index
            readonly property var action: Actions.entry(modelData)
            width: parent.width
            spacing: Style.space(4)
            Text {
                width: parent.width
                text: action.label
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }
            Text {
                width: parent.width
                text: action.description + "\n" + Actions.availabilityText(modelData,root.device,root.service)
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
            }
            Flow {
                width: parent.width
                spacing: Style.space(6)
                SettingsButton {
                    text: "Up"
                    Accessible.name: "Move " + action.label + " up"
                    focusable: true
                    foreground: Commons.Color.popups.text
                    enabled: !root.busy && index > 0
                    onClicked: root.moveAction(modelData,-1)
                }
                SettingsButton {
                    text: "Down"
                    Accessible.name: "Move " + action.label + " down"
                    focusable: true
                    foreground: Commons.Color.popups.text
                    enabled: !root.busy && index < root.order.length - 1
                    onClicked: root.moveAction(modelData,1)
                }
                SettingsButton {
                    text: "Remove"
                    Accessible.name: "Remove " + action.label + " quick action"
                    focusable: true
                    foreground: Commons.Color.popups.text
                    enabled: !root.busy
                    onClicked: root.removeAction(modelData)
                }
            }
        }
    }
    Text {
        width: parent.width
        text: "Find every other KDE Connect feature in Device features."
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Text {
        width: parent.width
        visible: root.order.length === 0
        text: "Your toolbar is empty. Choose an action above, then select Add selected action."
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    SettingsButton {
        width: parent.width
        text: "Use default actions"
        Accessible.name: text
        focusable: true
        foreground: Commons.Color.popups.text
        enabled: !root.busy && root.storedOrder !== Actions.DEFAULT_ORDER
        onClicked: root.saveOrder(Actions.DEFAULT_ORDER.split(","))
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
        command: ["/usr/bin/timeout","5","/usr/bin/python3",root.helperPath]
        stdinEnabled: true
        onStarted: { oversized=false;write(payload);stdinEnabled=false }
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if(text.length>8192){saver.oversized=true;saver.running=false}
        }
        onExited: function(code) {
            var result
            try { result=!oversized ? JSON.parse(reply.text) : null } catch(_){result=null}
            root.message=result && typeof result.ok === "boolean" && typeof result.message === "string" && result.message.length<512 && (code===0)===result.ok
                ? result.message : "Quick actions were not confirmed. The saved order is still shown. Try again."
            stdinEnabled=true
        }
    }
}
