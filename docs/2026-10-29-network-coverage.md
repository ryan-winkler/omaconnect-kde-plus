# Network coverage — 29 October 2026

**Decision:** Present Tailscale, MikroTik Back to Home and WireGuard together.
Keep their existing connection managers. Use the same explicit KDE address
approval and rediscovery path for all three.

## Candidate coverage

| Provider | Available in this fork | Existing owner | Limit |
| --- | --- | --- | --- |
| Tailscale | Named address provenance; approve its peer IP; bounded opt-in KDE rediscovery; open native Tailscale panel | Installed `omarchy.tailscale` panel and Tailscale daemon | No inline peer/status adapter yet; a missing owner stays unavailable. Opening the panel does not enable or install Tailscale. |
| MikroTik Back to Home | Existing strict public status and Automatic / On / Off controls; named approved addresses; bounded opt-in KDE rediscovery | Reviewed `remote-access-mode` helper | BTH setup and secrets stay with their current owners. Interface state does not prove service reachability. |
| WireGuard | Named approved private addresses; bounded opt-in KDE rediscovery; open native profile editor | Installed NetworkManager profile editor, or the user's existing WireGuard manager | The fork does not import profiles, toggle arbitrary tunnels or read keys/handshakes. The launch says requested, not that a profile connected. |

Back to Home uses WireGuard. The UI names the managed BTH policy separately from
other WireGuard profiles so users can select the correct owner. MikroTik's
[official BTH manual](https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/)
describes that relationship.

The generic WireGuard owner button starts `/usr/bin/nm-connection-editor` with no
profile arguments. If that optional editor is absent, the UI gives a clear
unavailable message. It does not assume every WireGuard installation uses
NetworkManager. The BTH card remains the sole fork entry point for the reviewed
BTH mode helper.

## Address contract

The existing schema version remains 1. `source` now permits `tailscale` alongside
`manual`, `bth` and `wireguard`. All sources accept the existing private IPv4/ULA
policy, with the existing BTH IPv6 restriction. Only the explicit `tailscale`
source additionally accepts IPv4 `100.64.0.0/10`. This range comes from
[Tailscale's IP address documentation](https://tailscale.com/docs/concepts/tailscale-ip-addresses).
It is shared address space, so the source label is provenance selected by the
user. It does not prove an IP belongs to Tailscale or to the selected KDE peer.

Automatic rediscovery, metadata readback, automatic-option changes and removal
retain that source. Public IPs, hostnames, subnets, shell text and scoped link-local
addresses remain rejected. Approval is explicit. Existing KDE addresses and
manual baseline ownership remain protected. The legacy Tailscale peer list and
legacy address writer stay disabled.

## Contribution boundaries

- `components/NetworkOptions.qml`: task labels, owner-launch buttons and feedback.
- `scripts/open_network_owner.py`: two fixed owner routes and bounded replies.
- `components/SavedAddressesSection.qml`: source labels and explicit approval.
- `scripts/manage_addresses.py`: validated source-scoped address policy and atomic metadata reconciliation.
- `DiscoveryModel.js` / `DiscoveryController.qml`: bounded response parsing and approved rediscovery queue.
- `BthControlCard.qml` / `BthControlModel.js`: existing reviewed BTH policy adapter.

A later inline Tailscale adapter must use bounded fixed commands, distinguish
provider availability from connection state and retain selected KDE identity
review. It must use the current address helper. Do not revive the legacy writer.
Generic WireGuard toggles require an explicit profile ownership contract before
implementation. Do not infer that every WireGuard profile can use BTH's
Automatic/On/Off policy.

## Evidence

Seven focused fake-only tests cover source-scoped CGNAT bounds, add/readback/auto/
remove preservation, unchanged private/BTH policy, the exact native Tailscale
summon with `ok`/`unknown`, native-editor argv/absence and unknown-owner rejection, and the actual JavaScript response/automatic-change model.
Twelve existing discovery tests pass. No real network manager was opened, no
profile or provider was installed, and no VPN mode changed during these tests.
Desktop owner-launch acceptance and actual offsite transfer remain open.
