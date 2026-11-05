pragma Singleton
import QtQuick
import qs.Commons as Commons
import "../TransferModel.js" as Transfers

Commons.Translations {
    directory: Qt.resolvedUrl(".")

    // Replace placeholders in the catalog text once. A device name may
    // itself contain %1 or %2 and must be displayed unchanged.
    function format(key, values) {
        return t(key).replace(/%([1-9][0-9]*)/g, function(match, number) {
            var index = Number(number) - 1
            return index < values.length ? String(values[index]) : match
        })
    }

    function fileCount(count) {
        var text = tn("files.count", count)
        return text.indexOf("%1") >= 0 ? text.arg(Commons.I18n.formatNumber(count)) : text
    }

    function byteSize(bytes) {
        return Transfers.formatBytes(bytes, Commons.I18n.formatNumber)
    }
}
