import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "plugin" as Plugin

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool pickerReady: false
    property double cancelledAt: 0
    property var checks: []
    function check(value, label) {
        if(!value){console.error("NATIVE_FAIL picker cancel: "+label);Qt.quit();return false}
        checks=checks.concat([label]);return true
    }
    function find(object,name,seen) {
        if(!object || seen.indexOf(object)!==-1)return null
        seen.push(object)
        if(object.objectName===name)return object
        for(var key of ["children","data"]){
            var values=object[key]
            if(!values || typeof values.length!=="number")continue
            for(var child of values){var found=find(child,name,seen);if(found)return found}
        }
        for(var single of ["contentItem","item","footer"]){
            var nested=object[single]
            if(nested){var loaded=find(nested,name,seen);if(loaded)return loaded}
        }
        return null
    }
    Plugin.Service {id:service}
    QtObject {id:facade;function serviceFor(id){return service}}
    QtObject {
        id:bar
        property var shell:facade
        property var activePopout:null
        property bool vertical:false
        property bool foregroundAnimationEnabled:false
        property int barSize:26
        property string position:"top"
        property string fontFamily:"sans-serif"
        property color barForeground:"#ffffff"
        property color foreground:"#ffffff"
        property color urgent:"#ff5555"
        property int width:1000
        property int height:26
        function requestPopout(owner){activePopout=owner}
        function releasePopout(owner){if(activePopout===owner)activePopout=null}
        function hideTooltip(owner){}
        function showTooltip(owner,text,options){}
        function registerClickTarget(owner){}
        function unregisterClickTarget(owner){}
        function switchPanelFrom(owner,direction){return false}
    }
    Window {
        visible:true;width:520;height:800
        Item{id:anchor;width:26;height:26}
        Plugin.Panel{id:panel;bar:bar;anchorItem:anchor;settings:({showTailscale:false})}
    }
    Process {
        id:readiness
        command:["python3","-c","from pathlib import Path; import sys; sys.exit(not (Path.home()/'picker-ready').exists())"]
        onExited:function(code){if(code===0)test.pickerReady=true}
    }
    Timer {
        interval:25;running:true;repeat:true
        onTriggered:{
            if(++test.ticks>250){test.check(false,"bounded phase "+test.phase);return}
            var cancel=test.find(panel,"cancel-pending-files",[])
            if(test.phase===0 && service.devices.length===2 && service.appearance.ready){
                panel.open();service.selectDevice("A")
                if(!test.check(service.chooseFiles("A"),"compatibility chooser starts owned stubborn picker"))return
                test.phase=1
            }else if(test.phase===1){
                if(!test.pickerReady){if(!readiness.running)readiness.running=true;return}
                if(!test.check(service.selectionState==="choosing" && cancel && cancel.visible && cancel.enabled && cancel.Accessible.role===Accessible.Button,"ready picker exposes named accessible Cancel"))return
                cancel.Accessible.pressAction();test.cancelledAt=Date.now()
                if(!test.check(service.selectionCancelling && cancel.visible && !cancel.enabled && cancel.text.indexOf("Cancelling")===0,"Cancel remains visible and disabled until stubborn picker exits"))return
                if(!test.check(!service.chooseFiles("A"),"pending cancellation blocks a second picker"))return
                test.phase=2
            }else if(test.phase===2 && !service.selectionCancelling){
                var elapsed=Date.now()-test.cancelledAt
                if(!test.check(elapsed>=1500 && elapsed<3500 && !service.operationBusy && service.operations.length===0,"two-second escalation kills ignored SIGTERM without submission"))return
                if(!test.check(service.chooseFiles("A"),"a fresh chooser starts after forced exit"))return
                test.phase=3
            }else if(test.phase===3 && service.selectionState==="draft"){
                if(!test.check(service.selection.length===1 && service.draftTarget.peerId==="A" && !service.operationBusy && service.operations.length===0,"next chooser returns inspected review with zero native submissions"))return
                service.cancelDraft()
                console.log("PICKER_CANCEL_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS picker cancel");Qt.quit()
            }
        }
    }
}
