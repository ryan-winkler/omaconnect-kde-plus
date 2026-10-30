import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    QtObject {
        id: panel
        function getSetting(key, fallback) { return fallback }
    }
    Components.PreferenceControls { id: saver; panel: panel }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 80) { console.error("NATIVE_FAIL section startup deadline"); Qt.quit(); return }
            if (test.phase === 0) {
                saver.save({key: "sectionOrder", value: ""})
                test.phase = 1
            } else if (!saver.busy && saver.message.indexOf("Setting could not start") === 0) {
                console.log("NATIVE_PASS section startup failure releases save guard")
                Qt.quit()
            }
        }
    }
}
