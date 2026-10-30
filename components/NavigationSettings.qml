pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    required property var panel
    width: parent.width
    spacing: Style.space(8)
    Text {
        width: parent.width
        text: "Daily popup navigation"
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        width: parent.width
        text: "To restore the default layout, turn all three options off."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
    }
    PreferenceControls {
        width: parent.width
        panel: parent.panel
        preferences: [
            {key: "navigationAtTop", label: "Place navigation at Top", defaultValue: false, description: "Off places navigation at Bottom, so devices come first. The position stays fixed until you change it."},
            {key: "showSendShortcut", label: "Show a direct Send shortcut", defaultValue: false, description: "Add Send beside the current-view menu. Send remains in the menu when this shortcut is hidden."},
            {key: "showActivityShortcut", label: "Show a direct Activity shortcut", defaultValue: false, description: "Add Activity beside the current-view menu. Submission state stays visible, and Activity remains in the menu when hidden."}
        ]
    }
}
