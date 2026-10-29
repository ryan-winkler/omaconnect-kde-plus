# Help with Omaconnect KDE Plus

Open **Settings** from the bar menu. Choose the domain that matches your task.
Use **Back to devices** to return. Native KDE Connect opens in its own window;
your Plus settings remain available. Select a device before changing its features.

## Appearance

- **Bar icon:** Select **Change bar icon**. Choose a labelled preset, search the
  installed icon theme, or use a custom symbol or local PNG/SVG. Preview, then Apply.
- **Device icon and name:** Select a device, then **Change selected device icon and
  alias**. A local alias changes its display here. It does not change pairing.
- **Battery beside the icon:** Enable this to show a reported charge. Missing
  battery information stays unknown.
- **Contribute an icon:** Read the [icon source and storage guide](ICONS.md).
  It explains the renderer, presets, private assets and contribution checks.

## Connections

Enable only the integrations you use. Each display switch shows or hides its
controls. It does not install, connect or disconnect a VPN.

| Integration | Use it | Official setup guide |
| --- | --- | --- |
| Tailscale | Open the existing Tailscale panel. Connect in its owner app. Approve the peer’s Tailscale IP under **Manage saved addresses**. | [Tailscale quickstart](https://tailscale.com/docs/how-to/quickstart) |
| MikroTik Back to Home | Use the existing reviewed helper. **Automatic** uses its policy; **On** requests activation; **Off** requests that it stay stopped. Read actual connection state separately. | [MikroTik Back to Home](https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/) |
| Other WireGuard profiles | Open the existing NetworkManager profiles. The manager owns profiles and keys. Approve the peer’s private VPN IP for rediscovery. | [WireGuard quickstart](https://www.wireguard.com/quickstart/) |

**BTH helper path** is optional. Empty uses `~/.local/bin/remote-access-mode`.
Use an absolute path to your existing reviewed controller. Plus does not create
that controller or import keys. A missing provider shows an unavailable result.
See [provider contracts](CONTRACTS.md) before connecting a different controller.

**Saved addresses:** Select a device. Open **Manage saved addresses**. Enter one IP,
choose its source and approve it. An address is a route hint; the KDE identity
still owns trust. Automatic rediscovery requires both the address opt-in and the
panel-session switch. It runs while the panel is open, with a 60-second interval.
**Forget local address record** removes Plus metadata. **Review removal from KDE**
needs a second selection and preserves pre-existing native addresses.

## Quick actions

Choose a shortcut, then select **Add selected action**. Use **Up**, **Down** or
**Remove** to change the toolbar. **Use default actions** restores Files, Text or
link, and Clipboard. These choices do not enable a native module or execute it.
Each action shows its description and selected-device availability.

- **Files:** Open the normal desktop file chooser, then review before Send.
- **Text or link:** Compose the content and send it explicitly.
- **Clipboard:** Send the current clipboard to the selected device.
- **Ring:** Request a sound. If unavailable, open native **Plugin settings** and
  check Find my phone. A successful command does not confirm an audible sound.
- **SMS:** Open native KDE Connect conversations, where the platform permits it.
- **Ping:** Compose a notification. The optional default message fills the draft;
  you can edit it before sending. Ping and Ring use different native modules.
- **KDE Connect features:** Open the selected peer in native KDE Connect.

## Device features

Open **All KDE Connect features**, then use native **Plugin settings** to enable
or configure installed modules and permissions. Search in Plus by task or plugin
ID to find reported features, including unfamiliar third-party IDs. Supported
means compatible; Loaded describes the local daemon. Neither confirms permission.
The native page manages installed modules; it is not a plugin download store.
Read the [KDE Connect user guide](https://kdeconnect.kde.org/users.html).

- **Battery details:** Show charge and charging state when reported.
- **Cellular connection details:** Show reported cellular type and signal; this
  does not describe Wi-Fi or VPN reachability.
- **Media controls:** Expand Media in Devices. Choose a reported player and use
  previous, play/pause or next. Playback stays in the owner app.
- **Remote commands:** Expand Remote commands in Devices. Commands run on the
  selected device. Add or edit them in that device’s KDE Connect Run commands settings.

## Send files and read activity

1. Select a paired, reachable device. Open **Send**.
2. Select **Choose files** for the graphical desktop chooser. For file-manager
   drag and drop, select **Open Send window** so the target stays open.
3. Choose or drop up to 100 local regular files, at most 1 TiB combined.
   Directories and remote URLs are not accepted. Drops use Copy and preserve originals.
4. Check the recipient, files, count and size. Select **Send files**. A changed
   device selection does not redirect a reviewed batch.
5. Read Activity. **Request accepted** confirms command acceptance. Check the
   recipient for actual receipt. **Stop submitting** can stop remaining requests;
   it does not confirm cancellation of work already accepted by KDE Connect.

**Cancel selection** discards the draft. Closing the Send window preserves it.
Activity keeps at most 50 summaries for this session and excludes raw paths.
Read [current verification and limits](VERIFICATION.md) for tested device scope.

## Syncthing identity link

Select a device and open **Link Syncthing device**. Compare both full identities
in their owner apps. Enter the full Syncthing device ID and confirm the local link.
This does not pair devices, start sync or verify ownership. **Remove local link**
removes only the association. **Open existing Syncthing panel** opens Syncshell;
it retains the synchronization engine and keys. Read the official
[Syncthing device setup guide](https://docs.syncthing.net/intro/getting-started.html).

## Get help or contribute

Use [support](../SUPPORT.md) for task help and safe issue evidence,
[contributing](../CONTRIBUTING.md) for small changes, or
[security reporting](../SECURITY.md) for private vulnerability reports.
Do not publish private IDs, addresses, configurations or credentials.

---

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
