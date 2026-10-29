.pragma library

// One resolver for the bar, device rows and chooser. It has no provider actions.
var presets = [
    {label:"Phone", mode:"preset", value:"phone", glyph:"󰄜", theme:"smartphone-symbolic"},
    {label:"Desktop", mode:"preset", value:"desktop", glyph:"󰍹", theme:"computer-symbolic"},
    {label:"Laptop", mode:"preset", value:"laptop", glyph:"󰌢", theme:"laptop-symbolic"},
    {label:"Link", mode:"preset", value:"link", glyph:"󰌷", theme:"insert-link-symbolic"},
    {label:"Share", mode:"preset", value:"share", glyph:"󰒪", theme:"document-send-symbolic"}
];
var glyphs = [
    {label:"Phone symbol",mode:"glyph",value:"☎"},
    {label:"Link symbol",mode:"glyph",value:"↔"},
    {label:"Share arrow",mode:"glyph",value:"↗"},
    {label:"Star symbol",mode:"glyph",value:"★"},
    {label:"Circle symbol",mode:"glyph",value:"●"}
];
function phone() { return {mode:"preset",value:"phone",render:"symbolic"}; }
function normalizeLegacy(value) { return value === true ? {mode:"automatic",render:"symbolic"} : phone(); }
function normalizeIcon(value, device) {
    if (!value || typeof value !== "object") return device ? {mode:"inherit",render:"symbolic"} : phone();
    var mode = value.mode, text = String(value.value || "");
    if (mode === "automatic" || (device && mode === "inherit")) return {mode:mode,render:"symbolic"};
    if (mode === "preset" && !presets.some(function(p) { return p.value === text; })) return phone();
    if (mode === "theme" && !/^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(text)) return phone();
    if (mode === "image" && !/^[a-f0-9]{64}\.(png|svg)$/.test(text)) return phone();
    if (mode === "glyph" && (!text.trim() || Array.from(text).length > 8 || /[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/.test(text))) return phone();
    if (["preset","theme","image","glyph"].indexOf(mode) < 0) return phone();
    var result = {mode:mode,value:text,render:value.render === "color" ? "color" : "symbolic"};
    if (mode === "glyph" && value.font) result.font = String(value.font);
    return result;
}
function key(id) { return String(id || "").indexOf("kdeconnect:") === 0 ? String(id) : "kdeconnect:" + String(id || ""); }
function record(snapshot,id) { return snapshot && snapshot.devices ? snapshot.devices[key(id)] || {} : {}; }
function typeIcon(type) {
    var value = String(type || "").toLowerCase();
    if (value === "tablet" || value === "tv") return {mode:"theme",value:value === "tablet" ? "tablet-symbolic" : "video-display-symbolic",render:"symbolic"};
    return {mode:"preset",value:["phone","desktop","laptop"].indexOf(value) >= 0 ? value : "phone",render:"symbolic"};
}
function deviceIcon(snapshot,id,type) {
    var value = normalizeIcon(record(snapshot,id).icon,true);
    return value.mode === "inherit" || value.mode === "automatic" ? typeIcon(type) : value;
}
function barIcon(snapshot,id,type) {
    var value = normalizeIcon(snapshot ? snapshot.bar_icon : null,false);
    return value.mode === "automatic" ? deviceIcon(snapshot,id,type) : value;
}
function displayName(snapshot,id,advertised) { return record(snapshot,id).alias || String(advertised || ""); }
function glyphFor(icon) {
    var value = normalizeIcon(icon,false);
    if (value.mode === "glyph") return value.value;
    var entry = presets.filter(function(p) { return p.value === value.value; })[0];
    return entry ? entry.glyph : presets[0].glyph;
}
function themeFor(icon) {
    if (icon.mode === "theme") return icon.value;
    var entry = presets.filter(function(p) { return p.value === icon.value; })[0];
    return entry ? entry.theme : "";
}
function library(query,themes) {
    var all = presets.concat(glyphs).concat((themes || []).map(function(name) { return {label:name,mode:"theme",value:name}; }));
    var filter = String(query || "").toLowerCase().trim();
    return all.filter(function(entry) { return !filter || entry.label.toLowerCase().indexOf(filter) >= 0; });
}
