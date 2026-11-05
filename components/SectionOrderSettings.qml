pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var panel
    width: parent ? parent.width : 0
    spacing: Style.space(8)
    Text {
        width: parent.width
        text: "Edit section visibility and order in Devices. Hidden sections stay available while editing."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        width: parent.width
        text: "Edit Devices layout"
        Accessible.name: text
        focusable: true
        foreground: Commons.Color.popups.text
        enabled: root.panel && typeof root.panel.setLayoutEditing === "function"
        onClicked: {
            root.panel.settingsWindow.closeSettings()
            root.panel.currentView = "Devices"
            root.panel.open()
            root.panel.setLayoutEditing(true)
        }
    }
    PreferenceControls {
        width: parent.width
        panel: root.panel
        preferences: [
            {key: "showEditLayoutShortcut", label: "Show Edit layout in Devices", defaultValue: true, description: "Show the pencil beside Plus settings. You can always open the layout editor here."}
        ]
    }
}
