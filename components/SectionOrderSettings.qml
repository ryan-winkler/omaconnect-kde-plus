pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

Column {
    id: root
    required property var panel
    width: parent ? parent.width : 0
    spacing: Style.space(8)
    Text {
        width: parent.width
        text: Locale.Strings.t("layout.settingsHelp")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SettingsButton {
        width: parent.width
        text: Locale.Strings.t("layout.editDevices")
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
            {key: "showEditLayoutShortcut", label: Locale.Strings.t("layout.showShortcut"), defaultValue: true, description: Locale.Strings.t("layout.shortcutHelp")}
        ]
    }
}
