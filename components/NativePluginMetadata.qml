import QtQuick
import org.kde.kdeconnect 1.0 as Native

QtObject {
    // No device target or view uses this model. Only installed metadata is read.
    readonly property Native.PluginModel metadata: Native.PluginModel {}

    function displayName(id) {
        if (typeof id !== "string" || !/^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(id)) return ""
        var name = metadata.pluginDisplayName(id)
        return typeof name === "string" && name.length <= 256 ? name.trim() : ""
    }
}
