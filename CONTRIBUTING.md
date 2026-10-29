# Contribute to OmaConnect Plus

**Start with one small change.** Keep it in the domain that owns the behavior.
KDE Connect owns protocol and pairing. The existing BTH helper owns VPN policy.
Syncshell owns synchronization and its keys.

| I want to… | Start here | Check |
| --- | --- | --- |
| Add or improve an icon | [Icon sources and storage](docs/ICONS.md), `Appearance.js`, `components/AppearanceIcon.qml` | Preset parity and appearance/native fixtures |
| Change the chooser | `components/IconChooser.qml` | Visible choices, keyboard, Apply/Cancel and missing-icon behavior |
| Change aliases or local ID links | `AppearanceStore.qml`, `scripts/appearance.py` | Stable ID, private atomic state, corrupt-state preservation |
| Change sharing | `KdeConnectController.qml`, `TransferModel.js`, `scripts/portal_files.py` | Fixed recipient, explicit send, unknown delivery and cancellation |
| Change address discovery | `DiscoveryController.qml`, `DiscoveryModel.js`, `scripts/manage_addresses.py` | Approval, baseline preservation, bounds and opt-in stop |
| Change the home-access card | `BthControlCard.qml`, `BthControlModel.js` | Existing helper contract and intent versus actual state |
| Add another provider | [Domain and facade map](docs/2026-10-29-contribution-architecture.md) | Own adapter; do not add a generic plugin loader |

## First useful loop

1. Read `AGENTS.md` and the owning file above.
2. Add a small failing behavior check for the defect or boundary.
3. Make the smallest complete change. Keep entry points and public paths stable.
4. Run `./scripts/validate.sh`. Native prerequisites and skips must be explicit.
5. Describe the changed behavior, evidence and remaining device/UI checks in the PR.

The normal test command uses fake providers and private temporary state. The
explicit desktop-mode test needs owner authorization for that desktop session;
it is not an automatic CI step. See [native QA](tests/NATIVE-QA.md).
Do not install the candidate, restart the shell, change VPN modes, pair devices,
access router/phone state or send a real file as an automated test.

## Keep the contribution reviewable

- One behavior or one extraction per change. Avoid unrelated directory moves.
- Keep aliases, icons and address hints separate from identity and pairing trust.
- Keep all remote names and user text plain. State must also have words, not color alone.
- Reuse native Omarchy UI controls where their contract fits. Add no dependency
  for an existing platform feature.
- Add no credentials, copied user state, imported images or private receipts.
- Record the source/license for new assets. Font glyph references do not vendor fonts.
- Update the owning contract/document with code. Do not claim delivery from CLI exit 0.

A feature becomes easier to extend through clear ownership and tested boundaries.
A second provider is the point to review a transfer-controller extraction. Five
preset choices do not need an internal plugin framework, factory or generator.

Native KDE plugins belong to KDE Connect's package/daemon. Use the native feature
route and inventory; do not add a second plugin loader. Network providers retain
their own policy and keys. See the [product addendum](docs/2026-10-29-product-addendum.md)
for Tailscale/BTH/WireGuard coverage and the boundary between approval and control.

| Additional task | Owner | Focused check |
| --- | --- | --- |
| Native feature metadata / app handoff | `scripts/discover_devices.sh`, `KdeConnectController.qml`, `components/NativeFeaturesSection.qml`, `scripts/open_app.sh` | `python3 -m unittest tests/test_native_features.py -q` |
| Tailscale / BTH / WireGuard guidance and approved address sources | `components/NetworkOptions.qml`, `scripts/open_network_owner.py`, existing discovery domain | `python3 -m unittest tests/test_network_coverage.py -q` |
| Ordinary keyboard routes | `Panel.qml`, native controls | `python3 -m unittest discover -s tests -p test_keyboard.py -q` |
