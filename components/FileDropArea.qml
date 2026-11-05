pragma ComponentBehavior: Bound
import QtQuick
import "../i18n" as Locale

// One review-only transfer boundary for the Send target and the bar icon.
DropArea {
    id: root
    required property var service
    property var device: null
    signal filesStaged()
    signal dragReadyEntered()
    readonly property bool ready: !!(service && device && device.paired && device.reachable
        && device.capabilities && device.capabilities.file && !service.operationBusy && !service.selectionCancelling
        && service.selectionState !== "choosing" && service.selectionState !== "draft" && service.selectionState !== "preview"
        && (!service.selection || service.selection.length === 0))
    readonly property string instructions: !device ? Locale.Strings.t("fileDropArea.selectADeviceBeforeDroppingFiles")
        : !device.paired || !device.reachable || !device.capabilities || !device.capabilities.file
            ? Locale.Strings.t("fileDropArea.selectAPairedReachableDeviceThat")
        : service && (service.operationBusy || service.selectionState === "choosing")
            ? Locale.Strings.t("fileDropArea.waitForTheCurrentFileAction")
        : service && (service.selectionState === "draft" || service.selectionState === "preview") ? Locale.Strings.t("fileDropArea.reviewOrClearTheCurrentSelection")
        : Locale.Strings.t("fileDropArea.dropUpTo100LocalFiles")
    function canAccept(event) {
        if (!(ready && event && event.hasUrls && (event.supportedActions & Qt.CopyAction)
                && event.urls && event.urls.length > 0 && event.urls.length <= 100)) return false
        var units = 0
        for (var i = 0; i < event.urls.length; i++) {
            var value = String(event.urls[i])
            if (value.length > 16384 || !/^file:\/\/(?:localhost)?\//.test(value)
                    || /[\u0000-\u001f\u007f]/.test(value)) return false
            units += value.length
            if (units > 128 * 1024) return false
        }
        return true
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
