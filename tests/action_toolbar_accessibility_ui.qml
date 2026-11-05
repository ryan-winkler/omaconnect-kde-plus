import QtQuick
import "plugin/i18n" as Locale
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components
import "plugin/ActionCatalog.js" as Actions

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool failed: false
    property bool dispatching: false
    property var checks: []
    property var fileAction: null
    property var ringAction: null

    function check(value, message) {
        if (!value) {
            failed = true
            console.error("NATIVE_FAIL action toolbar: " + message)
            Qt.quit()
            return false
        }
        checks = checks.concat([message])
        return true
    }
    // Only traverse Item.children. Do not request Accessible on non-Item
    // objects from a general QObject/data traversal.
    function findAction(item, id) {
        if ("modelData" in item && item.modelData === id) return item
        for (var i = 0; i < item.children.length; i++) {
            var found = findAction(item.children[i], id)
            if (found) return found
        }
        return null
    }
    function semantics(item, id) {
        if (!check(!!item, id + " delegate exists")) return false
        var entry = Actions.entry(id)
        return check(item.Accessible.role === Accessible.Button, id + " exposes button role")
            && check(item.Accessible.name === Locale.Strings.t(entry.labelKey), id + " exposes the visible action name")
            && check(item.Accessible.description === Locale.Strings.t(entry.descriptionKey), id + " exposes contextual help")
            && check(item.activeFocusOnTab, id + " participates in ordinary Tab focus")
    }
    function key(code) {
        return check(events.keyClick(code, Qt.NoModifier, 1), "actual Qt key event delivered")
    }
    function namedButton(item,label) {
        if (typeof item.clicked === "function" && item.visible && (item.text === label || item.tooltipText === label)) return item
        for (var i=0;i<item.children.length;i++) { var found=namedButton(item.children[i],label);if(found)return found }
        return null
    }
    QtObject {
        id: fakeBar
        property color foreground: "#ffffff"
        property string fontFamily: "sans-serif"
    }
    QtObject {
        id: fakeService
        property bool fileBusy: false
        property string actionState: "idle"
        property var mediaState: ({})
        property var operations: []
        property int clearCalls: 0
        function clearOperations() { clearCalls++;operations=[] }
        property bool commandsLoading: false
        property var remoteCommands: []
        property var commandReads: []
        function fetchRemoteCommands(id) { commandReads=commandReads.concat([id]) }
    }
    QtObject {
        id: fakePanel
        property var bar: fakeBar
        property var service: fakeService
        property var device: ({id:"fixture",type:"phone",paired:true,reachable:true,capabilities:{file:true,ring:true}})
        property var availableActions: ["file", "ring"]
        property bool cursorActive: false
        property string focusSection: ""
        property int actionSelectedIndex: -1
        property string activeComposer: ""
        property string deviceName: "Fixture phone"
        property string draftPing: "Unsent Ping"
        property string draftText: "Unsent text"
        property string composerError: ""
        property int composerCloses: 0
        property var submissions: []
        property bool commandsExpanded: true
        property bool remoteCommandsVisible: true
        property bool mediaPlayerVisible: false
        property int commandSelectedIndex: 0
        function toggleCommandsExpanded() { commandsExpanded=!commandsExpanded }
        function closeComposer() { composerCloses++;activeComposer="none" }
        function submitPing() { submissions=submissions.concat(["ping"]) }
        function submitText() { submissions=submissions.concat(["text"]) }
        property var dispatches: []
        function triggerAction(id) { dispatches = dispatches.concat([id]) }
    }
    QtObject {
        id: fakeTransfer
        property var draftTarget: ({peerId:"fixture",peerName:"Fixture phone"})
        property var selection: [{name:"Owned file.txt",size:89}]
        property int selectionBytes: 89
        property string selectionState: "draft"
        property string selectionError: ""
        property var operations: []
        property bool operationBusy: false
        property bool cancellationRequested: false
        property int submissions: 0
        function submitSelection() { submissions++ }
        function cancelDraft() {}
        function cancelOperation() {}
        function clearOperations() {}
    }
    Window {
        id: preview
        visible: true
        width: 500
        height: 300
        Components.ActionToolbar { id: toolbar; panel: fakePanel; width: parent.width }
        Components.ActivitySection { id: activity; service:fakeService; width:parent.width;visible:test.phase===12 }
        Components.ComposerSection { id:composer;panel:fakePanel;width:parent.width;visible:test.phase===13 }
        Components.RemoteCommandsSection { id:commands;panel:fakePanel;width:parent.width;visible:test.phase===14 }
        Item {
            id: sendHost
            width: parent.width
            visible: test.phase===15
            Components.SendSection { id:sendSection;service:fakeTransfer;width:parent.width }
        }
        Item { TestEvent { id: events } }
    }
    Timer {
        interval: 25
        running: true
        repeat: true
        onTriggered: {
            if (test.failed || test.dispatching) return
            test.dispatching = true
            try {
                if (++test.ticks > 160) { test.check(false, "scenario finishes within deadline"); return }
                if (test.phase === 0) {
                    test.fileAction = test.findAction(toolbar, "file")
                    test.ringAction = test.findAction(toolbar, "ring")
                    if (!test.semantics(test.fileAction, "file") || !test.semantics(test.ringAction, "ring")) return
                    preview.requestActivate()
                    test.fileAction.forceActiveFocus()
                    test.phase = 1
                } else if (test.phase === 1) {
                    if (!test.check(preview.activeFocusItem === test.fileAction, "file action receives native focus")) return
                    test.key(Qt.Key_Return)
                    test.phase = 2
                } else if (test.phase === 2) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file", "Enter dispatches exactly one file action")) return
                    test.key(Qt.Key_Tab)
                    test.phase = 3
                } else if (test.phase === 3) {
                    if (!test.check(preview.activeFocusItem === test.ringAction, "Tab reaches the next daily action")) return
                    test.key(Qt.Key_Space)
                    test.phase = 4
                } else if (test.phase === 4) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring", "Space dispatches exactly one Ring action to the fake panel")) return
                    test.fileAction.Accessible.pressAction()
                    test.phase = 5
                } else if (test.phase === 5) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file", "accessible press uses the same action dispatch")) return
                    fakeService.fileBusy = true
                    fakeService.actionState = "running"
                    test.phase = 6
                } else if (test.phase === 6) {
                    if (!test.check(test.fileAction.enabled && !test.ringAction.enabled, "busy state retains Stop and disables another action")) return
                    if (!test.check(test.fileAction.Accessible.name === "Stop submitting", "busy file action exposes Stop name")) return
                    if (!test.check(test.fileAction.Accessible.description === "Cancel the current file submission", "busy file action exposes cancellation help")) return
                    test.ringAction.Accessible.pressAction()
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file", "accessible press cannot dispatch a disabled action")) return
                    test.fileAction.forceActiveFocus()
                    test.key(Qt.Key_Space)
                    test.phase = 7
                } else if (test.phase === 7) {
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file,file", "Space dispatches Stop once through the same fake boundary")) return
                    fakeService.fileBusy = false
                    fakeService.actionState = "idle"
                    fakePanel.device = null
                    fakePanel.availableActions = ["plus-settings", "native-features"]
                    test.phase = 8
                } else if (test.phase === 8) {
                    var settings = test.findAction(toolbar, "plus-settings")
                    var nativeFeatures = test.findAction(toolbar, "native-features")
                    if (!test.check(toolbar.visible && settings && settings.enabled && nativeFeatures && nativeFeatures.enabled, "global settings and native handoff remain available without a connected device")) return
                    settings.Accessible.pressAction()
                    nativeFeatures.Accessible.pressAction()
                    if (!test.check(fakePanel.dispatches.join(",") === "file,ring,file,file,plus-settings,native-features", "global actions use the same accessible dispatcher")) return
                    fakePanel.device = ({id:"fixture",type:"phone",paired:true,reachable:true,capabilities:{media:true},loadedKnown:true,loadedPluginIds:["kdeconnect_mprisremote"]})
                    fakePanel.availableActions = ["media", "media-next", "native-features"]
                    test.phase = 9
                } else if (test.phase === 9) {
                    var media = test.findAction(toolbar, "media")
                    var next = test.findAction(toolbar, "media-next")
                    if (!test.check(media && media.enabled && next && !next.enabled, "media view remains available while transport waits for a reported player")) return
                    if (!test.check(next.Accessible.description.indexOf("choose a reported player") >= 0, "disabled media transport exposes its readiness reason")) return
                    next.Accessible.pressAction()
                    if (!test.check(fakePanel.dispatches.length === 6, "unready media press does not dispatch")) return
                    fakeService.mediaState = ({player:"Owned player"})
                    test.phase = 10
                } else if (test.phase === 10) {
                    var nextReady = test.findAction(toolbar, "media-next")
                    if (!test.check(nextReady.enabled, "a reported player enables the selected transport shortcut")) return
                    nextReady.Accessible.pressAction()
                    if (!test.check(fakePanel.dispatches[6] === "media-next", "ready transport uses the shared action dispatcher")) return
                    fakeService.actionState = "running"
                    test.phase = 11
                } else if (test.phase === 11) {
                    if (!test.check(!test.findAction(toolbar,"media-next").enabled && test.findAction(toolbar,"media").enabled && test.findAction(toolbar,"native-features").enabled, "busy state blocks transport while navigation and native configuration remain usable")) return
                    test.phase=12
                } else if (test.phase === 12) {
                    var clear=namedButton(activity,"Clear finished activity")
                    if(!check(clear && clear.Accessible.role===Accessible.Button && clear.Accessible.name===clear.text,"Clear activity exposes a named native button"))return
                    fakeService.operations=[{peerName:"Fixture",peerId:"fixture",count:1,total:3,state:"request_accepted",accepted:1,delivery:"unknown"}]
                    clear.Accessible.pressAction()
                    if(!check(fakeService.clearCalls===1 && fakeService.operations.length===0,"accessible Clear activity reaches the existing service action once"))return
                    activity.service=null;clear.Accessible.pressAction()
                    if(!check(!clear.enabled && fakeService.clearCalls===1,"disabled Clear activity cannot dispatch"))return
                    fakePanel.device=({id:"fixture",paired:true,reachable:true,capabilities:{ping:true,text:true}});test.phase=13
                } else if (test.phase === 13) {
                    for(var mode of ["ping","text"]) {
                        fakePanel.activeComposer=mode
                        var send=namedButton(composer,"Send"),cancel=namedButton(composer,"Cancel")
                        if(!check(send && cancel && send.Accessible.role===Accessible.Button && cancel.Accessible.role===Accessible.Button
                            && send.Accessible.name==="Send" && cancel.Accessible.name==="Cancel" && send.activeFocusOnTab && cancel.activeFocusOnTab,mode+" composer actions expose named keyboard-accessible buttons"))return
                        send.enabled=false;cancel.enabled=false;send.Accessible.pressAction();cancel.Accessible.pressAction()
                        if(!check(fakePanel.activeComposer===mode && fakePanel.submissions.length===fakePanel.composerCloses,"disabled composer actions cannot dispatch"))return
                        send.enabled=true;cancel.enabled=true
                        var sentBefore=fakePanel.submissions.length,closedBefore=fakePanel.composerCloses
                        fakePanel.activeComposer="none"
                        send.Accessible.pressAction();cancel.Accessible.pressAction()
                        if(!check(fakePanel.submissions.length===sentBefore && fakePanel.composerCloses===closedBefore,"retained hidden composer actions cannot dispatch"))return
                        fakePanel.activeComposer=mode
                        send.forceActiveFocus();composer.visible=false
                        test.key(Qt.Key_Return);test.key(Qt.Key_Space)
                        if(!check(fakePanel.submissions.length===sentBefore && fakePanel.composerCloses===closedBefore,"hidden focused composer rejects native Return and Space"))return
                        send.Accessible.pressAction();cancel.Accessible.pressAction()
                        if(!check(fakePanel.submissions.length===sentBefore && fakePanel.composerCloses===closedBefore,"hidden ancestor blocks retained composer actions"))return
                        composer.visible=true;preview.visible=false
                        send.Accessible.pressAction();cancel.Accessible.pressAction()
                        if(!check(fakePanel.submissions.length===sentBefore && fakePanel.composerCloses===closedBefore,"hidden containing window blocks retained composer actions"))return
                        preview.visible=true
                        send.Accessible.pressAction();cancel.Accessible.pressAction()
                        if(!check(fakePanel.activeComposer==="none" && fakePanel.submissions[fakePanel.submissions.length-1]===mode,"accessible composer Send and Cancel use their existing routes"))return
                    }
                    if(!check(fakePanel.composerCloses===2 && fakePanel.draftPing==="Unsent Ping" && fakePanel.draftText==="Unsent text","composer cancellation leaves unsent draft values intact"))return
                    test.phase=14
                } else if (test.phase === 14) {
                    var refresh=namedButton(commands,"Refresh commands")
                    if(!check(refresh && refresh.Accessible.role===Accessible.Button && refresh.Accessible.name==="Refresh remote commands" && refresh.activeFocusOnTab,"remote-command Refresh exposes named keyboard-accessible Button metadata"))return
                    fakeService.commandsLoading=true;refresh.Accessible.pressAction()
                    if(!check(!refresh.enabled && fakeService.commandReads.length===0,"disabled remote-command Refresh cannot dispatch"))return
                    fakeService.commandsLoading=false;refresh.Accessible.pressAction()
                    if(!check(fakeService.commandReads.join(",")==="fixture","accessible remote-command Refresh preserves the selected-device route"))return
                    refresh.forceActiveFocus()
                    fakePanel.commandsExpanded=false
                    test.key(Qt.Key_Return)
                    if(!check(fakeService.commandReads.length===1,"Enter on collapsed Refresh cannot fetch commands"))return
                    if(!check(fakePanel.commandsExpanded && preview.activeFocusItem && preview.activeFocusItem.Accessible.name==="Collapse remote commands","collapse returns focus to the header and Enter reopens it"))return
                    fakePanel.commandsExpanded=false;refresh.Accessible.pressAction()
                    if(!check(!refresh.enabled && fakeService.commandReads.length===1,"collapsed Refresh refuses a retained accessible action"))return
                    fakePanel.commandsExpanded=true;commands.visible=false;refresh.Accessible.pressAction()
                    if(!check(!refresh.enabled && fakeService.commandReads.length===1,"hidden commands refuse a retained accessible Refresh action"))return
                    commands.visible=true;preview.visible=false;refresh.Accessible.pressAction()
                    if(!check(!refresh.enabled && fakeService.commandReads.length===1,"hidden containing window refuses a retained accessible Refresh action"))return
                    preview.visible=true;refresh.Accessible.pressAction()
                    if(!check(fakeService.commandReads.length===2,"visible Refresh works again after restoring its window"))return
                    test.phase=15
                } else if (test.phase === 15) {
                    var submit=namedButton(sendSection,"Send files")
                    if(!check(submit && submit.Accessible.role===Accessible.Button && submit.Accessible.name==="Send files","file review Send exposes its named Button action"))return
                    var retainedSelection=JSON.stringify(fakeTransfer.selection),retainedTarget=JSON.stringify(fakeTransfer.draftTarget)
                    submit.Accessible.pressAction()
                    if(!check(fakeTransfer.submissions===1,"visible ready file review Send reaches the fake service once"))return
                    submit.forceActiveFocus();sendHost.visible=false
                    test.key(Qt.Key_Return);test.key(Qt.Key_Space);submit.Accessible.pressAction()
                    if(!check(fakeTransfer.submissions===1,"hidden file review ancestor blocks a retained Send action"))return
                    sendHost.visible=true;preview.visible=false;submit.Accessible.pressAction()
                    if(!check(fakeTransfer.submissions===1,"closed file review window blocks a retained Send action"))return
                    preview.visible=true;fakeTransfer.operationBusy=true;submit.Accessible.pressAction()
                    if(!check(!submit.enabled && fakeTransfer.submissions===1,"disabled file review Send cannot submit"))return
                    if(!check(JSON.stringify(fakeTransfer.selection)===retainedSelection && JSON.stringify(fakeTransfer.draftTarget)===retainedTarget && fakeTransfer.selectionState==="draft","blocked file review actions preserve selected files and recipient"))return
                    fakeTransfer.operationBusy=false;submit.Accessible.pressAction()
                    if(!check(fakeTransfer.submissions===2,"file review Send works again when visible and ready"))return
                    console.log("ACTION_TOOLBAR_ACCESSIBILITY_PASS " + JSON.stringify(test.checks))
                    console.log("NATIVE_PASS action toolbar accessibility")
                    Qt.quit()
                }
            } finally { test.dispatching = false }
        }
    }
}
