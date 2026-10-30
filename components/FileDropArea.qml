pragma ComponentBehavior: Bound
import QtQuick

// One review-only transfer boundary for the Send target and the bar icon.
DropArea {
    id: root
    required property var service
    property var device: null
    signal filesStaged()
    signal dragReadyEntered()
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
        : "Drop up to 100 local files, 1 TiB total. No folders. Review before Send."
    function canAccept(event) {
        return ready && event && event.hasUrls && (event.supportedActions & Qt.CopyAction)
            && event.urls && event.urls.length > 0 && event.urls.length <= 100
    }
    function acceptDrag(event) {
        event.accepted = !!canAccept(event)
        if (event.accepted) dragReadyEntered()
        return event.accepted
    }
    function acceptFiles(event) {
        if (!canAccept(event)) {
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
    onEntered: function(event) { root.acceptDrag(event) }
    onDropped: function(event) { root.acceptFiles(event) }
}
