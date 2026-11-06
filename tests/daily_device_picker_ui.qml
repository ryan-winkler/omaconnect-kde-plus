import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Plugin

ShellRoot {
    id:test
    property int phase:0
    property int ticks:0
    property bool dispatching:false
    property var checks:[]
    property var picker:null
    property var section:null
    property var initialDevices:[]
    property string draftBefore:""
    property int detailsToggleCount:0
    property string selectionBeforeEmpty:""
    property int failedGeneration:0
    property int interruptedGeneration:0
    property bool interruptedFinished:false
    FileView {
        id: launcherState
        path: Quickshell.env("HOME") + "/pairing-launch-state"
        watchChanges: true
        onFileChanged: reload()
    }
    Connections {
        target:service
        function onComposerRequestFinished(generation,accepted) {
            if(generation===test.interruptedGeneration) test.interruptedFinished=!accepted
        }
    }
    Connections { target:test.section; function onDetailsToggleRequested(){test.detailsToggleCount++} }
    function check(ok,message){
        if(!ok){console.error("NATIVE_FAIL device picker: "+message+" phase="+phase);Qt.quit();return false}
        checks=checks.concat([message]);return true
    }
    function find(item,name,seen,matchText){
        if(!item || seen.indexOf(item)>=0)return null
        seen.push(item)
        if((matchText ? item.text : item.objectName)===name)return item
        var lists=[item.children || [],item.data || []]
        for(var n=0;n<lists.length;n++)for(var i=0;i<lists[n].length;i++){
            var hit=find(lists[n][i],name,seen,matchText);if(hit)return hit
        }
        if(item.contentItem){var content=find(item.contentItem,name,seen,matchText);if(content)return content}
        return null
    }
    function key(code){return events.keyClick(code,Qt.NoModifier,1)}
    Plugin.Service{id:service}
    QtObject{id:facade;function serviceFor(id){return service}}
    QtObject{id:bar;property var shell:facade;property color foreground:"white";property color barForeground:"white";property string fontFamily:"sans-serif"}
    Window{
        id:preview;visible:true;width:500;height:900
        Item{id:anchor;width:26;height:26}
        Plugin.Panel{id:panel;bar:bar;anchorItem:anchor;settings:({showSavedAddresses:false,showNetworkControls:false})}
        Item{TestEvent{id:events}}
    }
    Timer{
        interval:30;running:true;repeat:true
        onTriggered:{
            if(test.dispatching)return
            test.dispatching=true
            try{
                if(++test.ticks>360){test.check(false,"bounded scenario finishes");return}
                if(test.phase===0 && service.appearance.ready && service.devices.length===2){
                    panel.open();preview.requestActivate();test.phase=901
                }else if(test.phase===901 && !service.scanning){
                    var known=JSON.parse(JSON.stringify(service.devices))
                    known[0].name="Fixture phone";known[1].name="Fixture phone";known[1].reachable=false
                    var unpaired=JSON.parse(JSON.stringify(known[0]))
                    unpaired.id="C";unpaired.name="<b>Literal unpaired phone with a long name</b>";unpaired.paired=false
                    service.devices=known.concat([unpaired]);test.initialDevices=JSON.parse(JSON.stringify(service.devices))
                    service.selectDevice("A");test.phase=1
                }else if(test.phase===1){
                    test.picker=test.find(panel,"daily-device-selector",[])
                    if(!test.check(test.picker && test.picker.count===3 && test.picker.currentValue==="A" && test.picker.Accessible.name==="Device","daily native picker contains every peer and exposes device semantics"))return
                    test.section=test.picker.parent.parent
                    if(!test.check(test.picker.textAt(0).indexOf("[A]")>=0 && test.picker.textAt(1).indexOf("[B]")>=0 && /offline/i.test(test.picker.textAt(1)) && test.picker.textAt(2).indexOf("Not paired")>=0,"duplicate names keep stable IDs and offline/unpaired peers remain available"))return
                    if(!test.check(service.stageDroppedFiles("A",[String(Qt.resolvedUrl("one"))]),"private file review starts without sending"))return
                    test.phase=2
                }else if(test.phase===2 && service.selectionState==="draft"){
                    test.draftBefore=JSON.stringify(service.draftTarget)+JSON.stringify(service.selection)
                    panel.draftText="Unsent composer text";panel.draftPing="Unsent Ping";panel.activeComposer="text"
                    test.picker.forceActiveFocus();test.key(Qt.Key_Space);test.phase=3
                }else if(test.phase===3){
                    if(!test.check(test.picker.popup.visible,"Space opens the daily native picker"))return
                    service.devices=JSON.parse(JSON.stringify(service.devices));test.phase=4
                }else if(test.phase===4){
                    if(!test.check(test.picker.popup.visible,"identical scan keeps the daily picker open"))return
                    test.key(Qt.Key_Down);test.key(Qt.Key_Return);test.phase=5
                }else if(test.phase===5){
                    if(!test.check(service.selectedDeviceId==="B" && test.picker.currentValue==="B" && !test.picker.popup.visible,"arrows and Enter switch the stable selected ID"))return
                    if(!test.check(panel.activeComposer==="none" && panel.draftText==="" && panel.draftPing==="","incoming peer does not inherit outgoing text or Ping"))return
                    if(!test.check(service.selectionState==="draft" && test.draftBefore===JSON.stringify(service.draftTarget)+JSON.stringify(service.selection) && service.draftTarget.peerId==="A","switching keeps the reviewed file recipient and files locked"))return
                    panel.draftText="Different B draft"
                    test.picker.forceActiveFocus();test.key(Qt.Key_Space);test.phase=6
                }else if(test.phase===6){
                    test.key(Qt.Key_Escape);test.phase=7
                }else if(test.phase===7){
                    if(!test.check(panel.opened && !test.picker.popup.visible && test.picker.activeFocus,"Escape closes only the device picker and returns focus"))return
                    test.picker.Accessible.pressAction();test.phase=71
                }else if(test.phase===71){
                    if(!test.check(test.picker.popup.visible,"accessible press opens the daily device picker"))return
                    var first=test.find(test.picker.popup.contentItem,"device-option-0",[])
                    if(!test.check(first!==null,"native option exposes an accessible target"))return
                    var triggerName=test.find(test.picker.contentItem,"device-label-name",[])
                    var optionName=test.find(first,"device-label-name",[])
                    if(!test.check(triggerName && optionName && Math.abs(
                        triggerName.mapToItem(null,0,0).x-optionName.mapToItem(null,0,0).x)<=1,
                        "popup and trigger name columns align"))return
                    first.Accessible.pressAction();test.phase=72
                }else if(test.phase===72){
                    if(!test.check(service.selectedDeviceId==="A" && !test.picker.popup.visible,"accessible option press selects by stable ID"))return
                    if(!test.check(panel.draftText==="Unsent composer text" && panel.draftPing==="Unsent Ping",
                        "switch-back restores both outgoing drafts"))return
                    service.selectDevice("B")
                    if(!test.check(panel.draftText==="Different B draft" && panel.draftPing==="",
                        "service-driven selection restores only the destination draft"))return
                    panel.selectDevice("A");panel.openComposer("text");test.phase=73
                }else if(test.phase===73){
                    if(!preview.activeFocusItem || preview.activeFocusItem === panel.focusTarget ||
                        preview.activeFocusItem.text !== "Unsent composer text")return
                    if(!test.check(preview.activeFocusItem.activeFocus,"outgoing editor holds real keyboard focus"))return
                    service.selectDevice("B");test.phase=74
                }else if(test.phase===74){
                    if(!test.check(panel.activeComposer==="none" && panel.focusTarget.activeFocus,
                        "service selection returns focus from a closed composer to the panel"))return
                    test.key(Qt.Key_X)
                    if(!test.check(panel.draftText==="Different B draft",
                        "typing after a switch cannot edit the incoming peer's hidden draft"))return
                    test.picker.forceActiveFocus();test.key(Qt.Key_Tab);test.phase=8
                }else if(test.phase===8){
                    if(!test.check(preview.activeFocusItem && preview.activeFocusItem.Accessible.name==="Refresh devices","Tab leaves the native picker for the next visible control"))return
                    test.picker.forceActiveFocus();test.key(Qt.Key_Space)
                    var changed=JSON.parse(JSON.stringify(service.devices));changed[1].name="Changed fixture phone";service.devices=changed;test.phase=9
                }else if(test.phase===9){
                    if(!test.check(!test.picker.popup.visible,"changed labels close stale popup rows"))return
                    service.devices=[service.devices[2],service.devices[0],service.devices[1]];test.phase=10
                }else if(test.phase===10){
                    if(!test.check(test.picker.currentValue==="B" && test.picker.displayText.indexOf("Changed fixture phone")===0,"scan reorder keeps the selected identity and label"))return
                    if(!test.check(service.devices[panel.selectedIndex].id==="B","keyboard cursor follows the displayed ID after reorder"))return
                    test.picker.activated(1)
                    if(!test.check(service.selectedDeviceId==="B","invalidated popup cannot activate a replacement at the old index"))return
                    test.key(Qt.Key_Up)
                    if(!test.check(service.selectedDeviceId==="B" && test.picker.currentValue==="B",
                        "a closed invalidated picker retains the current native ID on arrow input"))return
                    test.key(Qt.Key_Space);test.phase=105
                }else if(test.phase===105){
                    if(!test.check(test.picker.popup.visible && test.picker.highlightedIndex===test.picker.indexOfValue("B"),
                        "reopened picker highlights the selected ID"))return
                    test.key(Qt.Key_Escape)
                    panel.cursorActive=true;panel.focusSection="devices";panel.focusTarget.forceActiveFocus()
                    test.key(Qt.Key_U)
                    if(!test.check(panel.unpairConfirmingId==="B" && !service.unpairPendingId,"Unpair opens only for the selected peer"))return
                    panel.cancelUnpairConfirm("B")
                    test.key(Qt.Key_Return);test.phase=101
                }else if(test.phase===101){
                    if(!test.check(test.picker.popup.visible && !panel.unpairConfirmingId && service.selectedDeviceId==="B","panel Enter opens the picker without pairing actions"))return
                    test.key(Qt.Key_Escape);test.phase=102
                }else if(test.phase===102){
                    if(!test.check(panel.focusTarget.activeFocus,"Escape returns panel-origin picker to the keyboard catcher"))return
                    test.key(Qt.Key_K)
                    if(!test.check(service.selectedDeviceId==="A","global k works immediately after Escape"))return
                    test.key(Qt.Key_Space);test.phase=103
                }else if(test.phase===103){
                    if(!test.check(test.picker.popup.visible,"Space reopens from the returned panel focus"))return
                    test.key(Qt.Key_Down);test.key(Qt.Key_Return);test.phase=104
                }else if(test.phase===104){
                    if(!test.check(service.selectedDeviceId==="B" && panel.focusTarget.activeFocus,
                        "keyboard selection restores the panel keyboard catcher"))return
                    test.key(Qt.Key_U)
                    if(!test.check(panel.unpairConfirmingId==="B","Unpair after picker selection targets the new peer"))return
                    panel.cancelUnpairConfirm("B")
                    test.picker.selectDevice("C");test.phase=11
                }else if(test.phase===11){
                    if(!test.check(service.selectedDeviceId==="C" && test.picker.displayText.indexOf("<b>")===0 && test.find(test.picker.contentItem,"device-label-name",[]).textFormat===Text.PlainText,"unpaired markup-shaped names stay selectable as plain text"))return
                    var disclosure=test.find(test.section,"section-toggle-devices",[])
                    disclosure.Accessible.pressAction()
                    if(!test.check(test.detailsToggleCount===1,"device details exposes the controlled disclosure signal"))return
                    test.section.detailsExpanded=false
                    var updated=JSON.parse(JSON.stringify(service.devices))
                    updated[0].requestKnown=true;updated[0].pairRequestedByPeer=true
                    updated[1].name=updated[0].name
                    updated[1].paired=false
                    updated[1].requestKnown=true;updated[1].pairRequestedByPeer=true
                    updated[1].verificationKey="fixture-check-code"
                    service.devices=[updated[1],updated[0],updated[2]]
                    service.actionError="Fixture action error";test.phase=12
                }else if(test.phase===12){
                    var incomingCard=test.find(test.section,"incoming-pairing-warning",[])
                    if(!test.check(test.picker.visible && !test.find(test.section,"selected-device-details",[]).visible
                        && incomingCard.visible && test.find(test.section,"device-status-banner",[]).visible,
                        "collapsed details retain picker, incoming pairing and errors"))return
                    if(!test.check(panel.incomingRequest.id==="A" && test.section.incomingRequest.id==="C",
                        "the selected request takes precedence over another request with the same name"))return
                    test.find(test.section,"dismiss-device-status",[]).Accessible.pressAction()
                    if(!test.check(service.actionError==="","visible error status can be dismissed through accessible action"))return
                    var handoff=test.find(test.section,"pairing-native-handoff",[])
                    if(!test.check(handoff && handoff.visible && handoff.enabled && handoff.text==="Open KDE Connect",
                        "a collapsed incoming request without a key offers the native app"))return
                    if(!test.check(!test.find(incomingCard,"Accept",[],true) && !test.find(incomingCard,"Reject",[],true),
                        "Plus does not present direct trust decisions"))return
                    handoff.Accessible.pressAction()
                    test.phase=121
                }else if(test.phase===121 && !service.nativeAppOpening && !service.scanning){
                    if(!test.check(service.selectedDeviceId==="C" && !service.selectedDevice.paired,
                        "the list handoff preserves selection and does not imply pairing"))return
                    panel.focusSection="devices";panel.focusTarget.forceActiveFocus()
                    test.key(Qt.Key_C)
                    if(!test.check(test.section.incomingRequest && test.section.incomingRequest.id==="C",
                        "C does not dismiss a KDE-reported incoming request"))return
                    test.key(Qt.Key_P)
                    test.phase=122
                }else if(test.phase===122 && !service.nativeAppOpening && !service.scanning){
                    service.devices=test.initialDevices
                    service.actionError="";panel.selectDevice("B");panel.requestUnpairConfirm("B");test.phase=13
                }else if(test.phase===13){
                    if(!test.check(!test.section.detailsExpanded && test.find(test.section,"device-unpair-confirmation",[]).visible,"unpair confirmation stays visible outside collapsed details"))return
                    panel.cancelUnpairConfirm("B")
                    panel.selectDevice("A");panel.cursorActive=false;panel.focusSection="devices";panel.focusTarget.forceActiveFocus()
                    test.key(Qt.Key_J);test.key(Qt.Key_J)
                    if(!test.check(service.selectedDeviceId==="B" && test.picker.currentValue==="B","global j navigation still selects devices through the shared panel"))return
                    test.key(Qt.Key_K)
                    if(!test.check(service.selectedDeviceId==="A" && test.picker.currentValue==="A","global k navigation keeps the native picker in sync"))return
                    var removed=service.devices.filter(function(entry){return entry.id!=="B"});service.devices=removed;service.selectDevice("A");test.phase=14
                }else if(test.phase===14){
                    test.picker.selectDevice("B")
                    if(!test.check(service.selectedDeviceId==="A","removed stable ID cannot dispatch from stale rows"))return
                    test.selectionBeforeEmpty=service.selectedDeviceId;service.devices=[];test.phase=15
                }else if(test.phase===15){
                    test.picker.Accessible.pressAction()
                    if(!test.check(!test.picker.enabled && !test.picker.popup.visible && service.selectedDeviceId===test.selectionBeforeEmpty && test.picker.displayText==="Choose a device","disabled empty picker cannot activate by accessible press"))return
                    service.cancelDraft()
                    service.devices=test.initialDevices
                    test.phase=16
                }else if(test.phase===16){
                    panel.openComposer("text");panel.draftText="Fixture accepted"
                    if(!test.check(panel.submitText() && panel.draftText==="Fixture accepted","a pending submission keeps the draft until acceptance"))return
                    test.phase=17
                }else if(test.phase===17 && service.actionState==="accepted"){
                    if(!test.check(panel.draftText==="" && panel.draftPing==="Unsent Ping","acceptance clears only the submitted draft"))return
                    panel.openComposer("text");panel.draftText="Fixture failed"
                    if(!test.check(panel.submitText(),"fixture starts a submission that will fail"))return
                    test.failedGeneration=service.actionGeneration
                    test.phase=18
                }else if(test.phase===18 && service.actionState==="failed"){
                    if(!test.check(panel.draftText==="Fixture failed" && !panel.pendingComposer,
                        "failed submission preserves the draft and disarms its completion"))return
                    service.composerRequestFinished(test.failedGeneration+1,true)
                    if(!test.check(panel.draftText==="Fixture failed","another request cannot clear the failed draft"))return
                    panel.openComposer("text");panel.draftText="Fixture unknown"
                    if(!test.check(panel.submitText(),"fixture starts a submission with unknown outcome"))return
                    test.phase=19
                }else if(test.phase===19 && service.actionState==="unknown"){
                    if(!test.check(panel.draftText==="Fixture unknown" && !panel.pendingComposer,
                        "unknown completion preserves the draft and disarms its completion"))return
                    panel.openComposer("text");panel.draftText="Fixture same text"
                    if(!test.check(panel.submitText(),"fixture starts a delayed acceptance"))return
                    service.composerRequestFinished(service.actionGeneration-1,true)
                    if(!test.check(panel.pendingComposer && panel.draftText==="Fixture same text",
                        "an older completion cannot clear a newer pending draft"))return
                    panel.openComposer("text");panel.draftText="Edited";panel.draftText="Fixture same text"
                    test.phase=20
                }else if(test.phase===20 && service.actionState==="accepted"){
                    if(!test.check(panel.draftText==="Fixture same text",
                        "editing back to the submitted text preserves the newer revision"))return
                    panel.openComposer("text");panel.draftText="Fixture pending switch"
                    if(!test.check(panel.submitText(),"fixture starts a delayed submission"))return
                    test.interruptedGeneration=service.actionGeneration;test.phase=21
                }else if(test.phase===21){
                    panel.selectDevice("B");panel.selectDevice("A")
                    test.phase=22
                }else if(test.phase===22 && test.interruptedFinished){
                    if(!test.check(panel.draftText==="Fixture pending switch" && !panel.pendingComposer,
                        "the original recipient draft survives a stale terminal result after switching"))return
                    panel.focusSection="devices";panel.focusTarget.forceActiveFocus()
                    panel.requestUnpairConfirm("A")
                    service.devices=test.initialDevices.filter(function(peer){return peer.id!=="A"})
                    test.key(Qt.Key_P);test.key(Qt.Key_U);test.key(Qt.Key_Y)
                    panel.confirmUnpair("A")
                    if(!test.check(!service.unpairPendingId && !service.nativeAppOpening,
                        "a missing selected row in a healthy scan cannot dispatch a pairing action"))return
                    var unpaired=JSON.parse(JSON.stringify(test.initialDevices))
                    unpaired[0].paired=false
                    service.devices=unpaired
                    test.key(Qt.Key_Y);panel.confirmUnpair("A")
                    if(!test.check(!service.unpairPendingId,
                        "confirmation cannot dispatch when the selected row is no longer paired"))return
                    service.devices=test.initialDevices;service.selectDevice("B")
                    test.key(Qt.Key_Y);panel.confirmUnpair("A")
                    if(!test.check(!panel.unpairConfirmingId && !service.unpairPendingId,
                        "switching peers cancels the old confirmation"))return
                    service.selectedDeviceId=""
                    test.key(Qt.Key_P);test.key(Qt.Key_U);test.key(Qt.Key_Y)
                    if(!test.check(!panel.unpairConfirmingId && !service.nativeAppOpening,
                        "pair and unpair shortcuts have no target without a selection"))return
                    service.selectDevice("B")
                    test.key(Qt.Key_U);test.key(Qt.Key_Y)
                    if(!test.check(service.unpairPendingId==="B" && service.actionMessage!=="Device unpaired",
                        "Y submits only for the reviewed peer and does not report success at launch"))return
                    service.selectDevice("A")
                    test.key(Qt.Key_U);test.key(Qt.Key_Y)
                    if(!test.check(panel.unpairConfirmingId==="A" && service.unpairPendingId==="B",
                        "a busy Unpair retains the other peer confirmation without moving the operation"))return
                    test.key(Qt.Key_C)
                    if(!test.check(!panel.unpairConfirmingId && service.unpairPendingId==="B",
                        "C closes only the confirmation and leaves the in-flight Unpair alone"))return
                    service.selectDevice("B")
                    test.phase=23
                }else if(test.phase===23 && !service.unpairPendingId && !service.scanning){
                    if(!test.check(service.selectedDevice && service.selectedDevice.paired && service.actionState==="failed"
                        && service.actionError==="KDE Connect still reports this device as paired.",
                        "zero command exit with a fresh paired readback leaves trust intact"))return
                    service.selectDevice("A");test.key(Qt.Key_U)
                    var confirmButton=test.find(test.section,"Confirm unpair",[],true)
                    if(!test.check(confirmButton && confirmButton.visible,"confirmation is accessible for the matched row"))return
                    confirmButton.Accessible.pressAction()
                    if(!test.check(service.unpairPendingId==="A" && service.actionMessage!=="Device unpaired",
                        "accessible confirmation submits for its reviewed peer and waits for native readback"))return
                    test.phase=24
                }else if(test.phase===24 && !service.unpairPendingId && !service.scanning){
                    if(!test.check(service.selectedDevice && !service.selectedDevice.paired && service.actionState==="accepted"
                        && service.actionMessage==="Device unpaired",
                        "a fresh native unpaired row confirms removal"))return
                    var partial=test.find(test.section,"partial-roster-warning",[])
                    if(!test.check(service.discoveryState==="partial" && partial && partial.visible && test.picker.count===3,
                        "partial scan keeps readable rows and displays its warning outside collapsed details"))return
                    if(!test.check(test.picker.textAt(test.picker.indexOfValue("B")).indexOf("Status unavailable")>=0,
                        "an unreadable trust flag is distinct from an observed unpaired row"))return
                    panel.selectDevice("C")
                    var share=test.find(panel,"quick-action-file",[])
                    if(!test.check(service.selectedDevice.id==="C" && share && share.visible && share.enabled
                        && panel.sectionAvailability("drop")==="available",
                        "partial discovery keeps daily file actions for the known paired reachable device"))return
                    panel.selectDevice("B")
                    if(!test.check(panel.sectionAvailability("actions")==="unavailable"
                        && panel.sectionAvailability("drop")==="unavailable",
                        "partial discovery keeps device actions blocked when pairing is unknown"))return
                    panel.selectDevice("A")
                    var handoffAfterScan=test.find(test.section,"pairing-native-handoff",[])
                    if(!test.check(handoffAfterScan && handoffAfterScan.visible && handoffAfterScan.enabled && handoffAfterScan.text==="Pair in KDE Connect",
                        "the native recovery remains available after partial discovery"))return
                    handoffAfterScan.Accessible.pressAction()
                    test.phase=25
                }else if(test.phase===25 && launcherState.text()==="launching"){
                    if(!test.check(service.nativeAppOpening, "the launcher is still running before reopen"))return
                    panel.draftText="Retained through partial scan"
                    panel.close();panel.open()
                    panel.close();panel.open()
                    if(!test.check(!service.scanning,"reopening does not start a scan before the launcher exits"))return
                    service.refresh(false)
                    test.phase=26
                }else if(test.phase===26 && !service.nativeAppOpening && !service.scanning){
                    if(!test.check(service.discoveryState==="partial" && service.selectedDeviceId==="A"
                        && !service.selectedDevice && panel.draftText==="Retained through partial scan"
                        && panel.sectionAvailability("actions")==="unavailable",
                        "one queued read-only scan preserves the missing selected ID and its draft"))return
                    service.selectDevice("B")
                    if(!test.check(service.selectedDevice.paired && !service.selectedDevice.reachable,
                        "the remaining paired peer is offline"))return
                    panel.requestUnpairConfirm("B");panel.confirmUnpair("B")
                    if(!test.check(service.unpairPendingId==="B","offline Unpair starts for the reviewed peer"))return
                    test.phase=27
                }else if(test.phase===27 && !service.unpairPendingId && !service.scanning){
                    if(!test.check(service.discoveryState==="ready" && service.devices.length===1
                        && service.selectedDeviceId==="B" && !service.selectedDevice
                        && service.actionState==="unknown" && service.actionMessage!=="Device unpaired"
                        && service.actionError.indexOf("could not confirm removal")>=0,
                        "a complete readback missing the reviewed target preserves selection and reports unknown"))return
                    var provider=service.children.find(function(child){return typeof child.applyScan==="function"})
                    var unownedRow=["DEVICE","C","Connected phone","phone","true","true","90","false","kdeconnect_share"].join("\t")
                    provider.applyScan(unownedRow+"\nDEVICE\tunreadable",provider.generation)
                    panel.selectDevice("C")
                    if(!test.check(service.discoveryState==="partial" && !service.discoveryOwner && service.selectedDevice.paired
                        && panel.sectionAvailability("actions")==="unavailable" && panel.sectionAvailability("drop")==="unavailable",
                        "a partial scan without a verified owner cannot enable daily device actions"))return
                    service.devices=[]
                    service.discoveryState="unavailable"
                    test.phase=28
                }else if(test.phase===28){
                    if(!test.check(!test.find(test.section,"pairing-native-handoff",[]).visible,
                        "unavailable discovery does not look like an empty healthy roster"))return
                    service.discoveryState="ready"
                    test.phase=29
                }else if(test.phase===29){
                    var emptyHandoff=test.find(test.section,"pairing-native-handoff",[])
                    if(!test.check(emptyHandoff.visible && emptyHandoff.enabled && emptyHandoff.text==="Open KDE Connect",
                        "healthy empty roster offers a native setup action"))return
                    emptyHandoff.Accessible.pressAction()
                    test.phase=30
                }else if(test.phase===30 && !service.nativeAppOpening){
                    if(!test.check(!service.selectedDevice,
                        "the empty-roster handoff does not select or trust a peer"))return
                    console.log("DAILY_PICKER_PASS count="+test.checks.length);console.log("NATIVE_PASS daily device picker");Qt.quit()
                }
            }finally{test.dispatching=false}
        }
    }
}
