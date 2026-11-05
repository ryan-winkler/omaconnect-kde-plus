.pragma library

// These are verified UI entry points, not commands generated from plugin names.
// New actions need a reviewed dispatcher and a contract test before this catalog.
var DEFAULT_ORDER = "file,text,clipboard";
var MAX_ORDER_LENGTH = 512;
var entries = [
    {id:"file", groupKey:"actions.group.sharing", pluginId:"kdeconnect_share", labelKey:"actions.file.label", descriptionKey:"actions.file.description", icon:"󰈔", capability:"file", legacyKey:"showActionFile"},
    {id:"text", groupKey:"actions.group.sharing", pluginId:"kdeconnect_share", labelKey:"actions.text.label", descriptionKey:"actions.text.description", icon:"󰌹", capability:"text", legacyKey:"showActionText"},
    {id:"clipboard", groupKey:"actions.group.sharing", pluginId:"kdeconnect_clipboard", labelKey:"actions.clipboard.label", descriptionKey:"actions.clipboard.description", icon:"󰅌", capability:"clipboard", legacyKey:"showActionClipboard"},
    {id:"quick-share", groupKey:"actions.group.sharing", pluginId:"", labelKey:"actions.quick-share.label", descriptionKey:"actions.quick-share.description", icon:"󰒗", scope:"global", navigation:true},
    {id:"ring", groupKey:"actions.group.device", pluginId:"kdeconnect_findmyphone", labelKey:"actions.ring.label", descriptionKey:"actions.ring.description", icon:"󰂚", capability:"ring", legacyKey:"showActionRing"},
    {id:"sms", groupKey:"actions.group.device", pluginId:"kdeconnect_sms", labelKey:"actions.sms.label", descriptionKey:"actions.sms.description", icon:"󰍦", capability:"sms", legacyKey:"showActionSms", handoff:true, navigation:true},
    {id:"ping", groupKey:"actions.group.device", pluginId:"kdeconnect_ping", labelKey:"actions.ping.label", descriptionKey:"actions.ping.description", icon:"󰵅", capability:"ping", legacyKey:"showActionPing"},
    {id:"media", groupKey:"actions.group.media", pluginId:"kdeconnect_mprisremote", labelKey:"actions.media.label", descriptionKey:"actions.media.description", icon:"󰝚", capability:"media", navigation:true},
    {id:"media-previous", groupKey:"actions.group.media", pluginId:"kdeconnect_mprisremote", labelKey:"actions.media-previous.label", descriptionKey:"actions.media-previous.description", icon:"󰒮", capability:"media", requiresMedia:true},
    {id:"media-play-pause", groupKey:"actions.group.media", pluginId:"kdeconnect_mprisremote", labelKey:"actions.media-play-pause.label", descriptionKey:"actions.media-play-pause.description", icon:"󰐎", capability:"media", requiresMedia:true},
    {id:"media-next", groupKey:"actions.group.media", pluginId:"kdeconnect_mprisremote", labelKey:"actions.media-next.label", descriptionKey:"actions.media-next.description", icon:"󰒭", capability:"media", requiresMedia:true},
    {id:"commands", groupKey:"actions.group.device", pluginId:"kdeconnect_remotecommands", labelKey:"actions.commands.label", descriptionKey:"actions.commands.description", icon:"󰆍", capability:"commands", navigation:true},
    {id:"browse-files", groupKey:"actions.group.device", pluginId:"kdeconnect_sftp", labelKey:"actions.browse-files.label", descriptionKey:"actions.browse-files.description", icon:"󰉋", capability:"browse", navigation:true},
    {id:"native-notifications", groupKey:"actions.group.native-kde-connect", pluginId:"kdeconnect_notifications", pluginIds:["kdeconnect_notifications","kdeconnect_sendnotifications","kdeconnect_replynotifications"], labelKey:"actions.native-notifications.label", descriptionKey:"actions.native-notifications.description", icon:"󰂚", handoff:true, navigation:true},
    {id:"native-volume", groupKey:"actions.group.native-kde-connect", pluginId:"kdeconnect_remotesystemvolume", pluginIds:["kdeconnect_remotesystemvolume","kdeconnect_systemvolume"], labelKey:"actions.native-volume.label", descriptionKey:"actions.native-volume.description", icon:"󰕾", handoff:true, navigation:true},
    {id:"native-input", groupKey:"actions.group.native-kde-connect", pluginId:"kdeconnect_remotekeyboard", pluginIds:["kdeconnect_remotekeyboard","kdeconnect_mousepad","kdeconnect_presenter","kdeconnect_shareinputdevices"], labelKey:"actions.native-input.label", descriptionKey:"actions.native-input.description", icon:"󰌌", handoff:true, navigation:true},
    {id:"native-lock", groupKey:"actions.group.native-kde-connect", pluginId:"kdeconnect_lockdevice", labelKey:"actions.native-lock.label", descriptionKey:"actions.native-lock.description", icon:"󰌾", handoff:true, navigation:true},
    {id:"external-monitor", groupKey:"actions.group.native-kde-connect", pluginId:"kdeconnect_virtualmonitor", labelKey:"actions.external-monitor.label", activeLabelKey:"actions.external-monitor.activeLabel", descriptionKey:"actions.external-monitor.description", icon:"󰍹"},
    {id:"native-features", groupKey:"actions.group.settings", pluginId:"", labelKey:"actions.native-features.label", descriptionKey:"actions.native-features.description", icon:"󰒓", capability:"", legacyKey:"", scope:"global", handoff:true, navigation:true},
    {id:"plus-settings", groupKey:"actions.group.settings", pluginId:"", labelKey:"actions.plus-settings.label", descriptionKey:"actions.plus-settings.description", icon:"󰒓", scope:"global", navigation:true}
];
function entry(id) { return entries.filter(function(row) { return row.id === id; })[0] || null; }
function actionLabelKey(id,device) {
    var row=entry(id);
    return row ? (id === "external-monitor" && device && device.virtualMonitor && device.virtualMonitor.active ? row.activeLabelKey : row.labelKey) : id;
}
function parse(value) {
    if (typeof value !== "string" || value.length > MAX_ORDER_LENGTH) return null;
    if (value === "") return [];
    var ids = value.split(",");
    if (ids.length > entries.length) return null;
    var seen = {};
    for (var i=0; i<ids.length; i++) {
        if (!entry(ids[i]) || seen[ids[i]]) return null;
        seen[ids[i]] = true;
    }
    return ids;
}
function order(value) { var result=parse(value); return result === null ? DEFAULT_ORDER.split(",") : result; }
function pluginIds(row) { return row.pluginIds || (row.pluginId ? [row.pluginId] : []); }
function supported(row,device) {
    if (row.capability && device.capabilities && typeof device.capabilities[row.capability] === "boolean")
        return device.capabilities[row.capability];
    var ids=pluginIds(row), reported=device.pluginIds || [];
    return ids.length === 0 || ids.some(function(id) { return reported.indexOf(id) >= 0; });
}
function compatible(id,device) {
    var row=entry(id);
    return !!(row && (row.scope === "global" || (device && device.paired && device.reachable && supported(row,device))));
}
function available(value,device) { return order(value).filter(function(id) { return compatible(id,device); }); }
function locallyActive(row,device) {
    if (!device || !device.loadedKnown || row.handoff) return true;
    var ids=pluginIds(row), loaded=device.loadedPluginIds || [];
    return ids.length === 0 || ids.some(function(id) { return loaded.indexOf(id) >= 0; });
}
function hasMedia(service) {
    var media=service && service.mediaState;
    return !!(media && (media.player || media.title || media.artist || media.album));
}
function browsePending(service) {
    return !!service && (service.phoneFilesState === "preparing" || service.phoneFilesState === "opening"
        || service.phoneFilesState === "choosing");
}
function ready(id,device,service) {
    var row=entry(id);
    if (!row || !compatible(id,device)) return false;
    if (id === "plus-settings") return true;
    if (service === null) return false;
    if (id === "quick-share") return !!service.quickShareAvailable && !service.quickShareOpening;
    if (id === "browse-files" && service && (service.phoneFilesBusy || browsePending(service))) return false;
    if (!locallyActive(row,device)) return false;
    if (id === "external-monitor" && (!device.virtualMonitor || !device.virtualMonitor.known || (!device.virtualMonitor.active && !device.virtualMonitor.available))) return false;
    if (row.requiresMedia && (!hasMedia(service) || (service && service.mediaLoading))) return false;
    return !!(row.navigation || !service || service.actionState !== "running");
}
function availabilityKey(id,device,service) {
    var row=entry(id);
    if (!row) return "actionAvailability.thisShortcutIsUnavailable";
    if (service === null && id !== "plus-settings") return "actionAvailability.kdeConnectControlsAreUnavailableReopen";
    if (id === "quick-share") return service && service.quickShareOpening ? "actionAvailability.openingRquickshareWaitForTheLauncher"
        : service && service.quickShareAvailable ? "actionAvailability.opensRquickshareQuickShareIsA" : "actionAvailability.installTheRQuickSharePackage";
    if (row.scope === "global") return id === "plus-settings" ? "actionAvailability.opensPlusSettingsNoDeviceConnection" : "actionAvailability.opensNativeFeaturesAndPluginSettings";
    if (!device) return "actionAvailability.chooseADeviceToCheckAvailability";
    if (!device.paired || !device.reachable) return "actionAvailability.availableWhenTheDeviceIsPaired";
    if (!supported(row,device))
        return "actionAvailability.thisDeviceDoesNotReportSupport";
    if (!locallyActive(row,device))
        return "actionAvailability.thisActionIsNotActiveLocally";
    if (id === "browse-files") return service && service.phoneFilesBusy ? "actionAvailability.phoneStorageIsBusyWaitOr"
        : "actionAvailability.openThePhoneSSharedFolders";
    if (id === "external-monitor" && (!device.virtualMonitor || !device.virtualMonitor.known)) return "actionAvailability.nativeMonitorStateIsUnavailableOpen";
    if (id === "external-monitor" && !device.virtualMonitor.active && !device.virtualMonitor.available) return "actionAvailability.nativeVirtualMonitorIsUnavailableOn";
    if (row.requiresMedia && (!hasMedia(service) || (service && service.mediaLoading)))
        return "actionAvailability.openMediaControlsAndChooseA";
    if (row.handoff) return "actionAvailability.opensTheSelectedDeviceInNative";
    if (!row.navigation && service && service.actionState === "running") return "actionAvailability.anotherActionIsRunningWaitFor";
    return "actionAvailability.thisDeviceReportsSupportNativePermissions";
}
