import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    Components.NativePluginMetadata { id: metadata }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL metadata: " + message); Qt.quit(); return false }
        return true
    }
    Timer {
        interval: 1
        running: true
        onTriggered: {
            if (!check(metadata.configurations.length > 0, "installed configuration pages are discovered without a device target")) return
            if (!check(metadata.modules.length > metadata.configurations.length, "all installed modules include those without a configuration form")) return
            if (!check(metadata.modules.every(function(entry) { return typeof entry.hasConfiguration === "boolean" && metadata.validId(entry.id) }), "catalogue entries have validated IDs and explicit configuration availability")) return
            var commands = metadata.configurations.find(function(entry) { return entry.id === "kdeconnect_runcommand" })
            if (!check(commands && commands.name.length > 0 && commands.description.length > 0, "local command configuration has native metadata")) return
            if (!check(!metadata.configurations.some(function(entry) { return entry.id === "kdeconnect_remotecommands" }), "remote command execution is not confused with local configuration")) return
            var name = metadata.displayName("kdeconnect_virtualmonitor")
            if (!check(name.length > 0 && name !== "kdeconnect_virtualmonitor", "installed virtual monitor metadata resolves")) return
            if (!check(metadata.displayName("kdeconnect_nonexistent_metadata_fixture") === "", "unknown safe ID has no native label")) return
            for (var id of ["", "../plugin", "bad;command", "a".repeat(129), null, 42]) {
                if (!check(metadata.displayName(id) === "", "invalid ID is rejected")) return
            }
            if (!check(metadata.metadata.deviceId === "", "metadata model has no device target")) return
            console.log("NATIVE_PASS plugin metadata")
            Qt.quit()
        }
    }
}
