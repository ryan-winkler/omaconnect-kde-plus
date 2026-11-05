.pragma library

// Submission evidence only. Paths live in the transient queue, never this model.
function create(id, target, files, now) {
    return {id: id, provider: "kdeconnect", providerJobId: "", peerId: target.peerId,
        peerName: target.peerName, count: files.length,
        total: files.reduce(function(sum, file) { return sum + file.size }, 0),
        state: "queued", delivery: "unknown", accepted: 0, failed: 0, cancelled: 0,
        unknown: 0, processed: 0, error: "", cancellable: true, observedAt: now}
}

function record(operation, index, state, error, now) {
    var next = Object.assign({}, operation)
    next.processed = index + 1
    next.observedAt = now
    if (state === "request_accepted") next.accepted += 1
    else if (state === "cancelled_before_submit") next.cancelled += 1
    else if (state === "submission_unknown" || state === "cancellation_unconfirmed") next.unknown += 1
    else next.failed += 1
    if (error) next.error = error
    // Retain ambiguous evidence even when some earlier requests were accepted.
    if (state === "cancellation_unconfirmed" || operation.state === "cancellation_unconfirmed") next.state = "cancellation_unconfirmed"
    else if (next.unknown) next.state = "submission_unknown"
    else if (next.failed) next.state = "submission_failed"
    else if (next.cancelled) next.state = "cancelled_before_submit"
    else next.state = next.processed < next.count ? "queued" : "request_accepted"
    next.cancellable = next.processed < next.count
    return next
}

function remember(history, operation) {
    return [Object.assign({}, operation)].concat(history.filter(function(item) { return item.id !== operation.id })).slice(0, 50)
}

function formatBytes(value, formatNumber) {
    var units = ["B", "KiB", "MiB", "GiB", "TiB"], index = 0
    while (value >= 1024 && index < units.length - 1) { value /= 1024; index++ }
    var text = formatNumber ? formatNumber(value, index ? 2 : 0) : index ? value.toFixed(2) : String(value)
    return text + " " + units[index]
}

function status(operation, strings) {
    if (!operation) return ""
    var evidence = strings.format("files.status.evidence", [strings.number(operation.accepted), strings.number(operation.count)])
    if (operation.state === "submission_failed") {
        var failure = strings.format("files.status.failed", [strings.fileCount(operation.failed)])
        var detail = ""
        if (operation.error === "source-preparation-failed") detail = strings.t("files.couldNotPrepareAPrivateCopy") + " "
        else if (operation.error === "source-changed") detail = strings.t("files.aSelectedFileChangedChooseThe") + " "
        return failure + " " + detail + evidence
    }
    if (operation.state === "cancelled_before_submit")
        return strings.format("files.status.cancelled", [strings.fileCount(operation.cancelled), evidence])
    var labels = {
        preparing: "files.status.preparing",
        submitting: "files.status.submitting",
        queued: "files.status.queued",
        cancellation_unconfirmed: "files.status.unconfirmed",
        submission_unknown: "files.status.unknown"
    }
    return labels[operation.state] ? strings.format(labels[operation.state], [evidence]) : evidence
}
