pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../TransferModel.js" as Transfers

Column {
    id: root
    required property var service
    spacing: Style.space(8)
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "KDE submission activity"

        color: Commons.Color.popups.text
        font.bold: true
        font.pixelSize: Style.font.body
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width
        text: "KDE Connect owns delivery. An accepted request is not a delivery receipt. Activity holds up to 50 operations in memory and has no saved file paths."

        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.pixelSize: Style.font.caption
    }
    Repeater {
        model: root.service ? root.service.operations : []
        delegate: Text {
            textFormat: Text.PlainText
            required property var modelData
            width: root.width
            text: modelData.peerName + "\nKDE ID: " + modelData.peerId + "\n" + modelData.count + " file(s), " + Transfers.formatBytes(modelData.total) + "\n" + Transfers.status(modelData)

            wrapMode: Text.WrapAnywhere
            color: Commons.Color.popups.text
            font.pixelSize: Style.font.bodySmall
            Accessible.name: text
        }
    }
    Kit.Button {
        width: parent.width
        text: "Clear finished activity"
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service
        Accessible.name: text
        onClicked: root.service.clearOperations()
    }
}
