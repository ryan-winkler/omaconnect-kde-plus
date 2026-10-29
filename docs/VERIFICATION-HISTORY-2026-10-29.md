# Historical verification snapshots

Identity note: this report describes the previous development identity. It does not establish runtime or migration acceptance for the current `Omaconnect.plus` ID. See [current verification](VERIFICATION.md).

These are dated development receipts. They do not describe current installation
or release state. See [current verification](VERIFICATION.md).

# Candidate verification — 29 October 2026

## Current dedicated Settings / drop / comparison follow-up

**155 Python tests and all three JS suites pass.** The native Settings window,
provider preferences, searchable feature view, persistent Send window, drop review
and Ring readiness guard are integrated. See the settings review and new SP01–SP50
RICE audit. The earlier counts below are dated snapshots. Live comparison
installation is explicitly authorized on both computers, with original retained.


## Current icon, native-feature and network follow-up

**141 Python tests and all three JavaScript suites pass.** Shell syntax and the
installed Omarchy manifest validator pass. QML lint succeeds with known host/
unqualified-access diagnostics; it is not warning-free. Actual native QML loads
both new components without TypeError/ReferenceError in the isolated fixtures.

- Appearance: 13 checks, including distinct rendered preset fallbacks, visible
  choices, saved drafts, operation-error priority and late-import invalidation.
- Native feature boundary: four checks cover full/third-party IDs, optional loaded
  state, sender/receiver directions and strict selected-device launcher arguments.
- Network coverage: seven checks cover Tailscale source-scoped CGNAT, add/readback/
  auto/remove, fixed native-owner routes, unavailable owners and unchanged policy.
- Keyboard: actual Qt key-event fixture now passes **29 assertions**, including
  native feature entry/details, Tailscale/WireGuard owner-button focus, BTH,
  addresses and Syncthing. Owner buttons are focused, not launched.
- Intended desktop **the intended desktop, x86_64**: updated candidate passes **32 native
  assertions** with the actual installed KeyboardPanel and current Wayland socket.
  All providers/actions/state are private fakes. Seven protected installed files
  retain their hashes. The standard plugin remains active; no fork activation.
  Nonfatal sandbox Wayland text-input warnings were observed. This does not prove
  live pointer/focus or assistive-technology acceptance.

The separate review found one launch-success wording issue, now corrected to
“launch requested”; no blocking finding remains. Exactly 50 unique synthetic
persona scenarios were checked. Claude and Antigravity each completed independent
initial and scope-addendum reviews; recommendations were source-checked, with
incorrect loaded/disabled and glyph claims rejected. See the decision ledger.

New native owner launches, real pointer/AT, scale/RTL and away-network transfers
remain untested. The earlier owner-confirmed phone payload below is valid evidence
for that payload only. No real send was repeated during this follow-up. Logs and
machine-readable receipts are in the adjacent desktop-validation and
ux-contribution-audit delivery folders. The committed source stays isolated.

## Earlier first-release receipt

Local full-run result: **124 Python tests passed**, all three JavaScript suites
passed (including 18 BTH/discovery checks), manifest validation and shell syntax
passed. Quickshell 0.3.2 ran the native fixtures. QML lint returned success with
host-import/type diagnostics; this is not a warning-free lint claim. The native
integration fixture passed 31 runtime assertions without TypeError/ReferenceError.
Seven protected installed source/config/helper files retained their starting
hashes. This result applies to the isolated ARM candidate and synthetic providers.

Status: first-release implementation candidate. No installed activation, real
transfer, VPN-mode change or router/UniFi change is part of this receipt.

## Runnable evidence

`./scripts/validate.sh` runs all Python tests, the actual JS model checks, shell
syntax, the installed Omarchy manifest validator and QML lint when available.
The runner uses a temporary HOME/XDG/runtime, no host display and a private session
bus. Optional native prerequisites cause explicit skips; inspect the final test
summary before making a claim. CI runs this same command and has no native Omarchy
runtime by default.

Focused suites cover:

- Portal multiselect/cancel over private D-Bus, inspected real temporary regular
  files and unsupported/folder/FIFO/changed/oversized sources.
- Actual transfer JS/controller functions and fake CLI accepted, failed,
  ambiguous timeout and after-invocation cancellation outcomes.
- Appearance storage, stable identity, alias validation, concurrent writes,
  corrupt-state preservation, image import/rejection and Syncthing link metadata.
- BTH strict status, fixed commands, unsafe/unknown/missing cases, intent versus
  actual state and helper-path drift.
- Private address validation, baseline preservation, merge/readback conflicts,
  four concurrent writers, real busctl against private fake KDE and native
  queue/close-disable behavior with owned helpers.
- Native/replacement-bar/tray migration, icon semantics, private staging and rollback
  conflicts that preserve unrelated later edits.
- Native QML component/control integration: actual Service, BarWidget, Panel,
  facade bridge, tabs, chooser Apply/Cancel/reload, aliases, portal review,
  explicit Send, fixed recipient, sequential requests, delivery-unknown activity,
  cancellation and unconfirmed owner-panel opening. See [native QA details](../tests/NATIVE-QA.md).

## Platform limitation

Qt offscreen has no native Quickshell PanelWindow backend. The integration fixture
substitutes only the KeyboardPanel hosting boundary. Actual product components and
UI logic run unchanged in that fixture. It asserts no TypeError/ReferenceError or
configuration-load error. It is not a mapped desktop screenshot or an end-to-end
keyboard/assistive-technology test.

A separate CPU-only headless Hyprland attempt could not start a Wayland socket.
The isolated compositor reported backend creation failure; a mandatory-headless
Aquamarine probe reported no allocator. No host display/GPU or installed settings
were used to bypass this limit.

## Open acceptance gates

| Gate | Status |
| --- | --- |
| ARM native helper/model/UI logic fixtures | Run by the documented local validation command |
| Genuine PanelWindow mapping and compositor focus | Blocked by isolated compositor prerequisite |
| Native and replacement-bar activation | Not run; installed desktop preserved |
| x86_64 native UI | Not run |
| Linux/Android physical payload and zero-byte delivery | Not run |
| Offsite BTH and phone-away / desktop-LAN pairing | Not run |
| Scale 2, RTL, reduced motion and assistive technology | Not accepted; basic names/plain text/focus controls implemented |
| Release publication | Not performed |

A successful CLI request does not close the delivery gate. A successful helper
status does not prove a VPN handshake, service reachability or fleet acceptance.

## Current desktop session — 29 October 2026

The owner subsequently authorized validation on this desktop. Live identity is
asahi-omarchy/aarch64. The explicit desktop test uses the current Wayland socket,
the original native KeyboardPanel and existing GPU renderer with private sample
providers. It passes 32 runtime assertions and opens the genuine PanelWindow.
The former offscreen backend limit therefore no longer blocks this host's native
window smoke test. Installed-bar activation, manual focus/AT/scaling and physical
payload acceptance remain separate. No installation or BTH transition ran.

Read-only provider preflight: existing BTH status is valid, Automatic/inactive,
with no pending error (normal HOME metadata). KDE daemon/CLI and portal FileChooser
v4 respond. Syncshell is installed with one observed core. At preflight there were
zero paired/reachable KDE recipients; the owner chose their phone for a subsequent
real transfer check. Test submission acknowledgement alone is not delivery proof.

### Intended desktop and real phone check

The owner clarified that the intended x86_64 desktop, paired with the owner-selected phone, was the intended
desktop. The existing pinned `desktop` SSH connection verified Kintsugi/x86_64.
A private source staging directory on that host passed all 124 Python tests, all
three JS suites, the installed manifest validator and shell syntax. Its explicit
Wayland test passed 32 assertions using the original native KeyboardPanel and GPU.
Standard OmaConnect remained installed and connected; its seven protected
source/config/helper files retained their starting hashes.

The fork's actual one-shot submission helper sent a generated 109-byte text file
to the explicitly selected, paired and reachable the owner-selected phone. The helper reported
request_accepted. The owner then confirmed reception, opening and the matching
unique check code. This establishes one real text payload on this LAN; it does
not establish every file type, zero-byte/multifile delivery, cancellation or away
reachability. No second live candidate UI watcher or protocol daemon was started.

BTH's direct SSH status reported not-preauthorized. The same read-only command
through the existing native user-session manager reported nm_control=true,
Automatic/inactive, no pending state and no error. This was an SSH authorization
context limit. No policy/profile/VPN-mode change was needed or performed.

The candidate is still staged separately. Installed bar replacement, actual
keyboard/pointer/AT interaction and offsite validation remain open.
