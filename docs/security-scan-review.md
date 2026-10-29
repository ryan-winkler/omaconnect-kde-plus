# Codex Security Standard source review

Date: 29 October 2026. This is the installed Codex Security **Standard** scan,
not the separate CSO review, CodeQL run, outside opinion or native QA result.
The scan completed. Its source coverage remains **partial**. Completion is not
a clean result or security certification.

## Bound snapshot

- Scan ID: `d5a6aec5-1934-4228-9c45-bbbfcae9828c`.
- Base revision: `b6860b9d4265ce05987963a0bc4318b3da956faa`, plus the current
  uncommitted 0.1.1 candidate at scan start.
- Snapshot digest: `codex-security-snapshot/v1:sha256:f0735a90f2c223f3309187ca17a845a66b51963d81825a29e44d1d34275509e0`.
- Technical identity in that snapshot: `Omaconnect.plus`.

The completion tool warned: **“Working-tree contents changed while the scan was
running; results were saved for the original snapshot.”** The report belongs to
that original snapshot. Later source fixes need separate evidence. This summary
was added after sealing and is not part of the assessed snapshot.

The tool generated and sealed `scan-manifest.json`, `findings.json`,
`coverage.json`, `threatmodel.md`, `report.md` and SARIF in private local scan
storage. They are not copied into the repository. Scan usage was unavailable;
the tool reported `scan_thread_unavailable`.

## Findings at the scanned snapshot

| Finding | Severity / confidence | Source and prerequisite | Required correction |
| --- | --- | --- | --- |
| Activity renders a peer name with automatic rich-text detection | Low / high | `components/ActivitySection.qml`, Activity delegate. The peer name reaches `Text.text` through a reviewed operation without `Text.PlainText`. A visible/paired peer, user submission and Activity row are required. | Force plain text. Verify the real component with an owned image-tag URL, zero requests and no URL/token logging. |
| File identity is lost before the native path reopen | Low / medium | `scripts/portal_files.py`, inspection and submission. The validated descriptor closes before the original pathname reaches KDE. A separate local writer must control the selected file or its directory. Disclosure also needs an attacker-accessible selected recipient and native backend behavior that follows the replacement. | Use a validated descriptor-backed private snapshot for unsafe/shared sources, or a verified native descriptor contract. Specify bounds, retention and cleanup. Another pathname check alone does not close the race. |

These are source-backed findings. This scan executed no project code, exploit,
native provider or real transfer. The parent task separately reported a controlled
probe of the real Activity component: one loopback image request, with no observed
URL/token logging in that Text 404 case. That observation is not a runtime action
performed by this Standard scan. The native KDE file-open behavior remains an
explicit proof gap; no private-file exfiltration was reproduced.

The inherited predictable `/tmp/gdbus_set_test.log` append in `tests/test_state.py`
is also a contributor-isolation hardening item. Cross-user symlink impact depends
on host `protected_symlinks` behavior, which this scan did not inspect. Use the
test's existing private temporary directory. This is not asserted as a current
host exploit or a product-runtime vulnerability.

## Coverage and limits

The reviewer fully read **126 of 141** repository files: all product QML,
JavaScript, helper scripts, tests, CI configuration and primary user/contributor
contracts. The source-wide credential-pattern search found generated nonces and
explicit dummy sentinels in its reviewed hits. It found no supported embedded
credential exposure. Pattern matching alone does not establish complete coverage.

At the parent's explicit source-release bound, these files remained **not fully
assessed**:

- `preview.png`, `preview1.png`, `upstream-preview.png`.
- `docs/2026-10-29-contribution-architecture.md`.
- `docs/2026-10-29-persona-audit.md`.
- `docs/2026-10-29-ux-decision.md`.
- `docs/icon-audit.md`.
- `docs/2026-10-29-ux-response-review.md`.
- `docs/2026-10-29-product-addendum.md`.
- `docs/2026-10-29-ring-investigation.md`.
- `docs/2026-10-29-settings-rice-personas.md`.
- `docs/2026-10-29-settings-review.md`.
- `docs/release-outside-voices.md`.
- `docs/release-personas-red-blue.md`.
- `docs/contributor-release-plan.md`.

External KDE, Qt and Omarchy implementations, installed configuration, credentials,
router/phone state and native provider behavior were outside this source scope.
No test suite, external scanner or application ran in this workflow. The separate
parent QA results retain their own commands and evidence boundaries.

The available four-worker team was occupied. The installed skill's sequential
fallback was used; no fresh independent nested baseline or architecture worker is
claimed. Local preflight was ready, with a nonblocking unknown six-slot advisory.
The fresh Daybreak advisory returned `not_granted` with no programs; it did not
prevent the local scan. No restricted cloud scan was used.

## Remediation handoff

The parent owns source fixes and fresh focused regressions. Keep this original
result intact. Record the exact fixed revision, affected findings, positive and
negative controls, cleanup/retention behavior and remaining native checks in a
separate follow-up. Do not use the earlier media-art repair, fixture pass or scan
completion as evidence that these newly reported paths are closed.

## Later remediation evidence

The original findings above remain the record of the scanned snapshot. Later
source changes force plain text in Activity and introduce descriptor-backed
private snapshots for shared mutable sources. The real Activity probe is green;
the actual-submit/fake-backend source-replacement probe reads the reviewed bytes,
while its raw-path negative control reads the sentinel. Fourteen focused snapshot
unit tests and seven transfer tests pass at integration. The inherited test log
uses its private temporary directory. These are targeted remediation results,
not a new canonical full scan or a claim about real KDE exploit behavior.

See [privacy review and remaining limits](security-privacy-review.md) and
[preparation, storage and cleanup contract](CONTRACTS.md#file-chooser-and-submission).
