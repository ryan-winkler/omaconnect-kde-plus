pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

Column {
    required property var panel
    width: parent.width
    spacing: Style.space(8)
    Text {
        width: parent.width
        text: Locale.Strings.t("navigationSettings.dailyPopupNavigation")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        width: parent.width
        text: Locale.Strings.t("navigationSettings.toRestoreTheDefaultLayoutTurn")
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
            {key: "navigationAtTop", label: Locale.Strings.t("navigationSettings.atTop"), defaultValue: false, description: Locale.Strings.t("navigationSettings.atTopHelp")},
            {key: "showSendShortcut", label: Locale.Strings.t("navigationSettings.showSend"), defaultValue: false, description: Locale.Strings.t("navigationSettings.showSendHelp")},
            {key: "showActivityShortcut", label: Locale.Strings.t("navigationSettings.showActivity"), defaultValue: false, description: Locale.Strings.t("navigationSettings.showActivityHelp")}
        ]
    }
}
