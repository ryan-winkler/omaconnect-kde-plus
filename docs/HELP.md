# Contextual help coverage

Each feature has short task guidance beside its controls, a direct documentation
link, or both. External links open only when the user selects them. Help stays in
the owning domain; there is no extra daily help dashboard to search first.

| Feature | In-app help and documentation |
| --- | --- |
| Bar/device icons and local aliases | Appearance explains identity versus display; chooser explains preview/Apply, advanced choices and validation. Appearance opens the installed ICONS.md contribution guide. |
| Quick actions | Add/Up/Down/Remove instructions; each catalog item has a description and selected-device availability. Adding a shortcut does not enable or execute a native plugin. |
| Native features and permissions | Search scope/state legend, offline next step, selected-device native route, and official KDE user guide. |
| Tailscale | Independent display switch, existing-owner/address instructions and official quickstart. |
| MikroTik BTH | Independent display switch, Automatic/On/Off intent-versus-state help, trusted helper-path help and official BTH manual. |
| Other WireGuard profiles | Independent display switch, native manager/address instructions and official quickstart. |
| File chooser and drop | Choose files or persistent Send window; local-file/count/size limits; review before explicit Send; Copy protects originals; existing draft/busy reasons remain visible. |
| File activity and cancellation | Accepted-versus-delivered explanation, session-only retention and unconfirmed cancellation state. |
| Saved addresses | Source labels, explicit approval, identity warning, opt-in rediscovery and separate removal review. Provider setup documentation is in Connections. |
| Syncthing identity link | Full identity check, explicit local-only association explanation, existing owner button and official device setup guide. |
| Ring unavailable | Known-unloaded module message and native Plugin Settings next step; command acceptance does not claim sound. |

The official links were checked against provider documentation. Do not put API
keys, addresses, private IDs or configuration contents into help URLs. Do not
add a shell command or arbitrary URL field as a shortcut for documented features.

A future native action needs a verified dispatch contract and catalog entry before
it is offered as an executable shortcut. Safe unknown native modules remain
searchable through the native owner route without inventing invocation semantics.
