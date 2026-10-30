pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../TransferModel.js" as TransferModel

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

    width: parent ? parent.width : 0
    spacing: Style.space(8)
    visible: !!target || (service && service.selectionError !== "") || activity.length > 0

    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "SEND FILES"

        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
    }

    Text {
        textFormat: Text.PlainText
        visible: !!root.target
        width: parent.width
        text: root.target ? "To: \u2068" + root.target.peerName + "\u2069\nKDE Connect · \u2068" + root.target.peerId + "\u2069" : ""

        wrapMode: Text.WrapAnywhere
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        textFormat: Text.PlainText
        visible: !!root.target
        width: parent.width
        text: root.service && root.service.selectionState === "choosing" ? "Choose files in the desktop file chooser."
            : root.files.length + " file(s) · " + TransferModel.formatBytes(root.service ? root.service.selectionBytes : 0) + "\nReview the recipient and files, then select Send."

        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }

    Text {
        textFormat: Text.PlainText
        visible: root.files.length > 0
        width: parent.width
        text: "Files in shared locations can need a private cache copy. Copies become eligible for cleanup after 24 hours. Cleanup is attempted later when the cache is safe and available. See Help → Send files."
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
                    text: "\u2068" + modelData.name + "\u2069 · " + TransferModel.formatBytes(modelData.size)

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
        Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            text: "Send files"
            implicitHeight: Math.max(32, Style.space(32))
            enabled: root.service && root.service.selectionState === "draft" && root.files.length > 0 && !root.service.operationBusy
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.submitSelection()
        }
        Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            text: "Cancel selection"
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.cancelDraft()
        }
    }

    Text {
        textFormat: Text.PlainText
        visible: root.activity.length > 0
        text: "RECENT SUBMISSIONS"

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
                text: "\u2068" + operationRow.modelData.peerName + "\u2069 · KDE Connect · " + operationRow.modelData.count + " file(s) · " + TransferModel.formatBytes(operationRow.modelData.total)

                wrapMode: Text.WrapAnywhere
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
            }
            Text {
                textFormat: Text.PlainText
                width: parent.width
                text: TransferModel.status(operationRow.modelData)

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
        Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            visible: root.service && root.service.operationBusy
            text: "Stop submitting"
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.cancelOperation()
        }
        Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            visible: root.activity.length > 5
            text: root.showAllActivity ? "Show recent 5" : "Show all " + root.activity.length
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.showAllActivity = !root.showAllActivity
        }
        Button {
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            text: "Clear history"
            implicitHeight: Math.max(32, Style.space(32))
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            onClicked: root.service.clearOperations()
        }
    }
}
