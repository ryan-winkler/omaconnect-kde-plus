pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "BthControlModel.js" as Control

Column {
    id: root
    property bool panelOpened: false
    property int keyboardIndex: -1
    property var status: Control.unknown()
    property string wantedMode: ""
    property string feedback: ""
    readonly property bool busy: action.running
    // Reused from banan.bananet, Copyright (c) 2026 banan, MIT; see notice below.
    property string helperPath: Quickshell.env("HOME") + "/.local/bin/remote-access-mode"
    readonly property bool helperPathValid: Control.validHelperPath(helperPath)
    property bool helperMissing: false
    signal hoveredControl(int index)
    signal ensureVisibleRequested()
    spacing: Style.space(6)
    onKeyboardIndexChanged: if (keyboardIndex >= 0) ensureVisibleRequested()
    onHelperPathChanged: {
        status = Control.unknown()
        wantedMode = ""
        helperMissing = false
        if (panelOpened) refreshStatus()
    }

    function refreshStatus() {
        if (helperPathValid && !query.running && !action.running) query.running = true
    }
    function activate(index) {
        var mode = ["auto", "on", "off"][index]
        if (!helperPathValid || !Control.canRun(status, mode, action.running)) return
        wantedMode = mode
        feedback = "Saving " + Control.modeLabel(mode) + "…"
        action.mode = mode
        action.running = true
    }
    function loadStatus(raw) {
        status = Control.parse(raw)
        if (wantedMode && Control.confirmed(status, wantedMode)) {
            wantedMode = ""
            feedback = "Mode saved. Actual interface state is shown below."
        }
    }
    onPanelOpenedChanged: if (panelOpened) refreshStatus()
    Component.onCompleted: if (panelOpened) refreshStatus()
    Timer {
        interval: 5000
        repeat: true
        running: root.panelOpened
        onTriggered: root.refreshStatus()
    }
    Process {
        id: query
        property bool oversized: false
        property string pathUsed: ""
        command: ["/usr/bin/timeout", "4", root.helperPath, "control-status"]
        onStarted: { oversized = false; pathUsed = root.helperPath }
        stdout: StdioCollector {
            id: statusOutput
            waitForEnd: false
            onDataChanged: if (text.length > Control.MAX_STATUS) { query.oversized = true; query.running = false }
        }
        onExited: function(code) {
            if (pathUsed !== root.helperPath) { root.status = Control.unknown(); Qt.callLater(root.refreshStatus); return }
            root.helperMissing = code === 127
            if (code === 0 && !oversized) root.loadStatus(statusOutput.text)
            else root.status = Control.unknown()
        }
    }
    Process {
        id: action
        property string mode: ""
        property bool oversized: false
        command: ["/usr/bin/timeout", "8", root.helperPath, Control.command(mode)]
        onStarted: oversized = false
        stdout: StdioCollector {
            waitForEnd: false
            onDataChanged: if (text.length > Control.MAX_STATUS) { action.oversized = true; action.running = false }
        }
        // Do not collect or show helper stderr. Only fixed UI messages reach the user.
        onExited: function(code) {
            if (code !== 0 || oversized) {
                root.wantedMode = ""
                root.feedback = "The request did not finish. Refreshing the actual state."
            } else root.feedback = "Request saved. Waiting for the actual interface state."
            root.refreshStatus()
        }
    }

    Kit.PanelSeparator { foreground: Commons.Color.popups.text }
    Text {
        textFormat: Text.PlainText
        width: parent.width

        text: "MikroTik Back to Home · WireGuard"
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width

        text: "WireGuard: " + Control.stateLabel(root.status.connection_state) + " · Selected mode: " + Control.selectedModeLabel(root.status)
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width

        text: root.helperMissing ? "Optional BTH controller is not installed. Use your existing reviewed VPN setup to install remote-access-mode, then refresh. No setup runs from this card." : Control.errorText(root.status)
        visible: text !== ""
        color: Commons.Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Row {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
            model: ["auto", "on", "off"]
            delegate: Kit.Button {
                required property string modelData
                required property int index
                width: (root.width - Style.space(12)) / 3
                text: Control.modeLabel(modelData)
                selected: Control.isSelected(root.status, modelData)
                hasCursor: root.keyboardIndex === index
                focusable: true
                enabled: root.helperPathValid && Control.canRun(root.status, modelData, root.busy)
                Accessible.name: "Back To Home " + text
                Accessible.description: modelData === "auto" ? "Off at home, on away"
                    : modelData === "off" ? "Keep BTH off until On or Automatic is selected" : "Turn the saved WireGuard profile on manually"
                onClicked: root.activate(index)
                onHovered: function(value) { if (value) root.hoveredControl(index) }
            }
        }
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width

        text: Control.pendingText(root.status, root.wantedMode) || root.feedback
        visible: text !== ""
        color: root.status.last_apply_failed ? Commons.Color.urgent : Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Text {
        textFormat: Text.PlainText
        width: parent.width

        text: "Automatic: off at home, on away. Off: stays off until you choose On or Automatic. This card shows interface state, not a remote-service test."
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
}

/*
Adapted from banan.bananet.
MIT License

Copyright (c) 2026 banan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
