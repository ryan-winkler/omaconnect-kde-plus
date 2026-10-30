import QtQuick
import org.kde.kdeconnect 1.0 as Native

QtObject {
    id: root
    // No device target or view uses this model. Only installed metadata is read.
    readonly property Native.PluginModel metadata: Native.PluginModel {}
    property var modules: []
    readonly property var configurations: modules.filter(function(entry) { return entry.hasConfiguration })
    readonly property bool truncated: configurationEntries.count > 256
    readonly property Instantiator configurationEntries: Instantiator {
        model: root.metadata
        // Do not request isChecked: it requires a device configuration target.
        delegate: QtObject {
            required property string pluginId
            required property string name
            required property string description
            required property url configSource
        }
        onObjectAdded: rebuild.restart()
        onObjectRemoved: rebuild.restart()
    }
    readonly property Timer rebuild: Timer {
        interval: 0
        onTriggered: {
            var entries = []
            for (var i = 0; i < Math.min(256, root.configurationEntries.count); ++i) {
                var entry = root.configurationEntries.objectAt(i)
                if (entry && root.validId(entry.pluginId))
                    entries.push({id: entry.pluginId, name: entry.pluginId === "kdeconnect_runcommand" ? "Commands on this computer" : entry.name.slice(0, 256) || entry.pluginId, description: entry.pluginId === "kdeconnect_runcommand" ? "Choose commands on this computer that the selected device can run." : entry.description.slice(0, 1024),
                        hasConfiguration: entry.configSource.toString().indexOf("file:") === 0})
            }
            entries.sort(function(a, b) { return a.name.localeCompare(b.name) })
            root.modules = entries
        }
    }

    function validId(id) { return typeof id === "string" && /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(id) }

    function displayName(id) {
        if (!validId(id)) return ""
        var name = metadata.pluginDisplayName(id)
        return typeof name === "string" && name.length <= 256 ? name.trim() : ""
    }
}
