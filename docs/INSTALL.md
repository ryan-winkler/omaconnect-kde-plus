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
   **Native KDE Connect settings** and pair your device in KDE Connect if necessary.

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
`${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/`, change into it, then run:

```bash
review_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omaconnect-migration-review"
python3 scripts/migrate_settings.py prepare \
  --source-id omaconnect \
  --source "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" \
  --output "$review_dir" \
  --bindings "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"
```

Use a new private directory outside the repository for each run. Set `review_dir`
to that exact `--output` path and use it for every artifact below. If you rerun
`prepare`, update `review_dir` first; never combine artifacts from different runs.
In a new terminal, set it to your chosen prepare directory again. Omit
`--bindings` if that file does not exist, or repeat it for other binding files.
Older configurations can use `bindings.conf`; pass the file your setup uses.
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

`prepare` records binding locations and line hashes; it does not edit bindings.
Before switching, back up each file listed in `snapshot.json` under `bindings`.
Check that each referenced line still has its recorded SHA-256 hash, calculated
from the line text without its newline. If a line moved or changed, run `prepare`
again in a new output directory and review the new candidate before switching.

To switch:

1. Add Plus without `--enable`, or decline the enable prompt.
2. Back up `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json`, then replace it with the reviewed
   `$review_dir/candidate-shell.json`. If you changed shell settings after `prepare`, run
   `prepare` again first so the candidate keeps those changes. The candidate
   disables `omaconnect` and gives `Omaconnect.plus` the state the original had.
   If `candidate-appearance.json` is present, create the destination with private
   permissions and copy it without replacing any existing appearance file:

   ```bash
   : "${review_dir:?Set review_dir to the chosen prepare output directory}"
   appearance_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Omaconnect.plus"
   install -d -m 700 "$appearance_dir"
   cp -n --preserve=mode "$review_dir/candidate-appearance.json" "$appearance_dir/appearance.json"
   ```

   An existing appearance file needs manual review; keep it until you have merged
   the intended display choices. Do not replace it with an older candidate.
3. Update each reviewed binding line from its recorded `old_id` command target
   to `Omaconnect.plus`. For example, change `omarchy-shell omaconnect toggle`
   to `omarchy-shell Omaconnect.plus toggle`. Keep the key, action and other
   arguments unchanged. Do not replace IDs across the whole file. If the line
   changed since review, stop and reconcile that line first. Keep a private
   record of each original and edited line, its file and its hash for rollback.
4. Check the bar, keyboard focus and your devices. Keep the original installed
   until you are satisfied.

## Roll back

Keep `review_dir` set to the prepare directory that was applied. Choose a fresh
`rollback_dir` for each rollback candidate.

```bash
: "${review_dir:?Set review_dir to the applied prepare output directory}"
rollback_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omaconnect-rollback-review"
python3 scripts/migrate_settings.py rollback \
  --source "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json" \
  --snapshot "$review_dir/snapshot.json" \
  --output "$rollback_dir"
```

This stages a rollback `candidate-shell.json` that restores managed settings only
and keeps later unrelated edits. It refuses changed managed values or a moved
entry; resolve those by review. Review the candidate and back up the current
shell configuration. If shell settings changed after staging, rerun `rollback`
into a new output directory before applying the candidate. The new `$rollback_dir/candidate-shell.json` already restores the original bar
slot and enabled state. Replacing
`${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json` with that candidate restores the reviewed state.
Then disable `Omaconnect.plus` if it remains enabled as an installed plugin; the
original stays enabled only if it was enabled before the move.

The rollback helper does not restore bindings. Use your private before/after
record to reverse only the command-target edits you made, such as
`omarchy-shell Omaconnect.plus toggle` back to `omarchy-shell omaconnect toggle`.
First verify that the current line and hash still match your edited version.
If they differ, reconcile that line by review. Preserve all unrelated later
changes; do not restore a whole binding file or replace IDs globally.
