import QtQuick
import Quickshell
import Quickshell.Io
import "plugin" as Plus

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int actionStarted: 0
    property int scansBeforeSignal: 0
    property string reviewedOwner: ""
    readonly property bool switchBeforeLoss: false
    readonly property string selectedPeer: switchBeforeLoss ? "A" : "B"
    Plus.KdeConnectController { id: provider }
    FileView {
        id: oldActionState
        path: Quickshell.env("HOME") + "/old-action-state"
        watchChanges: true
        onFileChanged: reload()
    }
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
    function interruptionMatchesSelectedPeer() {
        if (provider.actionMessage !== "" || provider.unpairPendingId) return false
        return switchBeforeLoss
            ? provider.actionState === "idle" && provider.actionError === ""
            : provider.actionState === "unknown" && provider.actionError.indexOf("changed") >= 0
    }
    function finish() {
        console.log("NATIVE_PASS owner recovery " + (switchBeforeLoss ? "switched" : "retained"))
        Qt.quit()
    }
    Timer {
        interval: 30
        running: true
        repeat: true
        onTriggered: {
            if (!test.check(++test.ticks < 200, "scenario timed out in phase " + test.phase)) return
            if (test.phase === 0 && provider.daemonAvailable && provider.devices.length === 2) {
                provider.selectDevice("B")
                test.reviewedOwner = provider.discoveryOwner
                test.phase = 1
            } else if (test.phase === 1 && test.ticks >= 15) {
                if (!test.check(provider.canAct("B") && provider.unpairDevice("B", test.reviewedOwner) && provider.unpairPendingId === "B",
                        "an explicitly scoped fake Unpair begins before owner loss")) return
                test.phase = 11
            } else if (test.phase === 11 && oldActionState.text() === "started") {
                if (test.switchBeforeLoss) provider.selectDevice(test.selectedPeer)
                if (!test.check(provider.unpairPendingId === "B" && provider.selectedDeviceId === test.selectedPeer,
                        "selection changes do not retarget the dispatched Unpair")) return
                test.actionStarted = test.ticks
                changeOwner.operation = "release"
                changeOwner.running = true
                test.phase = 2
            } else if (test.phase === 2 && provider.generation >= 3 && !provider.scanning) {
                if (!test.check(!provider.daemonAvailable && provider.discoveryState === "unavailable"
                        && !provider.customAddressesReady && provider.selectedDeviceId === test.selectedPeer,
                        "owner loss clears readiness and preserves the selected identity")) return
                if (!test.check(!provider.canAct("B") && !provider.unpairPendingId && !provider.unpairDevice("B", test.reviewedOwner),
                        "stale action and Unpair gates close")) return
                if (!test.check(test.interruptionMatchesSelectedPeer(),
                        "interruption feedback is scoped to the selected peer")) return
                changeOwner.operation = "acquire"
                changeOwner.running = true
                test.phase = 3
            } else if (test.phase === 3 && provider.daemonAvailable && provider.generation >= 5 && !provider.scanning) {
                if (!test.check(provider.selectedDeviceId === test.selectedPeer && provider.canAct(test.selectedPeer)
                        && provider.discoveryState === "ready" && provider.customAddressesReady
                        && provider.discoveryOwner !== test.reviewedOwner
                        && !provider.unpairDevice(test.selectedPeer, test.reviewedOwner),
                        "owner return restores a fresh snapshot of the same selected device")) return
                test.phase = 4
            } else if (test.phase === 4 && test.ticks - test.actionStarted >= 75) {
                if (!test.check(test.interruptionMatchesSelectedPeer(),
                        "late old-owner success cannot change feedback or schedule Unpair readback")) return
                if (test.switchBeforeLoss) {
                    var activeOwner = provider.discoveryOwner
                    var row = ["DEVICE", test.selectedPeer, "Fixture phone", "phone", "true", "true",
                        "80", "false", "kdeconnect_share", "", "-1", "false", "false", "", "", "false",
                        JSON.stringify({pairingKnown: true, reachabilityKnown: true, requestKnown: true})]
                    provider.applyScan(row.join("\t"), provider.generation)
                    if (!test.check(provider.discoveryState === "partial" && !provider.discoveryOwner
                            && provider.selectedDevice && !provider.selectedDevice.pairingKnown
                            && !provider.canAct(test.selectedPeer)
                            && !provider.unpairDevice(test.selectedPeer, activeOwner),
                            "modern trust metadata without owner and count markers cannot enable paired actions")) return
                    test.finish()
                    return
                }
                changeOwner.operation = "pair-signal"
                changeOwner.running = true
                test.phase = 5
            } else if (test.phase === 5 && !changeOwner.running) {
                test.scansBeforeSignal = provider.generation
                provider.refresh(false)
                test.phase = 6
            } else if (test.phase === 6 && provider.generation >= test.scansBeforeSignal + 2 && !provider.scanning) {
                if (!test.check(provider.generation === test.scansBeforeSignal + 2,
                        "two pairing signals during a scan coalesce into one later read")) return
                test.finish()
            }
        }
    }
}
