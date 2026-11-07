pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../TransferModel.js" as Transfers
import "../i18n" as Locale

Column {
    id: root
    required property var service
    spacing: Style.space(8)
    Text {
        objectName: "task-notification-status"
        width: parent.width
        visible: text !== ""
        text: root.service && "taskNotificationMessage" in root.service ? root.service.taskNotificationMessage : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
        Accessible.name: text
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("activity.kdeSubmissionActivity")

        color: Commons.Color.popups.text
        font.bold: true
        font.pixelSize: Style.font.body
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        objectName: "activity-delivery-help"
        text: Locale.Strings.t("activity.deliveryHelp")

        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.bodySmall
    }
    Repeater {
        model: root.service ? root.service.operations : []
        delegate: Text {
            objectName: "submission-summary"
            textFormat: Text.PlainText
            required property var modelData
            width: root.width
            text: Transfers.activitySummary(modelData, root.service.operations, Locale.Strings)
                + "\n" + Transfers.status(modelData, Locale.Strings)

            wrapMode: Text.WrapAnywhere
            color: Commons.Color.popups.text
            font.pixelSize: Style.font.bodySmall
            Accessible.name: text
        }
    }
    SettingsButton {
        width: parent.width
        text: Locale.Strings.t("activity.clearFinishedActivity")
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service
        Accessible.name: text
        onClicked: root.service.clearOperations()
    }
}
