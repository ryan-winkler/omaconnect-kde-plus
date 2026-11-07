pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "../TransferModel.js" as TransferModel
import "../i18n" as Locale

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
    signal operationFinished(var operation)
    property var submissionQueue: []
    property int submissionIndex: 0
    property int operationSequence: 0
    property int selectionGeneration: 0
    property bool cancellationRequested: false
    property bool chooserSubmits: false
    property bool selectionCancelling: false
    property bool chooserUsesNativeMenu: false
    property var previewFiles: []
    readonly property var previewCandidates: previewFiles.map(function(file) { return file.path })
    readonly property bool previewSubmits: chooserSubmits

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

    function chooseFiles(id, options) {
        var device = controller.deviceById(id)
        if (operationBusy || fileTransferProcess.running || filePickerProcess.running || fileInspectProcess.running) return false
        if (selectionState === "draft" || selectionState === "preview" || selection.length) {
            selectionError = Locale.Strings.t("files.reviewOrClearTheCurrentFile")
            return false
        }
        if (!device || !controller.canAct(id) || !device.capabilities || !device.capabilities.file) {
            selectionError = Locale.Strings.t("files.selectAPairedReachableDeviceThat")
            return false
        }
        // The recipient belongs to this draft. Later navigation cannot change it.
        draftTarget = Object.freeze({peerId: String(device.id), peerName: String(device.name || device.id), provider: "kdeconnect"})
        // Calls without typed options keep the previous portal/review contract.
        var typed = options && typeof options.useDesktopFileChooser === "boolean"
            && typeof options.reviewFilesBeforeSend === "boolean"
        var screenshotOnly = !!options && options.screenshotOnly === true
        chooserSubmits = !screenshotOnly && !!typed && !options.reviewFilesBeforeSend
        return launchChooser(!screenshotOnly && !!typed && !options.useDesktopFileChooser, screenshotOnly)
    }

    function launchChooser(nativeMenu, screenshotOnly) {
        if (!draftTarget || operationBusy || fileTransferProcess.running || filePickerProcess.running || fileInspectProcess.running) return false
        selectionGeneration += 1
        chooserUsesNativeMenu = nativeMenu === true
        selection = []
        selectionBytes = 0
        previewFiles = []
        selectionState = "choosing"
        selectionError = ""
        if (screenshotOnly) {
            filePickerProcess.command = ["python3", controller.scriptPath("scripts/portal_files.py"),
                                         "choose-screenshot", Locale.Strings.t("files.screenshotPickerTitle")]
        } else {
            filePickerProcess.command = chooserUsesNativeMenu
                ? ["python3", controller.scriptPath("scripts/portal_files.py"), "recent"]
                : ["bash", controller.getPickerScriptPath(), Locale.Strings.t("files.pickerTitle")]
        }
        var recipient = draftTarget.peerName.slice(0, 80)
        filePickerProcess.payload = chooserUsesNativeMenu ? JSON.stringify({
            recipient: recipient,
            title: recipient ? Locale.Strings.format("files.pickerFor", [recipient]).slice(0, 160)
                             : Locale.Strings.t("files.pickerSingle").slice(0, 160),
            previewLabel: Locale.Strings.t("files.pickerPreviews").slice(0, 80)
        }) + "\n" : ""
        filePickerProcess.targetGeneration = selectionGeneration
        filePickerProcess.running = true
        return true
    }

    function validPreviewFiles(files) {
        if (!Array.isArray(files) || !files.length || files.length > 200) return false
        var seen = ({})
        for (var file of files) {
            if (!file || !Number.isSafeInteger(file.size) || file.size < 0 || file.size > Math.pow(2, 40)
                    || !["device", "inode", "mtimeNs", "ctimeNs"].every(function(key) {
                        return typeof file[key] === "string" && /^-?\d{1,20}$/.test(file[key])
                    })) return false
            var path = file.path
            if (typeof path !== "string" || path.charAt(0) !== "/" || path.indexOf("//") !== -1
                    || /\/(?:\.{1,2})(?:\/|$)/.test(path) || !/\.(?:jpe?g|png|webp|gif)$/i.test(path)
                    || /[\u0000-\u001f\u007f-\u009f\u00ad\u0600-\u0605\u061c\u06dd\u070f\u0890-\u0891\u08e2\u180e\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff\ufff9-\ufffb]/.test(path)
                    || Object.prototype.hasOwnProperty.call(seen, path)) return false
            try { if (encodeURIComponent(path).replace(/%[0-9A-F]{2}/g, "x").length > 4096) return false }
            catch (error) { return false }
            seen[path] = true
        }
        // Match the helper's conservative ASCII-escaped JSON byte budget.
        return JSON.stringify(files).replace(/[\u007f-\uffff]/g, function(c) {
            return "\\u" + ("000" + c.charCodeAt(0).toString(16)).slice(-4)
        }).length <= 48 * 1024
    }

    function backToFiles() {
        if (selectionState !== "preview") return false
        return launchChooser(true)
    }

    function confirmPreview(path) {
        if (selectionState !== "preview" || !draftTarget
                || operationBusy || filePickerProcess.running || fileInspectProcess.running) return false
        var file = previewFiles.find(function(candidate) { return candidate.path === path })
        if (!file) return false
        var device = controller.deviceById(draftTarget.peerId)
        if (!device || !controller.canAct(draftTarget.peerId) || !device.capabilities || !device.capabilities.file) {
            selectionError = Locale.Strings.t("files.theOriginalRecipientIsNoLonger")
            return false
        }
        selectionGeneration += 1
        previewFiles = []
        selectionState = "choosing"
        selectionError = ""
        fileInspectProcess.payload = JSON.stringify({preview: file}) + "\n"
        fileInspectProcess.targetGeneration = selectionGeneration
        fileInspectProcess.running = true
        return true
    }

    function applySelection(output, code, targetGeneration) {
        if (targetGeneration !== selectionGeneration) return
        selectionState = "idle"
        var result
        try { result = JSON.parse(output) } catch (error) { result = null }
        if (code === 0 && result && result.state === "preview") {
            if (!chooserUsesNativeMenu || !draftTarget || !validPreviewFiles(result.files)) {
                selectionError = Locale.Strings.t("files.theImageListCouldNotBe")
                return
            }
            previewFiles = result.files
            chooserUsesNativeMenu = false
            selectionState = "preview"
            selectionError = ""
            return
        }
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
                selectionError = Locale.Strings.t("files.theSelectedFilesCouldNotBe")
                return
            }
            total += item.size
        }
        if (total > Math.pow(2, 40)) {
            selectionError = Locale.Strings.t("files.selectUpTo100FilesAnd")
            return
        }
        selection = result.files
        selectionBytes = total
        selectionState = "draft"
        selectionError = ""
        if (chooserSubmits) {
            var generation = selectionGeneration
            chooserSubmits = false
            // Cancel can invalidate this exact selection before submission starts.
            Qt.callLater(function() {
                if (generation === root.selectionGeneration && root.selectionState === "draft") root.submitSelection()
            })
        }
    }

    function selectionErrorText(code) {
        if (code === "selection-limit") return Locale.Strings.t("files.selectUpTo100FilesAnd")
        if (code === "portal-unavailable") return Locale.Strings.t("files.theDesktopFileChooserIsUnavailable")
        if (code === "source-preparation-failed") return Locale.Strings.t("files.couldNotPrepareAPrivateCopy")
        if (code === "source-changed") return Locale.Strings.t("files.aSelectedFileChangedChooseThe")
        if (code === "recent-files-empty") return Locale.Strings.t("files.noSupportedRecentFilesFoundUse")
        if (code === "recent-files-timeout") return Locale.Strings.t("files.theFileMenuTimedOutIf")
        if (code === "recent-files-unavailable") return Locale.Strings.t("files.theOmarchyFilePickerIsUnavailable")
        return Locale.Strings.t("files.selectReadableLocalRegularFilesFolders")
    }

    function cancelDraft() {
        var nativeMenuMayRemain = chooserUsesNativeMenu && filePickerProcess.running
        selectionGeneration += 1
        chooserSubmits = false
        previewFiles = []
        if (filePickerProcess.running) filePickerProcess.signal(15)
        if (fileInspectProcess.running) fileInspectProcess.signal(15)
        selectionCancelling = filePickerProcess.running || fileInspectProcess.running
        if (selectionCancelling) selectionCancellationTimer.restart()
        selection = []
        selectionBytes = 0
        selectionState = "idle"
        selectionError = nativeMenuMayRemain ? Locale.Strings.t("files.selectionCancelledIfTheFileMenu") : ""
        draftTarget = null
        return true
    }

    function finishSelectionCancellation() {
        if (!filePickerProcess.running && !fileInspectProcess.running) {
            selectionCancelling = false
            selectionCancellationTimer.stop()
        }
    }

    function submitSelection() {
        if (operationBusy || fileTransferProcess.running || !draftTarget || selectionState !== "draft" || !selection.length) return false
        var target = Object.assign({}, draftTarget)
        var device = controller.deviceById(target.peerId)
        if (!device || !controller.canAct(target.peerId) || !device.capabilities || !device.capabilities.file) {
            selectionError = Locale.Strings.t("files.theReviewedRecipientIsNoLonger")
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
        fileTransferMessage = TransferModel.status(activeOperation, Locale.Strings)
        fileTransferError = ""
        // Let an explicit cancel happen while still queued, before any CLI call.
        Qt.callLater(function() { root.submitNextFile(id) })
        return true
    }

    function updateOperation(operation) {
        activeOperation = operation
        operations = TransferModel.remember(operations, operation)
        fileTransferState = operation.state
        fileTransferMessage = TransferModel.status(operation, Locale.Strings)
        fileTransferError = ""
    }

    function finishOperation() {
        if (!operationBusy || !activeOperation) return
        var done = Object.assign({}, activeOperation)
        done.cancellable = false
        done.observedAt = Date.now()
        updateOperation(done)
        operationBusy = false
        fileBusy = false
        submissionQueue = []
        operationFinished(Object.assign({}, done))
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
        if (!operationBusy || cancellationRequested) return false
        cancellationRequested = true
        if (fileTransferProcess.running) {
            fileTransferProcess.signal(15)
            cancellationTimer.operationId = activeOperation.id
            cancellationTimer.restart()
            fileTransferMessage = Locale.Strings.t("files.stoppingSubmissionAnyRequestAlreadySubmitted")
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
            selectionError = Locale.Strings.t("files.waitForTheCurrentFileAction")
            return false
        }
        if (selectionState === "draft" || selectionState === "preview" || selection.length) {
            selectionError = Locale.Strings.t("files.reviewOrClearTheCurrentFile2")
            return false
        }
        var device = controller.deviceById(id)
        if (!device || !controller.canAct(id) || !device.capabilities || !device.capabilities.file) {
            selectionError = Locale.Strings.t("files.selectAPairedReachableDeviceThat")
            return false
        }
        if (!Array.isArray(urls) || urls.length < 1 || urls.length > 100) {
            selectionError = Locale.Strings.t("files.dropUpTo100LocalFiles")
            return false
        }
        var values = []
        var units = 0
        for (var i = 0; i < urls.length; i++) {
            var value = urls[i]
            if (typeof value !== "string" || value.length > 16384
                    || !/^file:\/\/(?:localhost)?\//.test(value)
                    || /[\u0000-\u001f\u007f]/.test(value)) {
                selectionError = Locale.Strings.t("files.dropReadableLocalFilesFoldersAnd")
                return false
            }
            units += value.length
            // Bound UTF-8 stdin below the helper's 512 KiB input limit.
            if (units > 128 * 1024) {
                selectionError = Locale.Strings.t("files.theDroppedFileListIsToo")
                return false
            }
            values.push(value)
        }
        selectionGeneration += 1
        chooserSubmits = false
        chooserUsesNativeMenu = false
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
        id: selectionCancellationTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (filePickerProcess.running) filePickerProcess.signal(9)
            if (fileInspectProcess.running) fileInspectProcess.signal(9)
            root.finishSelectionCancellation()
        }
    }

    Timer {
        id: cancellationTimer
        property string operationId: ""
        interval: 2000
        repeat: false
        onTriggered: if (root.operationBusy && root.activeOperation
            && root.activeOperation.id === operationId && fileTransferProcess.running) fileTransferProcess.signal(9)
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
        onExited: function(code) { cancellationTimer.stop(); root.submissionExited(targetOperationId) }
    }

    Process {
        id: filePickerProcess
        property int targetGeneration: 0
        property string payload: ""
        command: ["bash", controller.getPickerScriptPath()]
        stdinEnabled: true
        onStarted: { write(payload); payload = ""; stdinEnabled = false }
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) { stdinEnabled = true; root.finishSelectionCancellation(); root.applySelection(stdout.text, code, targetGeneration) }
    }

    Process {
        id: fileInspectProcess
        property int targetGeneration: 0
        property string payload: ""
        command: ["python3", controller.scriptPath("scripts/portal_files.py"), "inspect"]
        stdinEnabled: true
        onStarted: { write(payload); payload = "" }
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) { root.finishSelectionCancellation(); root.applySelection(stdout.text, code, targetGeneration) }
    }

    // One best-effort pass per plugin start removes share copies older than 24 hours.
    Process {
        id: snapshotSweepProcess
        command: ["python3", controller.scriptPath("scripts/portal_files.py"), "sweep"]
    }

    Component.onCompleted: snapshotSweepProcess.running = true

    Component.onDestruction: {
        selectionCancellationTimer.stop()
        cancellationTimer.stop()
        fileTransferDismissTimer.stop()
        fileTransferProcess.running = false
        filePickerProcess.running = false
        fileInspectProcess.running = false
    }
}
