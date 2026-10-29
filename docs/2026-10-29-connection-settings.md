# Optional connection settings — 29 October 2026

The owner requested separate integration settings because the initial candidate
showed Tailscale and BTH together, then selected a dedicated Settings panel.
The network domain in that panel shows each provider directly, with its own native
toggle, short explainer and official help link. There is no nested network-settings
disclosure in Devices. The default is off for every optional integration.
An installer can explicitly select existing BTH on the owner's two computers.

| Setting | Visible when enabled | Connection owner |
| --- | --- | --- |
| `networkTailscaleEnabled` | Open Tailscale panel | Existing Tailscale panel/app |
| `networkBthEnabled` | Existing BTH status and Automatic / On / Off controls | Reviewed `remote-access-mode` helper |
| `networkWireguardEnabled` | Open WireGuard profiles | Installed NetworkManager editor or existing manager |

These preferences show or hide an integration. They do not install, connect,
disconnect or change a VPN's saved policy. Turning BTH display off must also stop
its status polling: the parent gates `panelOpened` with the saved BTH preference,
current Devices view and the panel's opened state. Existing address approval and
automatic rediscovery have their own explicit options; these display preferences
do not delete address records or modify KDE identity.

`components/NetworkOptions.qml` reads the current bar settings through the panel.
`configuration: true` shows provider preferences directly in the dedicated Settings
panel. The default `false` mode shows only enabled owner buttons and action feedback
in Devices. The Settings panel does not duplicate those daily launch buttons.
The native stateless `qs.Ui.Toggle` keeps `checked` bound to saved configuration.
A click requests the opposite saved value; pending and failed writes do not
optimistically replace it. The controls disable while a request is pending.
The native shell updates the setting; its later configuration readback drives
what is shown. An acknowledgment alone does not fabricate that readback.

`scripts/network_preferences.py` is the shared typed native preference boundary.
Its existing filename and boolean request stay compatible. It accepts the active
manifest boolean keys plus two explicitly permitted strings (`defaultPingMessage`
and `bthHelperPath`). It rejects inactive legacy fields and unknown keys/types.
Input limit: 32 KiB. The fixed native command is
`omarchy-shell shell setBarWidget ryan.omaconnect KEY JSON_VALUE {}`.
The existing bounded command helper enforces a four-second deadline and bounded
output. Only exact `ok` confirms the save. The native shell serializes its own
configuration mutations; no extra config writer or speculative queue is added.
Appearance assets and address metadata keep their separate validation owners.
The helper does not write shell.json directly, read credentials or call a VPN
command. The legacy `showTailscale` setting stays disabled and labelled as legacy.

Official help links open only after an explicit click:

- [Tailscale quickstart](https://tailscale.com/docs/how-to/quickstart)
- [MikroTik Back to Home](https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/)
- [WireGuard quickstart](https://www.wireguard.com/quickstart/)

The URLs were checked against the official sites on 29 October 2026. No keys,
profiles or router state are passed to the browser.

## Focused evidence

The focused tests exercise exact key/value validation, fixed native
arguments, successful/unknown/timed-out replies and rejection without invocation.
A native integration check loads the actual component with native Omarchy controls in the existing
isolated offscreen fixture. Nine assertions cover all-off defaults, hidden owners,
direct settings controls, no optimistic change, configuration readback, failed-save
preservation, independent settings and help discoverability. Its two actual helper
requests reach a fake native IPC executable; no owner, VPN or transfer runs.

Run `python3 -m unittest discover -s tests -p test_network_preferences.py -q`.
Native manifest validation passes. QML lint succeeds with existing host/unqualified
access diagnostics; no warning-free or human accessibility acceptance is claimed.
