import QtQuick
import Quickshell
import "plugin" as Plugin

ShellRoot {
    id: test
    property int ticks: 0
    Plugin.Service { id: service }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 200) {
                console.error("NATIVE_FAIL dependency discovery deadline")
                Qt.quit()
                return
            }
            if (service.scanning || service.discoveryState !== "unavailable") return
            if (service.daemonAvailable || service.sessionBusAvailable
                || service.discoveryMessage !== "Discovery needs busctl and Python 3. Check the system tools, then select Refresh.") {
                console.error("NATIVE_FAIL dependency discovery classification")
            } else {
                console.log("NATIVE_PASS dependency discovery unavailable, bus unverified, fixed recovery")
            }
            Qt.quit()
        }
    }
}
