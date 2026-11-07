.pragma library

// Submission evidence only. Paths live in the transient queue, never this model.
function create(id, target, files, now, sequence) {
    return {id: id, provider: "kdeconnect", providerJobId: "", peerId: target.peerId,
        peerName: target.peerName, count: files.length,
        total: files.reduce(function(sum, file) { return sum + file.size }, 0),
        state: "queued", delivery: "unknown", accepted: 0, failed: 0, cancelled: 0,
        unknown: 0, processed: 0, error: "", cancellable: true, observedAt: now, sequence: sequence}
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

function activityPeerName(operation, unnamed) {
    return operation.peerName && operation.peerName !== operation.peerId ? operation.peerName : unnamed
}

function activitySummary(operation, history, strings) {
    var unnamed = strings.t("files.activityUnnamedDevice")
    var name = activityPeerName(operation, unnamed)
    var recipient = "\u2068" + name + "\u2069"
    var peerId = operation.peerId
    var namesakes = history.filter(function(item) {
        return item.peerId && item.peerId !== peerId && activityPeerName(item, unnamed) === name
    })
    if (peerId && namesakes.length) {
        var length = Math.min(peerId.length, 6)
        // Reveal only the part of the ID needed to distinguish these rows.
        while (length < peerId.length && namesakes.some(function(item) { return item.peerId.endsWith(peerId.slice(-length)) }))
            length += 1
        recipient = strings.format("files.activityRecipient", [recipient, "\u2066" + peerId.slice(-length) + "\u2069"])
    }
    var count = strings.fileCount(operation.count)
    var size = strings.byteSize(operation.total)
    if (operation.sequence > 0 && Number.isFinite(operation.observedAt))
        return strings.format("files.activityTimedDetails", [recipient, strings.number(operation.sequence),
            strings.activityTime(operation.observedAt), count, size])
    return strings.format("files.activityDetails", [recipient, count, size])
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
