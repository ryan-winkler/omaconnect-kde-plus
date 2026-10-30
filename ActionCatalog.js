.pragma library

// These are verified UI entry points, not commands generated from plugin names.
// New actions need a reviewed dispatcher and a contract test before this catalog.
var DEFAULT_ORDER = "file,text,clipboard";
var MAX_ORDER_LENGTH = 512;
var entries = [
    {id:"file", group:"Sharing", pluginId:"kdeconnect_share", label:"Files", description:"Choose files and review before sending", icon:"󰈔", capability:"file", legacyKey:"showActionFile"},
    {id:"text", group:"Sharing", pluginId:"kdeconnect_share", label:"Text or link", description:"Write text or a link to share", icon:"󰌹", capability:"text", legacyKey:"showActionText"},
    {id:"clipboard", group:"Sharing", pluginId:"kdeconnect_clipboard", label:"Clipboard", description:"Send the current clipboard", icon:"󰅌", capability:"clipboard", legacyKey:"showActionClipboard"},
    {id:"ring", group:"Device", pluginId:"kdeconnect_findmyphone", label:"Ring", description:"Request a ring on the selected device", icon:"󰂚", capability:"ring", legacyKey:"showActionRing"},
    {id:"sms", group:"Device", pluginId:"kdeconnect_sms", label:"SMS", description:"Open the native SMS conversation app", icon:"󰍦", capability:"sms", legacyKey:"showActionSms", handoff:true, navigation:true},
    {id:"ping", group:"Device", pluginId:"kdeconnect_ping", label:"Ping", description:"Compose a ping notification", icon:"󰵅", capability:"ping", legacyKey:"showActionPing"},
    {id:"media", group:"Media", pluginId:"kdeconnect_mprisremote", label:"Media controls", description:"Open the media view to choose a reported player", icon:"󰝚", capability:"media", navigation:true},
    {id:"media-previous", group:"Media", pluginId:"kdeconnect_mprisremote", label:"Previous track", description:"Request the previous track on the selected device's active player", icon:"󰒮", capability:"media", requiresMedia:true},
    {id:"media-play-pause", group:"Media", pluginId:"kdeconnect_mprisremote", label:"Play / Pause", description:"Request play or pause on the selected device's active player", icon:"󰐎", capability:"media", requiresMedia:true},
    {id:"media-next", group:"Media", pluginId:"kdeconnect_mprisremote", label:"Next track", description:"Request the next track on the selected device's active player", icon:"󰒭", capability:"media", requiresMedia:true},
    {id:"commands", group:"Device", pluginId:"kdeconnect_remotecommands", label:"Remote commands", description:"Open the command list; choose a configured command before running it", icon:"󰆍", capability:"commands", navigation:true},
    {id:"browse-files", group:"Native KDE Connect", pluginId:"kdeconnect_sftp", label:"Browse files in KDE", description:"Open KDE Connect, then choose Browse files. The other device must permit file access", icon:"󰉋", capability:"browse", handoff:true, navigation:true},
    {id:"native-notifications", group:"Native KDE Connect", pluginId:"kdeconnect_notifications", pluginIds:["kdeconnect_notifications","kdeconnect_sendnotifications","kdeconnect_replynotifications"], label:"Notifications in KDE", description:"Open native KDE Connect to inspect notification modules and permissions", icon:"󰂚", handoff:true, navigation:true},
    {id:"native-volume", group:"Native KDE Connect", pluginId:"kdeconnect_remotesystemvolume", pluginIds:["kdeconnect_remotesystemvolume","kdeconnect_systemvolume"], label:"Volume in KDE", description:"Open native KDE Connect to inspect reported volume features and permissions", icon:"󰕾", handoff:true, navigation:true},
    {id:"native-input", group:"Native KDE Connect", pluginId:"kdeconnect_remotekeyboard", pluginIds:["kdeconnect_remotekeyboard","kdeconnect_mousepad","kdeconnect_presenter","kdeconnect_shareinputdevices"], label:"Input & presentation in KDE", description:"Open native KDE Connect for input or presentation features. Available directions depend on the reported module", icon:"󰌌", handoff:true, navigation:true},
    {id:"native-lock", group:"Native KDE Connect", pluginId:"kdeconnect_lockdevice", label:"Device locking in KDE", description:"Open native KDE Connect to inspect locking support and permissions", icon:"󰌾", handoff:true, navigation:true},
    {id:"native-features", group:"Settings", pluginId:"", label:"Native KDE Connect settings", description:"Open native KDE Connect for all features and Plugin settings", icon:"󰒓", capability:"", legacyKey:"", scope:"global", handoff:true, navigation:true},
    {id:"plus-settings", group:"Settings", pluginId:"", label:"Plus settings", description:"Open Plus appearance, sharing and connection preferences", icon:"󰒓", scope:"global", navigation:true}
];
function entry(id) { return entries.filter(function(row) { return row.id === id; })[0] || null; }
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
function ready(id,device,service) {
    var row=entry(id);
    if (!row || !compatible(id,device)) return false;
    if (id === "plus-settings") return true;
    if (service === null) return false;
    if (!locallyActive(row,device)) return false;
    if (row.requiresMedia && (!hasMedia(service) || (service && service.mediaLoading))) return false;
    return !!(row.navigation || !service || service.actionState !== "running");
}
function availabilityText(id,device,service) {
    var row=entry(id);
    if (!row) return "This shortcut is unavailable.";
    if (service === null && id !== "plus-settings") return "KDE Connect controls are unavailable. Reopen Plus or check native KDE Connect.";
    if (row.scope === "global") return id === "plus-settings" ? "Opens Plus settings. No device connection is required." : "Opens native features and Plugin settings, including the device list when no device is connected.";
    if (!device) return "Choose a device to check availability. Your choice stays saved.";
    if (!device.paired || !device.reachable) return "Available when the device is paired and reachable.";
    if (!supported(row,device))
        return "This device does not report support. Other devices may support it.";
    if (!locallyActive(row,device))
        return row.label + " is not active locally. Check native KDE Connect Plugin Settings.";
    if (row.requiresMedia && (!hasMedia(service) || (service && service.mediaLoading)))
        return "Open Media controls and choose a reported player before using transport buttons.";
    if (row.handoff) return "Opens the selected device in native KDE Connect. Choose or configure the feature there; native permissions still apply.";
    if (!row.navigation && service && service.actionState === "running") return "Another action is running. Wait for its result before starting this action.";
    return "This device reports support; native permissions still apply.";
}
