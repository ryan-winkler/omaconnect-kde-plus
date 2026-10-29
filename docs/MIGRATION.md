# Staging, activation and recovery

The original `omaconnect` and the fork `Omaconnect.plus` have separate UI identities.
The ID is case-sensitive and also names the IPC target and private metadata directories. This guide covers moving from the original plugin.

KDE pairing data and VPN profiles remain with their existing owners. Development
comparison used an earlier development ID on ARM and x86_64; acceptance for `Omaconnect.plus` requires its own receipt. Normal migration should leave one
daily UI enabled. This guide stages settings changes for review. It never applies them.

## Select the source identity

Use `--source-id omaconnect` (the default) when moving from Jitendra's original plugin. For another source plugin, read its `id` from that installed copy's `manifest.json` and pass that exact value as `--source-id SOURCE_ID`; do not infer it from a display name. This option selects the existing source, never the target.

## Prepare an offline candidate

Use a **new private directory outside the repository** for each run. The tool
never edits the source or talks to a running shell. The example below moves from the original plugin.

```bash
python3 scripts/migrate_settings.py prepare \
  --source-id omaconnect \
  --source "$HOME/.config/omarchy/shell.json" \
  --output "$HOME/.local/state/omaconnect-migration-review" \
  --bindings "$HOME/.config/hypr/bindings.conf"
```

Omit `--bindings` if that file does not exist. Repeat it for other known binding
files. Binding receipts contain file/line/hash/count only. They do not change
shortcuts; review bindings that target the selected source ID separately. The new target is `Omaconnect.plus`.

The new directory uses mode 0700 and its JSON files use mode 0600:

- `candidate-shell.json`: a private full configuration candidate. Do not commit
  or publish it. Unrelated fields remain in this private copy.
- `candidate-appearance.json`: emitted only for the original upstream source ID `omaconnect`. An explicit legacy `showDeviceTypeIcons=false` becomes Phone; true or the upstream default becomes automatic. For any other source ID, the helper returns no inferred appearance and emits no candidate appearance file. A fresh installation defaults to Phone.
- `snapshot.json`: understood old/new settings, exact layout slot, disabled flags,
  source hash and binding provenance. No pairing or VPN secrets are copied.

Unknown source settings, duplicate locations and an existing fork entry require
review. Native and replacement-bar layouts use the same supported `bar.layout` schema,
including tray. The legacy Tailscale discovery list and automatic setup remain
disabled. Current network guidance and saved-address approval cover Tailscale,
BTH and WireGuard. They do not reinstall or connect a provider. Saved-address
controls default to no automatic rediscovery.

## Review private metadata

The staging helper prepares shell settings and appearance metadata; do not assume it moves every private file. The original plugin has no Plus `appearance.json`, imported `icons/` or `addresses.json`. Their locations are documented in the [icon/storage guide](ICONS.md). Preserve file ownership, private modes and the original copies until readback is confirmed. Do not copy pairing databases, provider keys or unrelated configuration. Refuse existing conflicting target metadata instead of overwriting it.

## Activate after review

Activation is an explicit action after review. Do not overwrite an active
shell's configuration with a stale candidate. Confirm the source hash, preserve
the original plugin revision, and coordinate with any chat that owns shell tests.
Use supported `omarchy plugin` commands and user configuration only. Never edit
`/usr/share/omarchy` or copy daemon identities, VPN keys or API keys.

1. Stage the reviewed fork revision in user plugin storage, disabled. The native
   `omarchy plugin add` flow supports adding without `--enable`. In an interactive
   terminal, decline its enable prompt to keep the plugin disabled. Inspect the local
   command before use. Do not assume the remote default branch contains this
   candidate branch.
2. Validate the staged manifest. Confirm optional providers fail safely.
3. Stop the source identity's UI watcher before enabling the new fork. Preserve its exact
   layout position, and use a coordinated supported shell restart when changed
   QML needs reload. Use both UIs only for an explicit comparison, then choose one daily UI.
4. Apply only the reviewed display settings and appearance metadata. Recheck the
   source hash before any atomic configuration replacement. The staging helper
   deliberately has **no apply/activation command**.
5. Verify the actual mapped view, keyboard focus, original KDE identities and
   provider states on the intended host. Keep the old source available.

## Prepare rollback without discarding later edits

```bash
python3 scripts/migrate_settings.py rollback \
  --source "$HOME/.config/omarchy/shell.json" \
  --snapshot "$HOME/.local/state/omaconnect-migration-review/snapshot.json" \
  --output "$HOME/.local/state/omaconnect-rollback-review"
```

This stages a new candidate. It restores managed IDs/settings and disabled flags
only. It preserves later unrelated fields and settings. It refuses changed managed
values, a moved/replaced managed entry or incompatible source state. Resolve those
conflicts by review; do not force a full old snapshot over new configuration.

Restoring source/plugin activation remains a supported, coordinated owner action.
KDE pairing and transfer history, VPN profiles, Syncshell and the original local
plugin source are never part of the staging tool's write set.
