import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property var checks: []
    property int reviewedWindows: 0
    function check(value, label) {
        if (!value) { console.error("NATIVE_FAIL drop: " + label); Qt.quit(); return false }
        checks = checks.concat([label]); return true
    }
    function event(urls, actions) {
        return {hasUrls:true,urls:urls,supportedActions:actions,accepted:false,action:Qt.IgnoreAction,
            accept:function(value) { this.action=value;this.accepted=true }}
    }
    QtObject {
        id: service
        property bool operationBusy: false
        property string selectionState: "idle"
        property var selection: []
        property var calls: []
        property bool accept: true
        function stageDroppedFiles(id, urls) { calls=calls.concat([{id:id,urls:urls}]);return accept }
    }
    Item {
        width: 400; height: 700
        Components.FileDropArea {
            id: iconTarget
            width: 32; height: 32
            service: service
            device: ({id:"A",paired:true,reachable:true,capabilities:{file:true}})
            onFilesStaged: test.reviewedWindows++
        }
        Components.FileDropZone { id: zone; width: parent.width; service: service; device: ({id:"A",paired:true,reachable:true,capabilities:{file:true}}) }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            if (!test.check(zone.ready,"ready for local files")) return
            var copy=test.event(["file:///tmp/one","file:///tmp/two"],Qt.CopyAction|Qt.MoveAction)
            if (!test.check(zone.acceptFiles(copy) && copy.accepted && copy.action===Qt.CopyAction,"drop always accepts Copy instead of proposed Move")) return
            if (!test.check(service.calls.length===1 && service.calls[0].id==="A" && service.calls[0].urls.length===2,"drop stages full batch for selected peer")) return
            service.operationBusy=true
            if (!test.check(!zone.acceptFiles(test.event(["file:///tmp/one"],Qt.CopyAction)) && service.calls.length===1,"busy state never stages more files")) return
            service.operationBusy=false;service.selectionState="draft"
            if (!test.check(!zone.ready && !zone.acceptFiles(test.event(["file:///tmp/one"],Qt.CopyAction)),"existing draft is protected")) return
            service.selectionState="idle"
            if (!test.check(!zone.acceptFiles(test.event(["file:///tmp/one"],Qt.MoveAction)) && service.calls.length===1,"move-only sources are refused")) return
            var tooMany=[];for(var i=0;i<101;i++)tooMany.push("file:///tmp/x")
            if (!test.check(!zone.acceptFiles(test.event(tooMany,Qt.CopyAction)) && service.calls.length===1,"oversized drop is refused before staging")) return
            service.accept=false;var rejected=test.event(["file:///tmp/x"],Qt.CopyAction)
            if (!test.check(!zone.acceptFiles(rejected) && !rejected.accepted && rejected.action===Qt.IgnoreAction,"controller refusal leaves drop unaccepted")) return
            service.accept=true
            var iconEvent=test.event(["file:///tmp/icon"],Qt.CopyAction|Qt.MoveAction)
            if (!test.check(iconTarget.acceptFiles(iconEvent) && iconEvent.action===Qt.CopyAction && test.reviewedWindows===1,"bar-sized target uses the same Copy review boundary")) return
            service.selectionState="draft"
            if (!test.check(!iconTarget.acceptFiles(test.event(["file:///tmp/icon"],Qt.CopyAction)) && test.reviewedWindows===1,"icon drop preserves an existing draft")) return
            service.selectionState="idle"
            zone.device=({id:"A",paired:false,reachable:true,capabilities:{file:true}})
            if (!test.check(!zone.ready,"unpaired recipient cannot accept a drop")) return
            console.log("DROP_PASS " + JSON.stringify(test.checks));console.log("NATIVE_PASS drop");Qt.quit()
        }
    }
}
