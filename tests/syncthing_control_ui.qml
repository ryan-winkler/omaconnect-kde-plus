import QtQuick
import Quickshell
import "plugin" as Plugin
ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var checks: []
    property string a: Array(8).fill("AAAAAAA").join("-")
    property string b: Array(8).fill("BBBBBBB").join("-")
    property string c: Array(8).fill("CCCCCCC").join("-")
    property string d: Array(8).fill("DDDDDDD").join("-")
    property string e: Array(8).fill("EEEEEEE").join("-")
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL syncthing: " + label); Qt.quit(); return false }
        checks = checks.concat([label]); return true
    }
    Plugin.Service { id: service }
    Timer {
        interval: 25; repeat: true; running: true
        onTriggered: {
            if (++test.ticks > 500) { test.check(false,"bounded scenario deadline"); return }
            if (test.phase === 0) {
                if (!test.check(!service.readSyncthingPause("--bad") && !service.syncthingBusy,"invalid ID rejected without work")) return
                if (!test.check(service.readSyncthingPause(test.a) && service.readSyncthingPause(test.b),"latest selection queued during read")) return
                test.phase++
            } else if (test.phase === 1 && !service.syncthingBusy) {
                if (!test.check(service.syncthingDeviceId === test.b && service.syncthingState === "paused","queued selection gets its own state")) return
                service.readSyncthingPause(test.a); test.phase++
            } else if (test.phase === 2 && !service.syncthingBusy) {
                if (!test.check(service.syncthingState === "active" && service.setSyncthingPaused(test.a,true),"confirmed active state allows pause")) return
                if (!test.check(!service.setSyncthingPaused(test.a,false),"second mutation refused while busy")) return
                service.readSyncthingPause(test.b); service.readSyncthingPause(test.c); test.phase++
            } else if (test.phase === 3 && !service.syncthingBusy) {
                if (!test.check(service.syncthingDeviceId === test.c && service.syncthingState === "unknown","set readback completes before latest queued selection")) return
                if (!test.check(!service.setSyncthingPaused(test.c,false),"unknown state cannot authorize mutation")) return
                service.readSyncthingPause(test.d); test.phase++
            } else if (test.phase === 4 && !service.syncthingBusy) {
                if (!test.check(service.syncthingState === "unknown","oversized output is unconfirmed")) return
                service.readSyncthingPause(test.e); test.phase++
            } else if (test.phase === 5 && !service.syncthingBusy) {
                if (!test.check(service.syncthingState === "unknown","timeout is unconfirmed")) return
                service.readSyncthingPause(test.a); test.phase++
            } else if (test.phase === 6 && !service.syncthingBusy) {
                if (!test.check(service.syncthingState === "paused","later read recovers and confirms the earlier change")) return
                console.log("NATIVE_PASS syncthing " + JSON.stringify(test.checks)); Qt.quit(); test.phase++
            }
        }
    }
}
