import QtQuick
import Quickshell
import "plugin" as Plugin

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL launch: " + message); Qt.quit(); return false }
        return true
    }
    Plugin.Service { id: service }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 200) { test.check(false, "bounded launch scenario finishes"); return }
            if (test.phase === 0 && service.appearance.ready && service.devices.length === 2) {
                service.selectDevice("A")
                if (!test.check(service.openKdeConnectApp(), "native launch accepts its first request")) return
                if (!test.check(!service.openKdeConnectApp(), "repeat launch is rejected while starting")) return
                test.phase = 10
            } else if (test.phase === 10) {
                if (!test.check(service.nativeAppOpening && service.nativeAppMessage === "Opening KDE Connect", "launch exposes its own running state: " + service.nativeAppOpening + " / " + service.nativeAppMessage)) return
                if (!test.check(!service.openKdeConnectApp(), "repeat launch is rejected while running")) return
                service.selectDevice("B")
                test.phase = 1
            } else if (test.phase === 1 && !service.nativeAppOpening) {
                if (!test.check(service.nativeAppMessage === "" && !service.nativeAppFailed, "late result for A does not label selected B")) return
                service.openKdeConnectApp()
                test.phase = 2
            } else if (test.phase === 2 && !service.nativeAppOpening) {
                if (!test.check(service.nativeAppFailed && service.nativeAppMessage === "KDE Connect app unavailable", "native frontend failure has a bounded retry message")) return
                service.selectDevice("A")
                if (!test.check(service.nativeAppMessage === "" && !service.nativeAppFailed, "device selection clears old launch feedback")) return
                service.openKdeConnectApp()
                test.phase = 3
            } else if (test.phase === 3 && !service.nativeAppOpening) {
                if (!test.check(!service.nativeAppFailed && service.nativeAppMessage === "KDE Connect launch requested", "zero exit reports request acceptance")) return
                service.actionError = "Unrelated action failed"
                if (!test.check(service.nativeAppMessage === "KDE Connect launch requested", "other actions do not overwrite native launch feedback")) return
                if (!test.check(!service.openKdeConnectApp("../bad") && !service.openKdeConnectApp(42), "invalid native module input is rejected")) return
                service.openKdeConnectApp("kdeconnect_runcommand")
                test.phase = 4
            } else if (test.phase === 4 && !service.nativeAppOpening) {
                if (!test.check(service.nativeAppMessage === "Native configuration launch requested", "module handoff reports request acceptance")) return
                service.openKdeConnectApp("kdeconnect_clipboard")
                test.phase = 5
            } else if (test.phase === 5 && !service.nativeAppOpening) {
                if (!test.check(service.nativeAppFailed && service.nativeAppMessage.indexOf("Direct configuration unavailable") === 0, "unsupported direct configuration gives a native fallback step")) return
                if (!test.check(service.editRemoteCommands("A"), "native editor request accepts the paired capable peer")) return
                test.phase = 6
            } else if (test.phase === 6 && service.actionState !== "running") {
                if (!test.check(service.actionState === "accepted" && service.actionMessage.indexOf("Command editor request accepted") === 0, "editor acceptance does not claim execution or opened remote UI")) return
                console.log("NATIVE_PASS native launch")
                Qt.quit()
            }
        }
    }
}
