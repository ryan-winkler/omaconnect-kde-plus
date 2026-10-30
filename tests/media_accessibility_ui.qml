import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components
ShellRoot {
 id: test
 property int phase: 0
 property int tabs: 0
 property int ticks: 0
 property bool dispatching: false
 property var second: null
 property var previous: null
 property var play: null
 property var next: null
 property var result: ({tabVisits:[],secondVisited:false,previousVisited:false,playVisited:false,nextVisited:false})
 function findPlayer(item,name) {
  if ("modelData" in item && item.modelData===name) return item
  for(var i=0;i<item.children.length;i++){var hit=findPlayer(item.children[i],name);if(hit)return hit}
  return null
 }
 function glyph(item,value) {
  if ("text" in item && item.text===value && "textFormat" in item) return item.parent
  for(var i=0;i<item.children.length;i++){var hit=glyph(item.children[i],value);if(hit)return hit}
  return null
 }
 function owns(item,focus) { while(focus){if(focus===item)return true;focus=focus.parent}return false }
 function semantics(item) {return {role:item.Accessible.role,name:item.Accessible.name,activeFocusOnTab:item.activeFocusOnTab,enabled:item.enabled,visible:item.visible}}
 function focusName() {
  var focused=preview.activeFocusItem
  if(owns(before,focused))return "before"
  if(owns(after,focused))return "after"
  if(owns(second,focused))return "second-player"
  if(owns(previous,focused)||owns(play,focused)||owns(next,focused))return "transport"
  return focused && focused.Accessible ? focused.Accessible.name : "unknown"
 }
 function fail(message){console.error("NATIVE_FAIL media probe: "+message);Qt.quit()}
 QtObject {id:bar;property color foreground:"white";property string fontFamily:"sans-serif"}
 QtObject {
  id: fakeService
  property var mediaState:({title:"Owned track",artist:"Owned artist",album:"",player:"Owned first",playerList:["Owned first","Owned second"],isPlaying:false})
  property var selections:[]
  property var transports:[]
  function mediaSelectPlayer(id,name){selections=selections.concat([{peer:id,player:name}])}
  function mediaPrevious(id){transports=transports.concat(["previous:"+id])}
  function mediaPlayPause(id){transports=transports.concat(["play:"+id])}
  function mediaNext(id){transports=transports.concat(["next:"+id])}
 }
 QtObject {
  id:panel
  property var bar:bar
  property var service:fakeService
  property var device:({id:"owned-peer",name:"Owned phone",paired:true,reachable:true})
  property bool mediaPlayerVisible:true
  property bool mediaExpanded:true
  property bool cursorActive:false
  property string focusSection:"media"
  property int mediaControlIndex:1
  function toggleMediaExpanded(){mediaExpanded=!mediaExpanded}
 }
 Window {
  id:preview;visible:true;width:640;height:700
  Column {
   width:parent.width
   Item{id:before;objectName:"before-media";width:32;height:32;activeFocusOnTab:true;Accessible.role:Accessible.Button;Accessible.name:"Before media"}
   Components.MediaPlayerSection{id:media;panel:panel;width:parent.width}
   Item{id:after;objectName:"after-media";width:32;height:32;activeFocusOnTab:true;Accessible.role:Accessible.Button;Accessible.name:"After media"}
  }
  Item{TestEvent{id:events}}
 }
 Timer {
  interval:30;running:true;repeat:true
  onTriggered:{
   if(test.dispatching)return
   test.dispatching=true
   try {
    if(++test.ticks>100){test.fail("deadline");return}
    if(test.phase===0){
     test.second=test.findPlayer(media,"Owned second")
     test.previous=test.glyph(media,"󰒮");test.play=test.glyph(media,"󰐊");test.next=test.glyph(media,"󰒭")
     if(!test.second||!test.previous||!test.play||!test.next){test.fail("real player or transport control missing");return}
     test.result.second=test.semantics(test.second)
     test.result.previous=test.semantics(test.previous);test.result.play=test.semantics(test.play);test.result.next=test.semantics(test.next)
     test.result.expectedButtonRole=Accessible.Button
     for (var i=0;i<4;i++) {
      var action=[test.second,test.previous,test.play,test.next][i]
      if(action.Accessible.role!==Accessible.Button || !action.Accessible.name || !action.activeFocusOnTab){test.fail("button semantics missing");return}
     }
     preview.requestActivate();before.forceActiveFocus();test.phase=1
    }else if(test.phase===1){
     var focus=test.focusName()
     test.result.tabVisits.push(focus)
     if(focus==="second-player")test.result.secondVisited=true
     if(test.owns(test.previous,preview.activeFocusItem))test.result.previousVisited=true
     if(test.owns(test.play,preview.activeFocusItem))test.result.playVisited=true
     if(test.owns(test.next,preview.activeFocusItem))test.result.nextVisited=true
     if(++test.tabs<=12){if(!events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)){test.fail("Qt Tab event not delivered");return}}
     else {
      if(!test.result.secondVisited || !test.result.previousVisited || !test.result.playVisited || !test.result.nextVisited){test.fail("Tab skipped a player or transport");return}
      test.second.forceActiveFocus();test.phase=2
     }
    }else if(test.phase===2){
     test.result.secondProgrammaticFocus=preview.activeFocusItem===test.second
     if(!events.keyClick(Qt.Key_Return,Qt.NoModifier,1)||!events.keyClick(Qt.Key_Space,Qt.NoModifier,1)){test.fail("Qt key event not delivered");return}
     test.second.Accessible.pressAction()
     for(var i=0;i<3;i++) {
      var action=[test.previous,test.play,test.next][i]
      action.forceActiveFocus()
      if(!events.keyClick(Qt.Key_Return,Qt.NoModifier,1)||!events.keyClick(Qt.Key_Space,Qt.NoModifier,1)){test.fail("transport key not delivered");return}
      action.Accessible.pressAction()
     }
     test.phase=3
    }else if(test.phase===3){
     test.result.selectionsAfterKeyboardAndAccessible=fakeService.selections.length
     test.result.transportsAfterAccessible=fakeService.transports.length
     if(fakeService.selections.length!==3 || fakeService.transports.length!==9){test.fail("keyboard or accessibility did not dispatch exactly once");return}
     if(!events.mouseClick(test.second,test.second.width/2,test.second.height/2,Qt.LeftButton,Qt.NoModifier,1)){test.fail("Qt mouse click not delivered");return}
     test.phase=4
    }else if(test.phase===4){
     test.result.selectionsAfterMouse=fakeService.selections
     if(fakeService.selections.length!==4||fakeService.selections[0].player!=="Owned second"){test.fail("positive mouse control did not select the second player");return}
     for(var i=0;i<3;i++){
      var control=[test.previous,test.play,test.next][i]
      if(!events.mouseClick(control,control.width/2,control.height/2,Qt.LeftButton,Qt.NoModifier,1)){test.fail("transport mouse click not delivered");return}
     }
     test.phase=5
    }else if(test.phase===5){
     test.result.transportsAfterMouse=fakeService.transports
     if(fakeService.transports.length!==12){test.fail("mouse controls did not dispatch exactly once");return}
     fakeService.mediaState=Object.assign({},fakeService.mediaState,{player:"Owned second"})
     test.phase=6
    }else if(test.phase===6){
     if(test.second.enabled){test.fail("current player must not dispatch again");return}
     test.second.Accessible.pressAction();test.second.clicked()
     if(fakeService.selections.length!==4){test.fail("disabled player dispatched");return}
     fakeService.mediaState=({});test.phase=7
    }else if(test.phase===7){
     for(var i=0;i<3;i++) {
      var action=[test.previous,test.play,test.next][i]
      if(action.enabled){test.fail("empty media transport enabled");return}
      action.Accessible.pressAction();action.clicked()
     }
     if(fakeService.transports.length!==12){test.fail("disabled transport dispatched");return}
     if(fakeService.selections.some(function(row){return row.peer!=="owned-peer" || row.player!=="Owned second"})){test.fail("selection changed recipient");return}
     console.log("MEDIA_ACCESSIBILITY_PASS "+JSON.stringify(test.result))
     console.log("NATIVE_PASS media accessibility")
     Qt.quit()
    }
   }finally{test.dispatching=false}
  }
 }
}
