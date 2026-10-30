import QtQuick
import Quickshell.Io
import "SectionOrder.js" as SectionOrder

QtObject {
    id: root
    property string storedOrder: ""
    property var expectedIds: []
    property var entries: []
    property bool ready: false
    property string loadError: ""
    readonly property string error: loadError || (ready && expectedIds.some(function(id) { return !root.entry(id) })
        ? "Some daily sections are unavailable. Reinstall or update Plus." : "") || (ready && SectionOrder.parse(storedOrder, entries) === null
        ? "The saved section order is invalid. The daily panel uses its default order." : "")
    readonly property var order: SectionOrder.normalize(storedOrder, entries)
    readonly property FileView catalogue: FileView {
        preload: true
        path: decodeURIComponent(Qt.resolvedUrl("PanelSections.json").toString().replace(/^file:\/\//, ""))
        watchChanges: false
        onLoaded: {
            var parsed = SectionOrder.parseCatalog(text())
            root.entries = parsed
            root.ready = parsed.length > 0
            root.loadError = root.ready ? "" : "Section settings are unavailable. Optional daily sections are hidden. Reinstall or update Plus."
        }
        onLoadFailed: {
            root.ready = false
            root.loadError = "Section settings could not load. Optional daily sections are hidden. Reinstall or update Plus."
        }
    }

    function entry(id) { return entries.find(function(row) { return row.id === id; }) || null }

    function preferencesFor(page) {
        var result = []
        entries.filter(function(row) { return (row.settingsPage || "Appearance") === page; }).forEach(function(row) {
            if (row.visibilityKey) result.push({key: row.visibilityKey, label: "Show " + row.label, defaultValue: row.defaultVisible, description: row.description})
            result.push({key: row.expandedKey, label: "Start " + row.label + " expanded", defaultValue: row.defaultExpanded,
                description: "Sets the initial state when Devices opens. You can expand or collapse this section without changing its saved visibility."})
        })
        return result
    }
}
