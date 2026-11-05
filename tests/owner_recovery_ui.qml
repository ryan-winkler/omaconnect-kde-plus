import QtQuick
import Quickshell
import Quickshell.Io
import "plugin" as Plus

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int actionStarted: 0
    Plus.KdeConnectController { id: provider }
    Process {
        id: changeOwner
        property string operation: ""
        command: ["python3", "-c",
            "import pathlib,sys; (pathlib.Path.home()/'owner-request').write_text(sys.argv[1])", operation]
    }
    function check(condition, message) {
        if (!condition) {
            console.error("NATIVE_FAIL owner recovery: " + message)
            Qt.quit()
        }
        return condition
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            if (!test.check(++test.ticks < 200, "scenario timed out in phase " + test.phase)) return
            if (test.phase === 0 && provider.daemonAvailable && provider.devices.length === 2) {
                provider.selectDevice("B")
                test.phase = 1
            } else if (test.phase === 1 && test.ticks >= 15) {
                if (!test.check(provider.canAct("B") && provider.ringDevice("B"), "one owned fake ring begins before loss")) return
                test.actionStarted = test.ticks
                changeOwner.operation = "release"
                changeOwner.running = true
                test.phase = 2
            } else if (test.phase === 2 && provider.generation >= 3 && !provider.scanning) {
                if (!test.check(!provider.daemonAvailable && provider.discoveryState === "unavailable"
                        && !provider.customAddressesReady && provider.selectedDeviceId === "B", "owner loss clears readiness and preserves the selected identity")) return
                if (!test.check(!provider.canAct("B") && !provider.pairDevice("B"),
                        "stale action and pairing gates close")) return
                if (!test.check(provider.actionState === "unknown", "interrupted action reports uncertainty")) return
                changeOwner.operation = "acquire"
                changeOwner.running = true
                test.phase = 3
            } else if (test.phase === 3 && provider.daemonAvailable && provider.generation >= 5 && !provider.scanning) {
                if (!test.check(provider.selectedDeviceId === "B" && provider.canAct("B")
                        && provider.discoveryState === "ready" && provider.customAddressesReady,
                        "owner return restores a fresh snapshot of the same selected device")) return
                test.phase = 4
            } else if (test.phase === 4 && test.ticks - test.actionStarted >= 75) {
                if (!test.check(provider.actionState === "unknown" && provider.actionMessage === ""
                        && provider.actionError.indexOf("changed") >= 0, "late old-owner success cannot replace uncertainty")) return
                console.log("NATIVE_PASS owner recovery")
                Qt.quit()
            }
        }
    }
}
