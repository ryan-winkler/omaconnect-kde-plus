# Install, update and recover

Omaconnect KDE Plus is a Git-native Omarchy plugin. The root `manifest.json`
declares the case-sensitive ID `Omaconnect.plus`, which also names the IPC target
and the private metadata directories. There is no build step, custom installer,
virtual environment or AUR package.

## Install

1. Install missing prerequisites. Omarchy supplies Quickshell and its UI kit.

   ```bash
   omarchy pkg add kdeconnect python python-gobject
   ```

2. Add and enable the plugin:

   ```bash
   omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
   ```

3. Review the trust and bar placement prompts. Open the new bar icon, select
   **All KDE Connect features** and pair your device in KDE Connect if necessary.

The add command clones the repository and validates its manifest. It does not
run a repository install script. Optional integrations start hidden. Existing
Tailscale, Back to Home, WireGuard and Syncshell tools keep their policy, keys
and profiles; Plus does not install or configure them.

If a firewall blocks discovery, use its owner tool to allow KDE Connect ports
**1714–1764 TCP and UDP** for the intended trusted network. See the
[official troubleshooting guide](https://userbase.kde.org/KDEConnect/en#Troubleshooting).
Plus does not change firewall policy.

## Update, disable and remove

```bash
omarchy plugin update Omaconnect.plus
omarchy plugin disable Omaconnect.plus
omarchy plugin remove Omaconnect.plus
```

Removal uses Omarchy's confirmation flow. It does not remove KDE pairings,
provider configuration or private Plus metadata under
`~/.config/Omaconnect.plus/` and `~/.local/share/Omaconnect.plus/`. Shared-source
cache copies become eligible for cleanup after 24 hours. See the
[icon and storage guide](ICONS.md) for exact paths and backup scope.

## Move from the original OmaConnect

Pairings stay in KDE Connect, so both UIs see the same devices. The helper below
stages display settings for review. It never edits your configuration and has
no apply command. Find the installed plugin folder under
`~/.config/omarchy/plugins/`, change into it, then run:

```bash
python3 scripts/migrate_settings.py prepare \
  --source-id omaconnect \
  --source "$HOME/.config/omarchy/shell.json" \
  --output "$HOME/.local/state/omaconnect-migration-review" \
  --bindings "$HOME/.config/hypr/bindings.conf"
```

Use a new private directory outside the repository for each run. Omit
`--bindings` if that file does not exist, or repeat it for other binding files.
`--source-id` selects the plugin you move from; read the exact `id` from its
installed `manifest.json`.

The output directory (mode 0700) contains:

- `candidate-shell.json`: a private full configuration candidate. Do not publish it.
- `candidate-appearance.json`: only for the source ID `omaconnect`.
  `showDeviceTypeIcons=false` becomes Phone; otherwise the icon follows the device.
- `snapshot.json`: old and new settings, layout slot, source hash and binding
  locations. No pairing or VPN secrets are copied.

Unknown settings, duplicate entries or an existing `Omaconnect.plus` entry need
your review. Legacy Tailscale auto-discovery stays disabled; use the saved-address
controls instead.

To switch:

1. Add Plus without `--enable`, or decline the enable prompt.
2. Disable the original UI: `omarchy plugin disable omaconnect`.
3. Back up `~/.config/omarchy/shell.json`, then replace it with the reviewed
   `candidate-shell.json`. Copy `candidate-appearance.json`, if present, to
   `$XDG_CONFIG_HOME/Omaconnect.plus/appearance.json` (default
   `~/.config/Omaconnect.plus/appearance.json`). Then enable `Omaconnect.plus`.
4. Check the bar, keyboard focus and your devices. Keep the original installed
   until you are satisfied.

## Roll back

```bash
python3 scripts/migrate_settings.py rollback \
  --source "$HOME/.config/omarchy/shell.json" \
  --snapshot "$HOME/.local/state/omaconnect-migration-review/snapshot.json" \
  --output "$HOME/.local/state/omaconnect-rollback-review"
```

This stages a rollback `candidate-shell.json` that restores managed settings only
and keeps later unrelated edits. It refuses changed managed values or a moved
entry; resolve those by review. Review the candidate, replace
`~/.config/omarchy/shell.json` with it, then disable `Omaconnect.plus` and
re-enable the original plugin.
