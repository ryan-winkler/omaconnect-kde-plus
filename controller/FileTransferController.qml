pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../TransferModel.js" as TransferModel

// File selection review and batch submission. The recipient is fixed when a
// draft starts; KdeConnectController forwards the file API here.
Item {
    id: root
    required property var controller

    property string fileTransferState: "idle"
    property string fileTransferMessage: ""
    property string fileTransferError: ""
    property int fileTransferGeneration: 0
    property bool fileBusy: false
    property var selection: []
    property real selectionBytes: 0
    property string selectionState: "idle"
    property string selectionError: ""
    property var draftTarget: null
    property var operations: []
    property var activeOperation: null
    property bool operationBusy: false
    property var submissionQueue: []
    property int submissionIndex: 0
    property int operationSequence: 0
    property int selectionGeneration: 0
    property bool cancellationRequested: false

    onFileTransferMessageChanged: {
        if (root.fileBusy || root.fileTransferState === "transferring") {
            fileTransferDismissTimer.stop()
        } else if (fileTransferMessage !== "" || fileTransferError !== "") {
            fileTransferDismissTimer.restart()
        } else {
            fileTransferDismissTimer.stop()
        }
    }

    onFileTransferErrorChanged: {
        if (root.fileBusy || root.fileTransferState === "transferring") {
            fileTransferDismissTimer.stop()
        } else if (fileTransferMessage !== "" || fileTransferError !== "") {
            fileTransferDismissTimer.restart()
        } else {
            fileTransferDismissTimer.stop()
        }
    }

    function chooseFiles(id) {
        var device = controller.deviceById(id)
        if (operationBusy || fileTransferProcess.running || filePickerProcess.running || fileInspectProcess.running) return false
        if (selectionState === "draft" || selection.length) {
            selectionError = "Review or clear the current file selection before choosing more files."
            return false
        }
        if (!device || !controller.canAct(id) || !device.capabilities || !device.capabilities.file) {
            selectionError = "Select a paired, reachable device that supports files"
            return false
        }
        selectionGeneration += 1
        selection = []
        selectionBytes = 0
        selectionState = "choosing"
        selectionError = ""
        // The recipient belongs to this draft. Later navigation cannot change it.
        draftTarget = Object.freeze({peerId: String(device.id), peerName: String(device.name || device.id), provider: "kdeconnect"})
        filePickerProcess.targetGeneration = selectionGeneration
        filePickerProcess.running = true
        return true
    }

    function applySelection(output, code, targetGeneration) {
        if (targetGeneration !== selectionGeneration) return
        selectionState = "idle"
        var result
        try { result = JSON.parse(output) } catch (error) { result = null }
        if (code === 0 && result && result.state === "cancelled") {
            cancelDraft()
            return
        }
        if (code !== 0 || !result || result.state !== "selected" || !Array.isArray(result.files)
                || !result.files.length || result.files.length > 100) {
            selectionError = selectionErrorText(result ? result.error : "portal-unavailable")
            return
        }
        var total = 0
        for (var i = 0; i < result.files.length; i++) {
            var item = result.files[i]
            if (!item || typeof item.path !== "string" || item.path.charAt(0) !== "/"
                    || typeof item.size !== "number" || item.size < 0 || !isFinite(item.size)) {
                selectionError = "The selected files could not be checked"
                return
            }
            total += item.size
        }
        if (total > Math.pow(2, 40)) {
            selectionError = "Select up to 100 files and 1 TiB in total"
            return
        }
        selection = result.files
        selectionBytes = total
        selectionState = "draft"
        selectionError = ""
    }

    function selectionErrorText(code) {
        if (code === "selection-limit") return "Select up to 100 files and 1 TiB in total"
        if (code === "portal-unavailable") return "The desktop file chooser is unavailable. Check the desktop portal and Python Gio support."
        if (code === "source-preparation-failed") return "Could not prepare a private copy. Check cache access and free space, then choose again."
        if (code === "source-changed") return "A selected file changed. Choose the files again."
        return "Select readable local regular files. Folders and other locations are not supported."
    }

    function cancelDraft() {
        selectionGeneration += 1
        if (filePickerProcess.running) filePickerProcess.signal(15)
        if (fileInspectProcess.running) fileInspectProcess.signal(15)
        selection = []
        selectionBytes = 0
        selectionState = "idle"
        selectionError = ""
        draftTarget = null
        return true
    }

    function submitSelection() {
        if (operationBusy || fileTransferProcess.running || !draftTarget || selectionState !== "draft" || !selection.length) return false
        var target = Object.assign({}, draftTarget)
        var device = controller.deviceById(target.peerId)
        if (!device || !controller.canAct(target.peerId) || !device.capabilities || !device.capabilities.file) {
            selectionError = "The reviewed recipient is no longer paired and reachable"
            return false
        }
        operationSequence += 1
        fileTransferGeneration += 1
        var id = "kde-" + Date.now() + "-" + operationSequence
        submissionQueue = selection.map(function(item) { return Object.assign({}, item) })
        submissionIndex = 0
        cancellationRequested = false
        activeOperation = TransferModel.create(id, target, submissionQueue, Date.now())
        operations = TransferModel.remember(operations, activeOperation)
        operationBusy = true
        fileBusy = true
        cancelDraft()
        fileTransferState = "queued"
        fileTransferMessage = TransferModel.status(activeOperation)
        fileTransferError = ""
        // Let an explicit cancel happen while still queued, before any CLI call.
        Qt.callLater(function() { root.submitNextFile(id) })
        return true
    }

    function updateOperation(operation) {
        activeOperation = operation
        operations = TransferModel.remember(operations, operation)
        fileTransferState = operation.state
        fileTransferMessage = TransferModel.status(operation)
        fileTransferError = ""
    }

    function finishOperation() {
        var done = Object.assign({}, activeOperation)
        done.cancellable = false
        done.observedAt = Date.now()
        updateOperation(done)
        operationBusy = false
        fileBusy = false
        submissionQueue = []
    }

    function cancelRemaining() {
        while (submissionIndex < submissionQueue.length) {
            updateOperation(TransferModel.record(activeOperation, submissionIndex, "cancelled_before_submit", "", Date.now()))
            submissionIndex += 1
        }
        finishOperation()
    }

    function submitNextFile(operationId) {
        if (!operationBusy || !activeOperation || activeOperation.id !== operationId || fileTransferProcess.running) return
        if (cancellationRequested) { cancelRemaining(); return }
        if (submissionIndex >= submissionQueue.length) { finishOperation(); return }
        // Do not redirect a batch when a scan selects a different device.
        var device = controller.deviceById(activeOperation.peerId)
        if (!device || !controller.canAct(activeOperation.peerId) || !device.capabilities || !device.capabilities.file) {
            updateOperation(TransferModel.record(activeOperation, submissionIndex, "submission_failed", "peer-unreachable", Date.now()))
            submissionIndex += 1
            cancelRemaining()
            return
        }
        fileTransferProcess.targetOperationId = activeOperation.id
        fileTransferProcess.resultState = ""
        fileTransferProcess.resultError = ""
        fileTransferProcess.attempted = false
        fileTransferProcess.payload = JSON.stringify({peerId: activeOperation.peerId, file: submissionQueue[submissionIndex]}) + "\n"
        fileTransferProcess.running = true
    }

    function applySubmissionLine(line, operationId) {
        if (!operationBusy || !activeOperation || operationId !== activeOperation.id) return
        var result
        try { result = JSON.parse(line) } catch (error) { return }
        if (result.event === "preparing") {
            var preparing = Object.assign({}, activeOperation)
            preparing.state = "preparing"
            updateOperation(preparing)
        } else if (result.event === "submitting") {
            fileTransferProcess.attempted = true
            var next = Object.assign({}, activeOperation)
            next.state = "submitting"
            updateOperation(next)
        } else if (["request_accepted", "submission_failed", "submission_unknown", "cancelled_before_submit", "cancellation_unconfirmed", "failed"].indexOf(result.state) !== -1) {
            fileTransferProcess.resultState = result.state === "failed" ? "submission_failed" : result.state
            fileTransferProcess.resultError = ["source-path-rejected", "source-changed", "source-preparation-failed", "provider-missing", "submission-failed", "submission-unknown", "cancellation-unconfirmed", "identity-mismatch"].indexOf(result.error) !== -1 ? result.error : ""
        }
    }

    function submissionExited(operationId) {
        if (!operationBusy || !activeOperation || operationId !== activeOperation.id) return
        var state = fileTransferProcess.resultState
        var error = fileTransferProcess.resultError
        if (!state) {
            state = fileTransferProcess.attempted ? "submission_unknown" : "submission_failed"
            error = fileTransferProcess.attempted ? "submission-unknown" : "submission-failed"
        }
        // Absence of a progress line does not prove that KDE was never called.
        var confirmedBeforeSubmit = state === "cancelled_before_submit" && !fileTransferProcess.attempted
        if (cancellationRequested && !confirmedBeforeSubmit) {
            state = "cancellation_unconfirmed"
            error = "cancellation-unconfirmed"
        } else if (cancellationRequested && confirmedBeforeSubmit) {
            state = "cancelled_before_submit"
            error = ""
        }
        updateOperation(TransferModel.record(activeOperation, submissionIndex, state, error, Date.now()))
        submissionIndex += 1
        // An ambiguous outcome stops this batch. Retry always requires review.
        if (cancellationRequested || state === "submission_unknown" || state === "cancellation_unconfirmed") {
            cancelRemaining()
            return
        }
        var id = activeOperation.id
        Qt.callLater(function() { root.submitNextFile(id) })
    }

    function cancelOperation() {
        if (!operationBusy) return false
        cancellationRequested = true
        if (fileTransferProcess.running) {
            fileTransferProcess.signal(15)
            fileTransferMessage = "Stopping submission. Any request already submitted can still be delivered."
        } else cancelRemaining()
        return true
    }

    function cancelFileTransfer() {
        if (operationBusy) return cancelOperation()
        return cancelDraft()
    }

    function clearOperations() {
        operations = operationBusy && activeOperation ? [Object.assign({}, activeOperation)] : []
    }

    function stageDroppedFiles(id, urls) {
        if (operationBusy || fileTransferProcess.running || filePickerProcess.running || fileInspectProcess.running) {
            selectionError = "Wait for the current file action, then drop the files again."
            return false
        }
        if (selectionState === "draft" || selection.length) {
            selectionError = "Review or clear the current file selection before dropping more files."
            return false
        }
        var device = controller.deviceById(id)
        if (!device || !controller.canAct(id) || !device.capabilities || !device.capabilities.file) {
            selectionError = "Select a paired, reachable device that supports files"
            return false
        }
        if (!Array.isArray(urls) || urls.length < 1 || urls.length > 100) {
            selectionError = "Drop up to 100 local files. Folders and links are not supported."
            return false
        }
        var values = []
        var units = 0
        for (var i = 0; i < urls.length; i++) {
            var value = urls[i]
            if (typeof value !== "string" || value.length > 16384
                    || !/^file:\/\/(?:localhost)?\//.test(value)
                    || /[\u0000-\u001f\u007f]/.test(value)) {
                selectionError = "Drop readable local files. Folders and links are not supported."
                return false
            }
            units += value.length
            // Bound UTF-8 stdin below the helper's 512 KiB input limit.
            if (units > 128 * 1024) {
                selectionError = "The dropped file list is too large. Choose fewer files."
                return false
            }
            values.push(value)
        }
        selectionGeneration += 1
        draftTarget = Object.freeze({peerId: String(device.id), peerName: String(device.name || device.id), provider: "kdeconnect"})
        selection = []
        selectionBytes = 0
        selectionState = "choosing"
        selectionError = ""
        fileInspectProcess.payload = JSON.stringify(values) + "\n"
        fileInspectProcess.targetGeneration = selectionGeneration
        fileInspectProcess.running = true
        return true
    }

    function sendFile(id, path) {
        var value = String(path || "")
        if (value.charAt(0) === "/") value = "file://" + encodeURI(value).replace(/#/g, "%23").replace(/\?/g, "%3F")
        return stageDroppedFiles(id, [value])
    }

    Timer {
        id: fileTransferDismissTimer
        interval: 4000
        repeat: false
        onTriggered: {
            if (root.fileBusy) return
            root.fileTransferMessage = ""
            root.fileTransferError = ""
            if (root.fileTransferState === "accepted" || root.fileTransferState === "cancelled" || root.fileTransferState === "failed") {
                root.fileTransferState = "idle"
            }
        }
    }

    Process {
        id: fileTransferProcess
        property string targetOperationId: ""
        property string payload: ""
        property string resultState: ""
        property string resultError: ""
        property bool attempted: false
        command: ["python3", controller.scriptPath("scripts/portal_files.py"), "submit"]
        stdinEnabled: true
        onStarted: { write(payload); payload = "" }
        stdout: SplitParser {
            onRead: function(line) { root.applySubmissionLine(line, fileTransferProcess.targetOperationId) }
        }
        onExited: function(code) { root.submissionExited(targetOperationId) }
    }

    Process {
        id: filePickerProcess
        property int targetGeneration: 0
        command: ["bash", controller.getPickerScriptPath()]
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) { root.applySelection(stdout.text, code, targetGeneration) }
    }

    Process {
        id: fileInspectProcess
        property int targetGeneration: 0
        property string payload: ""
        command: ["python3", controller.scriptPath("scripts/portal_files.py"), "inspect"]
        stdinEnabled: true
        onStarted: { write(payload); payload = "" }
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) { root.applySelection(stdout.text, code, targetGeneration) }
    }

    Component.onDestruction: {
        fileTransferDismissTimer.stop()
        fileTransferProcess.running = false
        filePickerProcess.running = false
        fileInspectProcess.running = false
    }
}
