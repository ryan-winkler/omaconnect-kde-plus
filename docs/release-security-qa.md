# Release helper security and functional QA

Identity note: this report describes the previous development identity. It does not establish runtime or migration acceptance for the current `Omaconnect.plus` ID. See [current verification](VERIFICATION.md).

Date: 2026-10-29. Scope: the working release candidate based on `f8b3e11`,
including the fixes below. This is a source review and private fixture check.
It is not a claim that every device, desktop session or attack path is tested.

## Result

Three verified release defects are fixed. The complete isolated validation
command passes **163 Python tests**, the JavaScript checks, shell syntax checks,
the available Omarchy manifest validator and the QML error check. QML lint still
reports host import and unqualified type warnings. Offscreen native fixture
loads pass; this does not establish a warning-free desktop session.

No installed plugin, personal shell configuration, VPN profile, firewall rule,
pairing or remote device changed during this review. All process and file attack
fixtures used owned temporary state. No real send or Ring action ran.

## Reproduced defects and fixes

| Defect | Red fixture | Fix and green evidence |
| --- | --- | --- |
| Native migration rejected the actual inline Registry settings and emitted settings under an unused nested key. Legacy action flags would also lose their meaning in the new action catalog. | Native inline entry with `showDeviceTypeIcons: false`, `showTailscale: false` and action flags. Previously, preparation refused the entry. | Accept native inline, legacy nested and string entries. Emit native inline settings. Convert legacy action flags to an explicit `quickActionsOrder`. Reject mixed shapes and unknown keys. Exact round trips preserve source shape and disabled flag order. |
| A FIFO named `addresses.json` blocked before the regular-file check. | Owned mode-0600 FIFO, with no writer. The old reader exceeded a one-second subprocess deadline. | Open metadata with `O_NONBLOCK`, `O_NOFOLLOW` and `O_CLOEXEC`, then check the opened file. The fixture now returns `metadata-invalid` without waiting for a writer. |
| A timed-out discovery/provider wrapper left its child running. | Owned wrapper starts a 30-second child that holds stdout open. The old helper killed the wrapper and left the child alive. | On an incomplete command, kill the session's process group and wait for the wrapper. The regression checks the child is no longer running, then adopts and reaps the owned child. |

The migration receipt records source and target shape. Rollback accepts earlier
staged nested receipts, restores the original entry shape and keeps later
unrelated settings. It refuses changed managed values or ambiguous configuration
surfaces. Migration remains **staged only**; these tests did not activate a
candidate or copy settings into a user's shell configuration.

## Reviewed boundaries

| Boundary | Evidence and contract |
| --- | --- |
| File chooser and drop input | `portal_files.py` accepts bounded batches of local file URIs. It rejects remote hosts, folders, final symlinks and nonregular files. File identity, size and timestamps are checked again before submission. Existing transfer/drop fixtures exercise these branches and the actual QML staging path. |
| KDE submission | Fixed argument arrays call the existing CLI. Request acceptance, failure, timeout and cancellation remain distinct. A zero exit does not prove delivery. Existing fixtures test these results without a real recipient. |
| Appearance and imports | The helper validates private metadata, aliases and identifiers. Image limits and SVG element/reference rules reject active/external content, animations, malformed images and reference cycles. Existing private-state fixtures also cover corrupt state, symlinks and concurrent updates. |
| Preferences and owner links | The preference helper accepts exact key/value shapes and used the fixed previous development ID at this snapshot. It sends JSON values as arguments. Owner links open existing provider interfaces. Fixtures cover invalid values, saved-state readback, failed confirmation and original/fork isolation. |
| Addresses and rediscovery | Private literal addresses need explicit approval. Existing fixtures cover batch reconciliation, baseline ownership, stale external state, bounded provider replies and concurrent writers. The two process/metadata regressions above close reproduced gaps. |
| Native feature identifiers | Reported plugin metadata remains data. The feature list can retain unknown plugin IDs; it does not construct executable plugin commands from them. The device settings launcher validates device IDs and uses fixed arguments. Native feature fixtures exercise unknown IDs and older frontend fallback. |
| BTH/controller boundary | Existing fixed mode commands, strict status parsing and unavailable/error states remain in the controller contract. JavaScript fixtures cover mode and readback decisions. No real mode command was issued in this review. |

## Verification

Commands run from the repository root:

```sh
python3 -m unittest tests/test_release_migration.py tests/test_migration.py tests/test_release_security.py -q
./scripts/validate.sh
```

The focused run passes 15 tests. The full run passes 163 Python tests in about
22 seconds. It uses a temporary HOME, XDG directories, private D-Bus session,
software/offscreen Qt, and fake provider mutations. JavaScript appearance,
transfer, BTH and rediscovery checks also pass. Do not interpret these fixture
results as a real network, recipient, audio, portal-desktop or assistive
technology acceptance check.

## Limits and remaining acceptance

- The KDE CLI takes a path and opens it later. The pre-submit identity check
  reduces stale selection risk, but cannot provide an atomic file descriptor
  handoff. A same-user process can replace a path after that check. Do not claim
  that this race is eliminated.
- A helper process can clean up its owned process group. This is not a sandbox
  against a malicious replacement executable that deliberately creates a new
  session. Installed provider binaries remain part of the user's trust boundary.
- Private bus and offscreen Qt fixtures verify function and state contracts.
  Real desktop drag/drop, the user's portal, device permissions, Ring audio,
  provider connectivity and recipient confirmation still need native acceptance.
- No penetration test against a remote device, fuzz campaign, screen-reader
  evaluation or fleet-wide compatibility claim is included in this report.
