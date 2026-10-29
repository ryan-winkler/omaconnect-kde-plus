pragma ComponentBehavior: Bound
import QtQuick

// One review-only transfer boundary for the Send target and the bar icon.
DropArea {
    id: root
    required property var service
    property var device: null
    signal filesStaged()
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
        if (accepted) root.filesStaged()
        return accepted
    }
    onEntered: function(event) {
        event.accepted = root.ready && event.hasUrls && (event.supportedActions & Qt.CopyAction)
            && event.urls.length > 0 && event.urls.length <= 100
    }
    onDropped: function(event) { root.acceptFiles(event) }
}
