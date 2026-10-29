.pragma library

// These are verified UI entry points, not commands generated from plugin names.
// New actions need a reviewed dispatcher and a contract test before this catalog.
var DEFAULT_ORDER = "file,text,clipboard";
var entries = [
    {id:"file", pluginId:"kdeconnect_share", label:"Files", description:"Choose files and review before sending", icon:"󰈔", capability:"file", legacyKey:"showActionFile"},
    {id:"text", pluginId:"kdeconnect_share", label:"Text or link", description:"Write text or a link to share", icon:"󰌹", capability:"text", legacyKey:"showActionText"},
    {id:"clipboard", pluginId:"kdeconnect_clipboard", label:"Clipboard", description:"Send the current clipboard", icon:"󰅌", capability:"clipboard", legacyKey:"showActionClipboard"},
    {id:"ring", pluginId:"kdeconnect_findmyphone", label:"Ring", description:"Request a ring on the selected device", icon:"󰂚", capability:"ring", legacyKey:"showActionRing"},
    {id:"sms", pluginId:"kdeconnect_sms", label:"SMS", description:"Open the native SMS conversation app", icon:"󰍦", capability:"sms", legacyKey:"showActionSms"},
    {id:"ping", pluginId:"kdeconnect_ping", label:"Ping", description:"Compose a ping notification", icon:"󰵅", capability:"ping", legacyKey:"showActionPing"},
    {id:"native-features", pluginId:"", label:"KDE Connect features", description:"Open this device in native KDE Connect", icon:"󰒓", capability:"", legacyKey:""}
];
function entry(id) { return entries.filter(function(row) { return row.id === id; })[0] || null; }
function parse(value) {
    if (typeof value !== "string" || value.length > 128) return null;
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
function compatible(id,device) {
    var row=entry(id);
    return !!(row && device && device.paired && device.reachable
        && (!row.capability || (device.capabilities && device.capabilities[row.capability])));
}
function available(value,device) { return order(value).filter(function(id) { return compatible(id,device); }); }
function availabilityText(id,device) {
    if (!device) return "Choose a device to check availability. Your choice stays saved.";
    if (!device.paired || !device.reachable) return "Available when the device is paired and reachable.";
    var row=entry(id);
    if (row && row.capability && (!device.capabilities || !device.capabilities[row.capability]))
        return "This device does not report support. Other devices may support it.";
    if (row && row.pluginId && device.loadedKnown && (device.loadedPluginIds || []).indexOf(row.pluginId) < 0)
        return row.label + " is not active locally. Check native KDE Connect Plugin Settings.";
    return id === "native-features" ? "Opens native features and plugin settings." : "This device reports support; native permissions still apply.";
}
