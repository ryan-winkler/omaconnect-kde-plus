import QtQuick
import org.kde.kdeconnect 1.0 as Native

QtObject {
    id: root
    // No device target or view uses this model. Only installed metadata is read.
    readonly property Native.PluginModel metadata: Native.PluginModel {}
    property var configurations: []
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
            for (var i = 0; i < root.configurationEntries.count; ++i) {
                var entry = root.configurationEntries.objectAt(i)
                if (entry && root.validId(entry.pluginId) && entry.configSource.toString().indexOf("file:") === 0)
                    entries.push({id: entry.pluginId, name: entry.name.slice(0, 256), description: entry.description.slice(0, 1024)})
            }
            entries.sort(function(a, b) { return a.name.localeCompare(b.name) })
            root.configurations = entries
        }
    }

    function validId(id) { return typeof id === "string" && /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(id) }

    function displayName(id) {
        if (!validId(id)) return ""
        var name = metadata.pluginDisplayName(id)
        return typeof name === "string" && name.length <= 256 ? name.trim() : ""
    }
}
