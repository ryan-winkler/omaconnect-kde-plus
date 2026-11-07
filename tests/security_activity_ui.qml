import QtQuick
import QtQuick.Window
import Quickshell
import "components" as Components
import "TransferModel.js" as Transfers
ShellRoot {
 id: test
 property string peer: Quickshell.env("SECURITY_ACTIVITY_PEER")
 readonly property double updateTime: Date.UTC(2026, 10, 7, 13, 0)
 function completed(number, peerId, name) {
  return Transfers.record(Transfers.create("owned-operation-" + number, {peerId:peerId,peerName:name}, [{size:3}], test.updateTime, number), 0, "request_accepted", "", test.updateTime)
 }
 function rows(item) {
  var matches = []
  for (var child of item.children)
   matches = matches.concat(child.objectName === "submission-summary" ? [child] : test.rows(child))
  return matches
 }
 function checks(view, includesStatus) {
  var entries = test.rows(view)
  if (entries.length !== 5) return false
  var expectedTime = new Date(test.updateTime).toLocaleString(Qt.locale("en-US"), Locale.ShortFormat)
  var text = entries.map(entry => entry.text)
  return text.every((entry, index) => entry.includes("Submission " + (5 - index))
      && entry.includes(expectedTime) && entries[index].textFormat === Text.PlainText
      && entries[index].Accessible.name === entry
      && (includesStatus ? entry.includes("1/1 requests accepted. Delivery unknown.") : true))
    && text[0].includes(test.peer) && text[1].includes(test.peer)
    && text[2].includes("Shared name") && text[2].includes("a-CC1234")
    && text[3].includes("Shared name") && text[3].includes("b-CC1234")
    && text[4].includes("KDE Connect device")
    && text.every(entry => !entry.includes("private-"))
 }
 QtObject {
  id: fixtureService
  property var operations: [
   test.completed(5, "private-unique-id", test.peer),
   test.completed(4, "private-unique-id", test.peer),
   test.completed(3, "private-duplicate-aa-CC1234", "Shared name"),
   test.completed(2, "private-duplicate-bb-CC1234", "Shared name"),
   test.completed(1, "private-unnamed-id", "private-unnamed-id")
  ]
  property var draftTarget: null
  property var selection: []
  property string selectionError: ""
  property bool operationBusy: false
  function clearOperations() {}
 }
 Window {
  width:600
  height:680
  visible:true
  Components.ActivitySection { id: activity; service:fixtureService; width:280 }
  Components.SendSection { id: send; service:fixtureService; x:300; width:280 }
 }
 Timer { interval:800;running:true;onTriggered: {
  try {
  var actual = test.rows(activity)[0]
  if (!test.checks(activity, true) || !test.checks(send, false) || fixtureService.operations[0].delivery!=="unknown") console.error("ACTIVITY_STATE_FAIL")
  else console.log("ACTIVITY_STATE_PASS")
  console.log("ACTIVITY_PLAIN_FORMAT",!!actual && actual.textFormat===Text.PlainText)
  var help = Array.from(activity.children).find(item => item.objectName === "activity-delivery-help")
  var expected = "Check the receiving device before you send again. If a file is missing, try sending one small file in KDE Connect."
  console.log("ACTIVITY_DELIVERY_HELP", !!help && help.text === expected && help.contentWidth <= help.width)
  } finally { Qt.quit() }
 } }
}
