pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var service
    property var modules: []
    property bool active: false
    property alias searchText: search.text
    property alias backend: controller
    signal configureRequested(string pluginId)
    readonly property var filteredModules: {
        var query = search.text.trim().toLowerCase()
        return modules.filter(function(entry) {
            return entry && controller.pluginIds.indexOf(entry.id) >= 0
                && (!query || (entry.id + " " + entry.name + " " + entry.description).toLowerCase().indexOf(query) >= 0)
        })
    }
    width: parent ? parent.width : 0
    spacing: Style.space(8)
    NativeModuleController { id: controller; service: root.service; modules: root.modules; active: root.active }
    Text {
        width: parent.width
        text: "Features on this computer for the selected device"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        width: parent.width
        text: "On and Off are native KDE Connect settings. A feature can be On while this device is offline. Configure opens its native settings. Phone permissions stay on the phone."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        text: "Search native features"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        id: search
        objectName: "native-module-search"
        width: parent.width
        foreground: Commons.Color.popups.text
        placeholderText: "Feature name or plugin ID"
        Accessible.name: "Search native features"
        maximumLength: 128
        selectByMouse: true
    }
    SettingsButton {
        objectName: "native-module-refresh"
        width: parent.width
        text: "Refresh native settings"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: controller.ready && !controller.busy
        onClicked: controller.refresh()
    }
    Text {
        objectName: "native-module-status"
        width: parent.width
        text: !root.active ? ""
            : !root.service || root.service.daemonAvailable !== true ? "KDE Connect is unavailable."
            : !controller.device ? "Choose a device above."
            : !controller.device.paired ? "Pair this device in KDE Connect to change its native features."
            : controller.message
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    Repeater {
        model: root.filteredModules
        delegate: Column {
            required property var modelData
            width: root.width
            spacing: Style.space(2)
            Text {
                width: parent.width
                text: modelData.name || modelData.id
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }
            Text {
                width: parent.width
                text: modelData.description || modelData.id
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Row {
                width: parent.width
                spacing: Style.space(8)
                Controls.CheckBox {
                    id: nativeSwitch
                    objectName: "native-module-toggle-" + modelData.id
                    width: Math.max(100, parent.width - configureButton.width - parent.spacing)
                    height: Math.max(44, implicitHeight)
                    text: controller.known(modelData.id) ? controller.enabledStates[modelData.id] ? "On" : "Off" : "Unknown"
                    checked: controller.known(modelData.id) && controller.enabledStates[modelData.id] === true
                    nextCheckState: function() { return checkState }
                    enabled: controller.ready && !controller.busy && controller.known(modelData.id)
                    activeFocusOnTab: true
                    palette.windowText: Commons.Color.popups.text
                    palette.text: Commons.Color.popups.text
                    palette.buttonText: Commons.Color.popups.text
                    Accessible.role: Accessible.CheckBox
                    Accessible.checkable: true
                    Accessible.checked: checked
                    Accessible.name: "Enable " + (modelData.name || modelData.id)
                    Accessible.description: (modelData.description || "") + ". Native setting: " + text + ". On this computer for the selected device."
                    function requestChange() { if (enabled) controller.setEnabled(modelData.id, !checked) }
                    onClicked: requestChange()
                    Accessible.onToggleAction: requestChange()
                    Accessible.onPressAction: requestChange()
                }
                SettingsButton {
                    id: configureButton
                    objectName: "native-module-configure-" + modelData.id
                    visible: modelData.hasConfiguration === true
                    width: visible ? implicitWidth : 0
                    height: Math.max(44, implicitHeight)
                    text: "Configure ↗"
                    foreground: Commons.Color.popups.text
                    focusable: true
                    enabled: controller.ready
                    Accessible.name: "Configure " + (modelData.name || modelData.id) + " in KDE Connect"
                    Accessible.description: "Open native configuration on this computer for the selected device."
                    onClicked: if (enabled) root.configureRequested(modelData.id)
                }
            }
            Rectangle { width: parent.width; height: 1; color: Commons.Color.popups.border }
        }
    }
    Text {
        width: parent.width
        visible: root.filteredModules.length === 0
        text: root.modules.length ? "No matching native features. Clear the search to see all installed features." : "Native feature metadata is unavailable. Open KDE Connect Plugin Settings."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
}
