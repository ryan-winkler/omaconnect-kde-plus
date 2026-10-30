pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
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
    Row {
        width: parent.width
        spacing: Style.space(8)
        Text {
            width: Math.max(1, parent.width - refreshButton.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            text: "KDE Connect modules · " + root.modules.length
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
        }
        SettingsButton {
            id: refreshButton
            objectName: "native-module-refresh"
            text: "Refresh"
            Accessible.name: "Refresh native settings"
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: controller.ready
            onClicked: controller.refresh()
        }
    }
    Text {
        width: parent.width
        text: "On/Off changes KDE Connect on this computer. Phone permissions stay on the phone."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Kit.TextField {
        id: search
        objectName: "native-module-search"
        width: parent.width
        foreground: Commons.Color.popups.text
        placeholderText: "Search device features"
        Accessible.name: "Search native features"
        maximumLength: 128
        selectByMouse: true
    }
    Text {
        objectName: "native-module-status"
        width: parent.width
        text: !root.active ? ""
            : !root.service || root.service.daemonAvailable !== true ? "KDE Connect is unavailable."
            : !controller.device ? "Choose a device above."
            : !controller.device.paired ? "Pair this device in KDE Connect to change its native features."
            : controller.message
        visible: text !== "" && text !== "Native settings are current."
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
            id: featureRow
            required property var modelData
            readonly property real switchWidth: Math.max(88, switchMetrics.advanceWidth("Unknown") + Style.space(40))
            readonly property bool configureBelow: modelData.hasConfiguration === true
                && root.width < switchWidth + configureButton.implicitWidth + Style.font.body * 12 + Style.space(16)
            width: root.width
            spacing: Style.space(4)
            FontMetrics { id: switchMetrics; font: nativeSwitch.font }
            GridLayout {
                width: parent.width
                columns: 3
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(2)
                Controls.CheckBox {
                    id: nativeSwitch
                    objectName: "native-module-toggle-" + modelData.id
                    Layout.row: 0
                    Layout.column: 0
                    Layout.preferredWidth: featureRow.switchWidth
                    Layout.minimumWidth: featureRow.switchWidth
                    Layout.maximumWidth: featureRow.switchWidth
                    Layout.preferredHeight: Math.max(44, implicitHeight)
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    text: controller.known(modelData.id) ? controller.enabledStates[modelData.id] ? "On" : "Off" : "Unknown"
                    checked: controller.known(modelData.id) && controller.enabledStates[modelData.id] === true
                    nextCheckState: function() { return checkState }
                    enabled: controller.ready && controller.known(modelData.id)
                    activeFocusOnTab: true
                    palette.windowText: Commons.Color.popups.text
                    palette.text: Commons.Color.popups.text
                    palette.buttonText: Commons.Color.popups.text
                    palette.button: Commons.Color.popups.background
                    palette.base: Commons.Color.popups.background
                    palette.highlight: Commons.Color.accent
                    palette.highlightedText: Commons.Color.popups.background
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
                Column {
                    id: details
                    Layout.row: 0
                    Layout.column: 1
                    Layout.columnSpan: configureButton.visible && !featureRow.configureBelow ? 1 : 2
                    Layout.fillWidth: true
                    Layout.minimumWidth: 1
                    Layout.preferredWidth: Style.font.body * 12
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Style.space(2)
                    Text {
                        width: parent.width
                        text: modelData.name || modelData.id
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                    }
                    Text {
                        id: description
                        width: parent.width
                        text: modelData.description || modelData.id
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        HoverHandler { id: descriptionHover }
                        Controls.ToolTip.visible: description.truncated && descriptionHover.hovered
                        Controls.ToolTip.text: description.text
                    }
                }
                SettingsButton {
                    id: configureButton
                    objectName: "native-module-configure-" + modelData.id
                    visible: modelData.hasConfiguration === true
                    Layout.row: featureRow.configureBelow ? 1 : 0
                    Layout.column: featureRow.configureBelow ? 1 : 2
                    Layout.columnSpan: featureRow.configureBelow ? 2 : 1
                    Layout.preferredHeight: Math.max(44, implicitHeight)
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    text: "Configure ↗"
                    foreground: Commons.Color.popups.text
                    focusable: true
                    enabled: root.active && !!root.service && !!root.service.selectedDevice && root.service.selectedDevice.paired === true && !root.service.nativeAppOpening
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
