import QtQuick
import Quickshell
import "plugin" as Plugin
import "plugin/controller" as Controllers
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int started: 0
    property var secondWindow: null
    property var serviceNotices: null
    property var previewWindow: null
    property var unownedPreviewWindow: null
    Plugin.Service { id: service }
    Controllers.TaskNotificationController { id: notices }
    Components.SendWindow { id: sendWindow; service: service }
    Component { id: sendWindowFactory; Components.SendWindow {} }
    Component { id: previewWindowFactory; Components.ImagePreviewWindow {} }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL task notices: " + message); Qt.quit(); return false }
        return true
    }
    function op(state) { return {state:state, peerName:"PRIVATE-PHONE", peerId:"PRIVATE-ID", path:"PRIVATE-PATH"} }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (++test.ticks > 600) { test.check(false,"deadline"); return }
            if (test.phase === 0 && service.devices.length === 2 && service.appearance.ready) {
                service.selectDevice("A")
                if (!test.check(!service.taskNotificationDeviceName && service.taskNotificationsEnabled, "privacy defaults")) return
                if (!test.check(service.chooseFiles("A",{useDesktopFileChooser:true,reviewFilesBeforeSend:true}),"chooser")) return
                test.phase = 1
            } else if (test.phase === 1 && service.selectionState === "draft") {
                if (!test.check(service.submitSelection(),"submit")) return
                test.phase = 2
            } else if (test.phase === 2 && !service.operationBusy && service.operations.length) {
                if (!test.check(service.activeOperation.state === "request_accepted" && service.activeOperation.delivery === "unknown", "honest final event")) return
                test.started = test.ticks
                test.phase = 3
            } else if (test.phase === 3 && test.ticks-test.started > 20) {
                test.serviceNotices = service.children.find(function(child) { return "suppressed" in child && "pending" in child })
                if (!test.check(!!test.serviceNotices && !test.serviceNotices.suppressed, "service starts without visible surfaces")) return
                sendWindow.visible = true
                if (!test.check(service.sendWindowOpened,"persistent visibility suppresses service")) return
                test.secondWindow = sendWindowFactory.createObject(test, {service:service, visible:true})
                if (!test.check(service.taskNoticeVisibleSurfaces.length === 2, "two actual visible Send windows register independently")) return
                sendWindow.visible = false
                if (!test.check(service.sendWindowOpened && test.serviceNotices.suppressed && !test.serviceNotices.notify(test.op("request_accepted")),"closing one surface does not lift suppression while another is visible")) return
                test.secondWindow.service = null
                if (!test.check(!service.sendWindowOpened && service.taskNoticeVisibleSurfaces.length === 0, "service replacement removes old visibility owner")) return
                test.secondWindow.service = service
                if (!test.check(service.sendWindowOpened && service.taskNoticeVisibleSurfaces.length === 1, "new service registers the still-visible window")) return
                test.secondWindow.destroy()
                test.started = test.ticks
                test.phase = 31
            } else if (test.phase === 31 && test.ticks-test.started > 1) {
                if (!test.check(!service.sendWindowOpened && service.taskNoticeVisibleSurfaces.length === 0 && !test.serviceNotices.suppressed && test.serviceNotices.pending.length === 0, "destroying the last visible surface cleans up without replay")) return
                service.selectionState = "preview"
                test.previewWindow = previewWindowFactory.createObject(test, {service:service})
                test.unownedPreviewWindow = previewWindowFactory.createObject(test, {service:service, activeForOwner:false})
                if (!test.check(test.previewWindow.visible && !test.unownedPreviewWindow.visible
                    && service.taskNoticeVisibleSurfaces.length === 1 && service.taskNoticeVisibleSurfaces[0].kind === "preview"
                    && test.serviceNotices.suppressed && !test.serviceNotices.notify(test.op("request_accepted")),
                    "only the visible owner preview registers and suppresses notices")) return
                sendWindow.visible = true
                test.previewWindow.activeForOwner = false
                if (!test.check(!test.previewWindow.visible && service.taskNoticeVisibleSurfaces.length === 1
                    && service.sendWindowOpened && test.serviceNotices.suppressed,
                    "revoking preview ownership removes only its surface while Send stays visible")) return
                sendWindow.visible = false
                test.previewWindow.activeForOwner = true
                test.previewWindow.service = null
                if (!test.check(!test.previewWindow.visible && service.taskNoticeVisibleSurfaces.length === 0 && !test.serviceNotices.suppressed,
                    "preview service replacement removes its old visibility registration")) return
                test.previewWindow.service = service
                if (!test.check(test.previewWindow.visible && service.taskNoticeVisibleSurfaces.length === 1 && test.serviceNotices.suppressed,
                    "preview registers again when its active service returns")) return
                test.previewWindow.destroy(); test.unownedPreviewWindow.destroy()
                test.started = test.ticks; test.phase = 32
            } else if (test.phase === 32 && test.ticks-test.started > 1) {
                if (!test.check(service.taskNoticeVisibleSurfaces.length === 0 && !test.serviceNotices.suppressed
                    && test.serviceNotices.pending.length === 0, "destroying the final preview cleans visibility without replay")) return
                service.selectionState = "idle"
                notices.panelOpened = true
                if (!test.check(!notices.notify(test.op("request_accepted")) && notices.pending.length === 0,"open popup suppressed")) return
                notices.panelOpened = false
                notices.notify(test.op("request_accepted"))
                notices.sendWindowOpened = true
                if (!test.check(notices.pending.length === 0 && !notices.notify(test.op("request_accepted")),"open Send discards queued notices")) return
                notices.sendWindowOpened = false
                for (var i=0;i<6;++i) notices.notify(test.op("request_accepted"))
                if (!test.check(notices.pending.length === 3,"pending cap")) return
                notices.includeDeviceName = true
                if (!test.check(notices.pending.length === 0,"privacy change discards queued payloads")) return
                notices.notify({state:"request_accepted", peerName:"RAW-ID", peerId:"RAW-ID"})
                if (!test.check(notices.pending.length === 1 && notices.pending[0].deviceName === "", "missing name never falls back to device ID")) return
                notices.includeDeviceName = false
                for (var j=0;j<6;++j) notices.notify(test.op("request_accepted"))
                test.phase = 4
            } else if (test.phase === 4 && !notices.inFlight && notices.pending.length === 0) {
                notices.notify(test.op("submission_unknown"))
                test.phase = 5
            } else if (test.phase === 5 && notices.message !== "") {
                if (!test.check(service.activeOperation.state === "request_accepted" && !service.operationBusy,"notice failure preserves transfer")) return
                notices.message = ""
                notices.notify(test.op("submission_failed"))
                test.phase = 6
            } else if (test.phase === 6 && notices.message !== "" && !notices.inFlight) {
                notices.message = ""
                notices.notify(test.op("cancelled_before_submit"))
                test.started = test.ticks
                test.phase = 7
            } else if (test.phase === 7 && notices.message !== "" && !notices.inFlight) {
                if (!test.check(test.ticks-test.started > 170 && test.ticks-test.started < 250,"five second process deadline")) return
                notices.enabled = false
                if (!test.check(!notices.notify(test.op("request_accepted")),"disabled notices suppressed")) return
                console.log("NATIVE_PASS task notifications")
                Qt.quit()
            }
        }
    }
}
