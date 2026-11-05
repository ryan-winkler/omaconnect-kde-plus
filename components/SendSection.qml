pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../TransferModel.js" as TransferModel
import "../i18n" as Locale

Column {
    id: root
    required property var service
    property var device: null
    property color foreground: "#ffffff"
    property string fontFamily: "sans-serif"
    readonly property var target: service ? service.draftTarget : null
    readonly property var files: service ? service.selection : []
    readonly property var activity: service ? service.operations : []
    property bool showAllActivity: false
    property bool showHeading: true

    width: parent ? parent.width : 0
    spacing: Style.space(8)
    visible: !!target || (service && service.selectionError !== "") || activity.length > 0

    Text {
        visible: root.showHeading
        textFormat: Text.PlainText
        width: parent.width
        text: Locale.Strings.t("files.sendHeading")

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
    }

    Text {
        textFormat: Text.PlainText
        visible: !!root.target
        width: parent.width
        text: root.target ? Locale.Strings.format("files.recipient",
            ["\u2068" + root.target.peerName + "\u2069", "\u2068" + root.target.peerId + "\u2069"]) : ""

        wrapMode: Text.WrapAnywhere
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        textFormat: Text.PlainText
        visible: !!root.target
        width: parent.width
        text: root.service && root.service.selectionState === "choosing" ? Locale.Strings.t("files.chooseHelp")
            : root.service && root.service.selectionState === "preview" ? Locale.Strings.t("files.previewHelp")
            : Locale.Strings.t("files.reviewSummary").arg(Locale.Strings.fileCount(root.files.length))
                .arg(Locale.Strings.byteSize(root.service ? root.service.selectionBytes : 0))

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        textFormat: Text.PlainText
        visible: root.files.length > 0
        width: parent.width
        text: Locale.Strings.t("send.filesInSharedLocationsCanNeed")
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Controls.ScrollView {
        visible: root.files.length > 0
        width: parent.width
        height: Math.min(160, selectionList.implicitHeight)
        clip: true
        contentWidth: availableWidth
        Column {
            id: selectionList
            width: parent.width
            spacing: Style.space(4)
            Repeater {
                model: root.files
                Text {
                    textFormat: Text.PlainText
                    required property var modelData
                    width: selectionList.width
                    text: "\u2068" + modelData.name + "\u2069 · " + Locale.Strings.byteSize(modelData.size)

                    wrapMode: Text.WrapAnywhere
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                }
            }
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: root.service && root.service.selectionError !== ""
        width: parent.width
        text: root.service ? root.service.selectionError : ""

        wrapMode: Text.Wrap
        color: Commons.Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Flow {
        width: parent.width
        visible: !!root.target
        spacing: Style.space(8)
        SettingsButton {
            bordered: false
            focusable: true
            text: Locale.Strings.t("files.send")
            implicitHeight: Math.max(44, Style.space(44))
            enabled: root.service && root.service.selectionState === "draft" && root.files.length > 0 && !root.service.operationBusy
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.submitSelection()
        }
        SettingsButton {
            bordered: false
            focusable: true
            objectName: "cancel-file-selection"
            text: Locale.Strings.t("common.cancel")
            Accessible.description: Locale.Strings.t("send.cancelThisFileSelectionBeforeSubmission")
            implicitHeight: Math.max(44, Style.space(44))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.cancelDraft()
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: root.activity.length > 0
        text: Locale.Strings.t("send.recentSubmissions")

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
    }

    Repeater {
        model: root.showAllActivity ? root.activity : root.activity.slice(0, 5)
        Column {
            id: operationRow
            required property var modelData
            width: root.width
            spacing: Style.space(4)
            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: "\u2068" + operationRow.modelData.peerName + "\u2069 · KDE Connect · "
                    + Locale.Strings.fileCount(operationRow.modelData.count) + " · " + Locale.Strings.byteSize(operationRow.modelData.total)

                wrapMode: Text.WrapAnywhere
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }
            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: TransferModel.status(operationRow.modelData, Locale.Strings)

                wrapMode: Text.Wrap
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
            }
        }
    }

    Flow {
        width: parent.width
        visible: root.activity.length > 0
        spacing: Style.space(8)
        SettingsButton {
            bordered: false
            focusable: true
            visible: root.service && root.service.operationBusy
            objectName: "cancel-file-submission"
            text: root.service && root.service.cancellationRequested === true ? Locale.Strings.t("files.cancelling") : Locale.Strings.t("common.cancel")
            enabled: !!root.service && root.service.cancellationRequested !== true
            Accessible.description: Locale.Strings.t("send.stopPendingSubmissionsForAnAccepted")
            implicitHeight: Math.max(44, Style.space(44))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.cancelOperation()
        }
        SettingsButton {
            bordered: false
            focusable: true
            visible: root.activity.length > 5
            text: root.showAllActivity ? Locale.Strings.format("files.showRecent", [Commons.I18n.formatNumber(5)]) : Locale.Strings.format("files.showAll", [Commons.I18n.formatNumber(root.activity.length)])
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.showAllActivity = !root.showAllActivity
        }
        SettingsButton {
            bordered: false
            focusable: true
            text: Locale.Strings.t("send.clearHistory")
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.clearOperations()
        }
    }
    Text {
        width: parent.width
        visible: root.activity.length > 0
        text: Locale.Strings.t("send.cancelStopsPendingSubmissionsForAn")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
}
