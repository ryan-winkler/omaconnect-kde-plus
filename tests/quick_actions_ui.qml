import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var checks: []
    function check(value,message) {
        if(!value){console.error("NATIVE_FAIL quick actions: "+message);Qt.quit();return false}
        checks=checks.concat([message]);return true
    }
    function find(object,label) {
        if(!object)return null
        if(typeof object.clicked === "function" && object.Accessible && object.Accessible.name===label)return object
        var children=object.children || []
        for(var i=0;i<children.length;i++){var result=find(children[i],label);if(result)return result}
        return null
    }
    QtObject {
        id: fakePanel
        property var settings: ({})
        property var device: ({id:"fixture",paired:true,reachable:true,capabilities:{file:true,text:true,clipboard:true,ring:true},loadedKnown:true,loadedPluginIds:[]})
        function getSetting(key,fallback){return key in settings ? settings[key] : fallback}
    }
    Item {
        width:480;height:900
        Components.QuickActionsSettings{id:actions;width:parent.width;panel:fakePanel}
    }
    Timer {
        interval:30;running:true;repeat:true
        onTriggered:{
            if(++test.ticks>180){test.check(false,"scenario finishes within deadline");return}
            if(test.phase===0){
                if(!test.check(actions.order.join(",")==="file,text,clipboard","defaults contain common actions and Ring is optional"))return
                actions.selectedAction="ring"
                test.find(actions,"Add selected action").clicked()
                if(!test.check(actions.order.join(",")==="file,text,clipboard","add does not optimistically replace stored order"))return
                test.phase=1
            }else if(test.phase===1 && !actions.busy && actions.message==="Setting saved."){
                fakePanel.settings=({quickActionsOrder:"file,text,clipboard,ring"});test.phase=2
            }else if(test.phase===2){
                if(!test.check(actions.order[3]==="ring" && actions.selectedAction==="","native readback adds Ring once and clears add choice"))return
                var up=test.find(actions,"Move Ring up")
                if(!test.check(up && up.enabled,"labelled native reorder control is available"))return
                up.clicked();test.phase=3
            }else if(test.phase===3 && !actions.busy && actions.message==="Setting saved."){
                fakePanel.settings=({quickActionsOrder:"file,text,ring,clipboard"});test.phase=4
            }else if(test.phase===4){
                if(!test.check(actions.order.join(",")==="file,text,ring,clipboard","readback preserves user-defined action order"))return
                test.find(actions,"Remove Ring quick action").clicked();test.phase=5
            }else if(test.phase===5 && !actions.busy && actions.message==="Setting saved."){
                fakePanel.settings=({quickActionsOrder:"file,text,clipboard"});test.phase=6
            }else if(test.phase===6){
                if(!test.check(actions.order.indexOf("ring")<0,"Ring can be removed without changing native module state"))return
                test.find(actions,"Remove Text quick action").clicked();test.phase=7
            }else if(test.phase===7 && !actions.busy && actions.message.indexOf("not confirmed")>=0){
                if(!test.check(actions.order.join(",")==="file,text,clipboard","a failed save leaves the canonical order intact"))return
                if(!test.check(!actions.moveAction("file",-1) && !actions.addAction("file") && !actions.addAction("untrusted;command"),"invalid moves and duplicate or unknown additions do not save"))return
                console.log("QUICK_ACTIONS_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS quick actions");Qt.quit()
            }
        }
    }
}
