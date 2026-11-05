import QtQuick
import Quickshell.Io
import "SectionOrder.js" as SectionOrder
import "i18n" as Locale

QtObject {
    id: root
    property string storedOrder: ""
    property var expectedIds: []
    property var entries: []
    property bool ready: false
    property string loadErrorKey: ""
    readonly property string error: loadErrorKey ? Locale.Strings.t(loadErrorKey) : (ready && expectedIds.some(function(id) { return !root.entry(id) })
        ? Locale.Strings.t("layout.catalogue.missingSections") : "") || (ready && SectionOrder.parse(storedOrder, entries) === null
        ? Locale.Strings.t("layout.catalogue.invalidOrder") : "")
    readonly property var order: SectionOrder.normalize(storedOrder, entries)
    readonly property FileView catalogue: FileView {
        preload: true
        path: decodeURIComponent(Qt.resolvedUrl("PanelSections.json").toString().replace(/^file:\/\//, ""))
        watchChanges: false
        onLoaded: {
            var parsed = SectionOrder.parseCatalog(text())
            root.entries = parsed
            root.ready = parsed.length > 0
            root.loadErrorKey = root.ready ? "" : "layout.catalogue.invalid"
        }
        onLoadFailed: {
            root.ready = false
            root.loadErrorKey = "layout.catalogue.missing"
        }
    }

    function entry(id) { return entries.find(function(row) { return row.id === id; }) || null }
    function title(id) {
        var row = entry(id)
        return row ? Locale.Strings.t("section." + id + ".title", id) : id
    }

    function preferencesFor(page) {
        var result = []
        entries.filter(function(row) { return (row.settingsPage || "Appearance") === page; }).forEach(function(row) {
            result.push({key: row.expandedKey, label: Locale.Strings.t("layout.startSectionExpanded").arg(root.title(row.id)),
                defaultValue: row.defaultExpanded, description: Locale.Strings.t("layout.startExpandedHelp")})
        })
        return result
    }
}
