import QtQuick
import Quickshell
import qs.Commons as Commons

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var first: null
    property var second: null
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL direct IPC: " + label); Qt.quit(); return false }
        return true
    }
    Component {
        id: handlerFactory
        Commons.ShellIpc {
            target: "omaconnect.ipc-fixture"
            property int calls: 0
            function echo(value: string): string { calls++; return value }
            function fail(): void { calls++; throw new Error("owned fixture failure") }
        }
    }
    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            if (++test.ticks > 80) { test.check(false, "lifecycle completes"); return }
            if (test.phase === 0) {
                test.first = handlerFactory.createObject(test)
                test.second = handlerFactory.createObject(test)
                var result = Commons.IpcRegistry.call("omaconnect.ipc-fixture", "echo", ["first"])
                if (!test.check(result.ran && result.output === "first" && test.first.calls === 1 && test.second.calls === 0, "first enabled target runs once")) return
                test.first.enabled = false
                result = Commons.IpcRegistry.call("omaconnect.ipc-fixture", "echo", ["second"])
                if (!test.check(result.ran && result.output === "second" && test.second.calls === 1, "disabled handler is skipped")) return
                result = Commons.IpcRegistry.call("omaconnect.ipc-fixture", "fail", [])
                if (!test.check(result.ran && result.output === "" && test.second.calls === 2, "exception means ran, so no fallback or second execution")) return
                if (!test.check(!Commons.IpcRegistry.call("omaconnect.ipc-fixture", "destroy", []).ran, "QObject destruction is not an IPC route")) return
                test.first.destroy(); test.second.destroy()
                test.phase = 1
            } else if (test.phase === 1) {
                if (!test.check(Commons.IpcRegistry.handlerFor("omaconnect.ipc-fixture") === null, "destroyed handlers unregister")) return
                test.first = handlerFactory.createObject(test)
                var revived = Commons.IpcRegistry.call("omaconnect.ipc-fixture", "echo", ["recreated"])
                if (!test.check(revived.ran && revived.output === "recreated" && test.first.calls === 1, "recreated target has no stale handler")) return
                test.first.destroy()
                console.log("NATIVE_PASS direct IPC lifecycle")
                Qt.quit()
            }
        }
    }
}
