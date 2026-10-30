import QtQuick
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var checks: []
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL preferences: " + message); Qt.quit(); return false }
        checks = checks.concat([message]); return true
    }
    function find(object, label) {
        if (!object) return null
        if (object.Accessible && object.Accessible.name === label && typeof object.clicked === "function") return object
        if ("text" in object && object.text === label && typeof object.clicked === "function") return object
        var children = object.children || []
        for (var i = 0; i < children.length; i++) { var result = find(children[i], label); if (result) return result }
        return null
    }
    function textItem(item, value) {
        if ("text" in item && item.text === value && "truncated" in item) return item
        var children = item.children || []
        for (var i=0; i<children.length; i++) { var found=textItem(children[i],value); if(found)return found }
        return null
    }
    QtObject {
        id: fakePanel
        property var settings: ({})
        function getSetting(key, fallback) { return key in settings ? settings[key] : fallback }
    }
    Item {
        width: 400; height: 700
        Components.PreferenceControls { id: preferences; width: 220; panel: fakePanel; preferences: [{key:"fixture",label:"A long settings label that must not hide state",defaultValue:false}] }
        Components.NetworkOptions { id: options; width: parent.width; panel: fakePanel; configuration: true }
        Components.NetworkOptions { id: daily; width: parent.width; panel: fakePanel }
    }
    Timer {
        interval: 30; repeat: true; running: true
        onTriggered: {
            if (++test.ticks > 150) { test.check(false, "scenario completed before deadline"); return }
            if (test.phase === 0) {
                if (!test.check(!options.tailscaleEnabled && !options.bthEnabled && !options.wireguardEnabled, "all optional integrations default off")) return
                if (!test.check(!test.find(daily, "Open Tailscale panel").visible && !test.find(daily, "Open WireGuard profiles").visible, "disabled owner buttons hidden")) return
                var checkbox = test.find(options, "Show Tailscale")
                if (!test.check(options.configuration && checkbox !== null, "dedicated settings shows labelled switches directly")) return
                var off = test.textItem(checkbox,"Off"), pref = test.find(preferences,"A long settings label that must not hide state")
                if (!test.check(off && !off.truncated && pref && pref.description === "Off", "both switch types expose non-elided saved state")) return
                checkbox.clicked()
                if (!test.check(!checkbox.checked && !options.tailscaleEnabled, "save request does not optimistically change saved state")) return
                test.phase = 1
            } else if (test.phase === 1 && !options.busy && options.message.indexOf("Setting saved.") === 0) {
                if (!test.check(!options.tailscaleEnabled, "acknowledgment alone does not fabricate config readback")) return
                fakePanel.settings = ({networkTailscaleEnabled: true})
                test.phase = 2
            } else if (test.phase === 2) {
                var checkbox = test.find(options, "Show Tailscale")
                if (!test.check(checkbox.checked && options.tailscaleEnabled && test.find(daily, "Open Tailscale panel").visible && !test.find(options, "Open Tailscale panel").visible, "saved config readback shows owner only in daily view")) return
                var on = test.textItem(checkbox,"On")
                if (!test.check(on && !on.truncated, "saved On state remains visible")) return
                checkbox.clicked()
                test.phase = 3
            } else if (test.phase === 3 && !options.busy && options.message.indexOf("not confirmed") !== -1) {
                if (!test.check(test.find(options, "Show Tailscale").checked && options.tailscaleEnabled, "failed save preserves saved switch and integration")) return
                fakePanel.settings = ({networkBthEnabled: true})
                test.phase = 4
            } else if (test.phase === 4) {
                if (!test.check(options.bthEnabled && !options.tailscaleEnabled && !options.wireguardEnabled, "provider preferences remain independent")) return
                if (!test.check(test.find(options, "Open official MikroTik Back to Home help in your browser") !== null, "official help is discoverable")) return
                console.log("PREFERENCES_PASS " + JSON.stringify(test.checks))
                console.log("NATIVE_PASS preferences")
                Qt.quit()
            }
        }
    }
}
