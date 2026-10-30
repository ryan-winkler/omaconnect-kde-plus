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
