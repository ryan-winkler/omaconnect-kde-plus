# Install, update and recover

Omaconnect KDE Plus is a Git-native Omarchy plugin. The root `manifest.json`
declares the lowercase machine ID `omaconnect.plus`, which also names the IPC target.
The display name remains Omaconnect KDE Plus. Private metadata keeps the existing
`Omaconnect.plus` directory spelling so older data remains available. There is no build step, custom installer,
virtual environment or AUR package.

## Install

If you already use the uppercase ID from releases through 0.1.2, read
**Former uppercase development ID** before using the fresh-install command.

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
omarchy plugin update omaconnect.plus
omarchy plugin disable omaconnect.plus
omarchy plugin remove omaconnect.plus
```

Removal uses Omarchy's confirmation flow. It does not remove KDE pairings,
provider configuration or private Plus metadata under
`~/.config/Omaconnect.plus/` and `~/.local/share/Omaconnect.plus/`. While installed,
Plus attempts cleanup of eligible shared-file copies in
`$XDG_CACHE_HOME/Omaconnect.plus/` (default `~/.cache/Omaconnect.plus/`) at plugin
start and during later preparation, when the cache is safe. Unexpected files stay. Copies become eligible after 24 hours.
Permissions or the cleanup deadline can leave eligible copies, so 24 hours is not a
maximum retention time. After removal, delete that folder yourself. See the
[icon and storage guide](ICONS.md) for exact paths and backup scope.

## Former uppercase development ID

Releases through 0.1.2 used `Omaconnect.plus`. Community listings require lowercase
IDs. Native update does not rename saved widget/service references or its source
directory. Keep your current installation until you have reviewed an explicit
migration. Private data directories keep their uppercase spelling.

The stage-only procedure below also supports `--source-id Omaconnect.plus`.
For that source it preserves every understood setting and enablement, emits no
appearance file, and leaves original `omaconnect` untouched. Review the exact
source and target directories as well as configuration and bindings before the
one-time switch. Do not install a second active copy or run update-all across
both identities. A source rollback alone does not restore migrated references.

A normally disabled former Plus installation can have no bar or service entry.
For this explicit source ID, the helper adds no missing role or settings and
keeps the new target disabled. It does not reconstruct settings that native
disable already removed.

### If native update already changed the manifest

An uppercase-named checkout can already contain a lowercase manifest after
native update. Check the checkout's manifest before using Add. An installed
lowercase manifest will make Add refuse the duplicate ID.

1. Stop file submissions and close Plus dialogs. Back up shell configuration,
   bindings and the entire current checkout privately, including Git history
   and local changes. Keep the private XDG data folders in place.
2. Move that conflicting checkout out of `~/.config/omarchy/plugins/` into the
   private recovery area. Preserve it; do not delete or edit its manifest to
   hide the conflict. Run `omarchy-shell shell rescanPlugins`, then confirm the
   old checkout no longer registers the lowercase ID. Do not overwrite a
   canonical lowercase checkout that already exists; review that conflict first.
3. If saved references still use `Omaconnect.plus`, continue the staged Add and
   candidate procedure below with that old configuration ID. If references
   already use `omaconnect.plus`, preserve them and their enablement; do not run
   the former-ID helper or remove them to satisfy the ordinary preflight.
   Restore the verified source at the canonical lowercase location instead.
   In this already-configured case, rescan can activate its existing intent even
   without `--enable`; review that intent before adding source.
4. If both identities have saved references, stop and reconcile the two sets.
   Keep all backups and values. Do not guess which settings to overwrite.

A backup whose manifest already uses the lowercase ID is not an uppercase-code
rollback point. Restore a reviewed former release with the correct old manifest
and IPC target before restoring uppercase configuration; do not change only
its manifest ID.

## Move from an existing installation

Pairings stay in KDE Connect, so both UIs see the same devices. The helper below
stages display settings for review. It never edits your configuration and has
no apply command. Choose `omaconnect` for the original UI or `Omaconnect.plus`
for the former Plus ID. Keep a private source backup if you will retire the
former Plus checkout.

Before adding the target, check that shell configuration has no existing
`omaconnect.plus` bar or service entry. Resolve a conflicting or dormant target
before rescan can activate it. Add the new source without enabling it:

```bash
omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --yes
```

With `--yes` and no `--enable`, this only stages the source and rescans. Confirm
it remains disabled. Change into `~/.config/omarchy/plugins/omaconnect.plus/`,
then prepare the candidate below. For the former Plus ID, replace the example's
`--source-id omaconnect` with `--source-id Omaconnect.plus`:

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
`--source-id` selects the old configuration and binding identity. It normally
matches the source manifest. For an already-updated checkout, use the saved
uppercase references when those remain, even if its current manifest is lower.
Do not pass the new target ID as the source.

The output directory (mode 0700) contains:

- `candidate-shell.json`: a private full configuration candidate. Do not publish it.
- `candidate-appearance.json`: only for the source ID `omaconnect`.
  `showDeviceTypeIcons=false` becomes Phone; otherwise the icon follows the device.
- `snapshot.json`: old and new settings, layout slot, source hash and binding
  locations. No pairing or VPN secrets are copied.

Unknown settings, duplicate entries or an existing `omaconnect.plus` entry need
your review. When converting original OmaConnect, legacy Tailscale auto-discovery
stays disabled; use the saved-address controls instead.

`prepare` records binding locations and line hashes; it does not edit bindings.
Before switching, back up each file listed in `snapshot.json` under `bindings`.
Check that each referenced line still has its recorded SHA-256 hash, calculated
from the line text without its newline. If a line moved or changed, run `prepare`
again in a new output directory and review the new candidate before switching.

To switch:

1. Back up `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json`, then replace it with the reviewed
   `$review_dir/candidate-shell.json`. If you changed shell settings after `prepare`, run
   `prepare` again first so the candidate keeps those changes. The candidate
   disables only the chosen source ID and gives `omaconnect.plus` that source’s
   prior state. For `Omaconnect.plus`, original `omaconnect` stays untouched.
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
2. Update each reviewed binding line from its recorded `old_id` command target
   to `omaconnect.plus`. For example, change `omarchy-shell omaconnect toggle`
   to `omarchy-shell omaconnect.plus toggle`. Keep the key, action and other
   arguments unchanged. Do not replace IDs across the whole file. If the line
   changed since review, stop and reconcile that line first. Keep a private
   record of each original and edited line, its file and its hash for rollback.
3. Check the bar, keyboard focus, exact settings, enablement and devices. Do not
   use a generic enable command for a previously disabled installation.
4. If the source was uppercase Plus, confirm it has no enabled references,
   archive its source privately, then run `omarchy plugin remove Omaconnect.plus`.
   This removes the retired source checkout; private XDG data stays in place.
   The new lowercase directory supports normal lowercase update/remove commands.
   Keep original `omaconnect` installed if you use it beside Plus.

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

If the former source was removed, restore its privately archived checkout to
its original source directory before applying the rollback candidate. Verify
that its manifest ID matches `old_id` in the snapshot and that its code is the
recorded former release. Do not overwrite another checkout or restore an
already-updated lowercase manifest as uppercase code. Run
`omarchy-shell shell rescanPlugins` and confirm the former source is registered.
The configuration switch must not point to an absent or mismatched plugin.
Original OmaConnect needs no source restore if it remained installed.

This stages a rollback `candidate-shell.json` that restores managed settings only
and keeps later unrelated edits. It refuses changed managed values, moved or
extra target references, or a reappeared old-source reference; resolve those by
review. Review the candidate and back up the current
shell configuration. If shell settings changed after staging, rerun `rollback`
into a new output directory before applying the candidate. The new `$rollback_dir/candidate-shell.json` already restores the original bar
slot and enabled state. Replacing
`${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json` with that candidate restores the reviewed state.
Then disable `omaconnect.plus` if it remains enabled as an installed plugin; the
original stays enabled only if it was enabled before the move.

The rollback helper does not restore bindings. Use your private before/after
record to reverse only the command-target edits you made, such as
`omarchy-shell omaconnect.plus toggle` back to `omarchy-shell omaconnect toggle`.
First verify that the current line and hash still match your edited version.
If they differ, reconcile that line by review. Preserve all unrelated later
changes; do not restore a whole binding file or replace IDs globally.

After rollback, keep the recovered uppercase source at its reviewed revision.
Do not run update-all across the recovered and replacement identities: another
native update can change the recovered manifest without renaming references.
Once recovery is verified, remove any unused replacement source through native
Omarchy controls, keeping private data and original OmaConnect intact. Use the
explicit migration when moving to the current lowercase release again.
