import QtQuick
import QtQuick.Window
import Quickshell
import "components" as Components
import "TransferModel.js" as Transfers
ShellRoot {
 id: test
 property string peer: Quickshell.env("SECURITY_ACTIVITY_PEER")
 function row(item) {
  if (typeof item.text === "string" && item.text.indexOf("KDE ID: owned-peer") >= 0) return item
  for (var i=0;i<item.children.length;i++) { var found=row(item.children[i]);if(found)return found }
  return null
 }
 QtObject { id: fixtureService; property var operations: [Transfers.record(Transfers.create("owned-operation",{peerId:"owned-peer",peerName:test.peer},[{size:3}],1),0,"request_accepted","",2)]; function clearOperations() {} }
 Window { width:520;height:400;visible:true; Components.ActivitySection { id: activity; service:fixtureService;width:500 } }
 Timer { interval:800;running:true;onTriggered: {
  var actual=test.row(activity)
  if (!actual || actual.text.indexOf(test.peer)!==0 || actual.text.indexOf("1/1 requests accepted. Delivery unknown.")<0 || fixtureService.operations[0].delivery!=="unknown") console.error("ACTIVITY_STATE_FAIL")
  else console.log("ACTIVITY_STATE_PASS")
  console.log("ACTIVITY_PLAIN_FORMAT",!!actual && actual.textFormat===Text.PlainText)
  Qt.quit()
 } }
}
