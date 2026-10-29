pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Kit.BorderSurface {
    id: root
    required property var service
    property var device: null
    readonly property bool ready: !!(service && device && device.paired && device.reachable
        && device.capabilities && device.capabilities.file && !service.operationBusy
        && service.selectionState !== "choosing" && service.selectionState !== "draft"
        && (!service.selection || service.selection.length === 0))
    readonly property string instructions: !device ? "Select a device before dropping files."
        : !device.paired || !device.reachable || !device.capabilities || !device.capabilities.file
            ? "Select a paired, reachable device that supports files."
        : service && (service.operationBusy || service.selectionState === "choosing")
            ? "Wait for the current file action before dropping files."
        : service && service.selectionState === "draft" ? "Review or clear the current selection to drop more files."
        : "Drop local files here, or use Choose files. Up to 100 regular files and 1 TiB; folders are not included. Review the recipient and files before Send."
    width: parent ? parent.width : 0
    implicitHeight: copy.implicitHeight + Style.space(24)
    color: dropArea.containsDrag ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
    radius: Style.cornerRadius
    borderSpec: Commons.Border.controlSpec(dropArea.containsDrag ? "focus" : "normal", Commons.Color.popups.text, Commons.Color.accent)
    Accessible.role: Accessible.StaticText
    Accessible.name: "Drop files for review"
    Accessible.description: instructions

    // Used by Qt's native drop event and focused tests. File metadata is inspected
    // by the same helper as the graphical chooser; this view never sends files.
    function acceptFiles(event) {
        if (!ready || !event.hasUrls || !(event.supportedActions & Qt.CopyAction)
                || !event.urls || event.urls.length < 1 || event.urls.length > 100) {
            event.accepted = false
            return false
        }
        var urls = []
        for (var i = 0; i < event.urls.length; i++) urls.push(String(event.urls[i]))
        var accepted = service.stageDroppedFiles(String(device.id), urls)
        event.accepted = accepted
        // Always copy. Accepting a proposed Move could let the file manager delete originals.
        if (accepted) event.accept(Qt.CopyAction)
        return accepted
    }
    Text {
        id: copy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Style.space(12)
        text: dropArea.containsDrag && root.ready ? "Release to review these files. Nothing sends until you select Send." : root.instructions
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    DropArea {
        id: dropArea
        anchors.fill: parent
        onEntered: function(event) {
            event.accepted = root.ready && event.hasUrls && (event.supportedActions & Qt.CopyAction)
                && event.urls.length > 0 && event.urls.length <= 100
        }
        onDropped: function(event) { root.acceptFiles(event) }
    }
}
