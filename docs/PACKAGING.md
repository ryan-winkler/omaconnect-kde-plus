# Native Omarchy packaging and installation

**Install this as an Omarchy plugin from its Git repository.** The root `manifest.json` declares the case-sensitive ID `Omaconnect.plus`, version and service/bar entry points. The QML, JavaScript, helper scripts and documentation stay in the same checkout. There is no build artifact or custom installer to run.

## New installation

1. Use an existing supported Omarchy shell and working desktop file portal. Omarchy supplies Quickshell and the UI kit. Install missing prerequisites with:

   ```bash
   omarchy pkg add kdeconnect python python-gobject
   ```

2. Add and enable the plugin with one native command:

   ```bash
   omarchy plugin add https://github.com/ryan-winkler/omaconnect-kde-plus.git --enable
   ```

3. Review the native trust/placement prompts. Open the new bar icon, choose **All KDE Connect features** and pair in KDE Connect if necessary. Use **Settings** to choose appearance, quick actions and optional connections. Optional integrations start hidden.

The native add command clones the repository, validates its root manifest and registers its declared entry points. It does not run a repository install hook. No Python virtual environment, AUR package, dependency downloader or extra protocol daemon is required. Node is a contributor test prerequisite, not a runtime package.

Optional services remain optional. Existing Tailscale, BTH/WireGuard and Syncshell tools retain policy, profiles, keys and pairing. Plus does not install or configure those providers. Missing providers have an unavailable result rather than an automatic setup action.


If a firewall blocks discovery, use its owner tool to allow KDE Connect ports
**1714–1764 TCP and UDP** for the intended trusted network. Read the
[official troubleshooting guide](https://userbase.kde.org/KDEConnect/en#Troubleshooting).
Plus does not change firewall policy.

## Existing installation

If `Omaconnect.plus` is already registered:

```bash
omarchy plugin update Omaconnect.plus
```

If an earlier fork identity or the original `omaconnect` is registered, follow [migration and recovery](MIGRATION.md) first. A Git update alone does not rename registry entries, IPC targets or metadata directories. Stage settings with the exact source ID; inspect the candidate before activation. For earlier Plus identities, existing private appearance/assets/address records need separate copy and validation; the helper does not infer replacement appearance.

## Disable, remove and recover

Use the command for the intended action:

```bash
omarchy plugin disable Omaconnect.plus
omarchy plugin remove Omaconnect.plus
```

Removal uses Omarchy's confirmation flow. It removes or backs up plugin source according to the native command; it does not remove KDE pairings, provider configuration or private metadata. See [exact metadata paths](ICONS.md). Re-enable the recorded source plugin ID for rollback if it is still installed; inspect staged rollback settings rather than applying a stale full configuration.

## Maintainer package check

Keep the root manifest, fixed entry points and installed relative paths intact. Run the real Omarchy manifest validator when available, with the existing functional runner. An unavailable native validator is a skip, not a pass. Use a reviewed source revision and current [verification receipts](VERIFICATION.md) for publication. Do not claim a new-ID installation passed because a historical identity worked.
