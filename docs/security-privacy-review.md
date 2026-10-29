# Security and privacy boundary review

Date: 2026-10-29. This is a finite manual source review with private native
fixtures. It is separate from the trusted CSO workflow and its proof labels.
It is not a universal security or privacy certificate.

## Assessed scope and actors

Reviewed paths include media metadata, native text controls, subprocess arguments,
file selection/drop and submission, appearance imports/private state, saved
addresses/rediscovery, provider owner links, operation summaries, shell logs,
repository review configuration and hosted workflow permissions.

Relevant actors are the local user, installed plugin/provider code, paired device
metadata and contributors who can propose repository changes. Plus runs in the
user's unsandboxed shell session. Installation therefore trusts the plugin with
that session's authority. A marketplace capability declaration is not an
enforcement sandbox and is not itself an application vulnerability.

## Supported finding

| ID | Priority and confidence | Boundary and trigger | Impact | Disposition |
| --- | --- | --- | --- | --- |
| PRIV-01 | P2; high confidence in the Plus sink, packet-level attacker control untested | Media helper/controller could publish an artwork URI. Both `Image` consumers in `MediaPlayerSection.qml` used it directly, including when the card was collapsed. | Implicit HTTP request from the desktop. A failed image load also placed the complete URL and synthetic query token in Qt shell output. | Fixed in current source; identical private native regression passes. |

The red control loads the **actual** media component, with a fake paired/reachable
provider model, temporary HOME/runtime, private D-Bus session and an owned
loopback HTTP server. The URL contains an invented token. Both collapsed and
expanded cases produced `(requests=1, URL/token logged=true)`. The assertion
requires `(0, false)`. Valid title, artist, player and playback state are checked
in the same fixture. HTML-like title text is included to challenge text sinks.

This proves the Plus URI sink and logging behavior. It does not prove that an
arbitrary phone packet passes through KDE Connect's own artwork caching or
validation. It does not establish arbitrary-file disclosure, credential theft or
code execution. The helper's artwork fallback properties and the direct UI sink
were considered together; native provider behavior remains a separate boundary.

The applied repair removes provider artwork rendering and publication. A neutral
music symbol retains media orientation. Text, player choice and playback controls
remain. A later artwork feature needs its own bounded native-cache contract.

Regression command:

```sh
python3 -m unittest tests/test_security_boundaries.py -q
```

Green result: **1 test, both native subcases pass**, about 2 seconds. Each records
zero loopback requests and no URL or token in captured shell output. Valid media
text and playback state remain. The test did not change between the red and green
runs. Source inspection also confirms controller publication sets `albumArt` to
an empty value and the component has no provider image consumer.

## Red and blue dispositions

| Red challenge | Observed control or limit | Disposition |
| --- | --- | --- |
| Put a network URI in provider artwork, with the card expanded or collapsed. | Before repair, direct `Image.source` bindings fetched it and Qt logged it on failure. The repair removes those consumers. | PRIV-01 fixed; identical green checks observe no request or URL/token output. |
| Put HTML-like content in a track name or native action label. | Product dynamic `Text` and the inspected native kit `Button`/`PanelToolTip` content use `Text.PlainText`. The media fixture includes image-like title markup. | No additional supported injection finding in the inspected sinks. This is not a complete Qt renderer assessment. |
| Use filenames, aliases or provider values as shell commands. | New helpers pass fixed argument arrays; selected file paths go through JSON stdin and local-file validation before the CLI path argument. Imported icon names are hashes, theme names and glyphs are validated. | No supported shell-injection path found in these inspected flows. Installed tools and PATH remain trusted local code. |
| Replace a selected source with a link or changed file. | Regular-file/no-follow checks and identity/timestamp comparison reject observed changes. Shared mutable sources now use a retained private snapshot from the validated descriptor. | A fake native backend replacement probe reads reviewed bytes through the actual submit helper; its raw-path negative control reads the sentinel. KDE itself was not used. Protected private paths retain native later-open behavior; same-UID code and root remain trusted. |
| Read saved metadata from a FIFO or leave child processes after a timeout. | Earlier release regressions cover nonblocking metadata reads and owned process-group termination. | Existing repairs retained. This is not containment against a malicious child that deliberately creates a separate session. |
| Turn on network activity without opt-in. | Address changes require explicit approval. Automatic rediscovery requires both an open panel and the separate opt-in; only approved saved rows are scheduled. Owner links open the existing provider interfaces. | No additional supported unauthorized setup/toggle finding found in the inspected paths. KDE Connect itself retains its existing discovery/transfer authority. |
| Leak local paths or file content through saved operation history. | Transfer summaries retain counts, size, peer identity and outcome in memory, capped at 50. Draft/queue paths are transient; the CLI path can appear in process metadata. | No saved payload/history store found in this flow. Local process metadata and native provider logs remain outside that claim. |
| Make source review upload runtime state or secrets. | Repository review configuration operates on repository content. Issue/contribution instructions require invented, redacted examples. Native test artifacts use owned fixtures. | Review services can receive repository content according to their configured access. No runtime telemetry uploader was identified in product source. This does not audit GitHub/CodeRabbit retention policy or the user's app installation. |

## Data map

| Data | Use and retention | Privacy limit |
| --- | --- | --- |
| Pairing keys, VPN keys, API credentials | Owned by KDE Connect and existing network/Syncthing tools. Plus adds no credential copy path. | Those native tools and the user session remain trusted. Their security was not independently audited here. |
| Aliases, icon choice, explicit identity links, approved addresses | Private XDG metadata, owner-only directories/files, validated reads and atomic replacement. | Same-user applications can read user-owned state. Imported assets remain after removal; no automatic garbage collection is claimed. |
| Selected filenames/paths | Needed in transient review and submission state; not copied into operation summaries. | Paths can appear in process metadata and native provider diagnostics. |
| Device/media/command labels | Rendered as local UI text. | Private when visible on screen. Screenshots and manual diagnostic sharing require user review. |
| Source and review evidence | Public repository files, invented fixtures, bounded reviewer evidence. | Public code and review comments remain public. Do not attach raw personal configuration, private IDs or credentials. |

## Residual limits and evidence boundaries

- The plugin is not a sandbox. A malicious installed QML/helper or provider can
  act with user-session authority. The fixed argument and private-file controls
  reduce data-boundary errors; they do not make untrusted plugin installation safe.
- Not all inherited provider collectors have a single global output-byte limit.
  Bounded new helper responses do not establish a global memory bound for every
  KDE/media/command response. No remote resource-exhaustion exploit was reproduced
  in this finite review.
- The checks use fake provider metadata and an owned loopback server. They do not
  validate a real phone, production network, provider permissions, delivery,
  accessibility or every image decoder path.
- Source inspections and review-service configuration are not legal privacy
  compliance, a penetration test or an assurance about third-party retention.
- The trusted CSO prerequisite check is recorded separately: static snapshot is
  available; Docker, qualified runtime and scanner execution are unavailable.
  No CSO runtime reproduction or scanner completion is claimed by these native
  fixtures.

## Follow-up fixes after the Standard scan

Activity now renders peer names with `Text.PlainText`. The real native component
regression previously observed one owned loopback image request; after the fix it
observes zero requests and no URL/token output. Accepted/delivery-unknown state is
retained. This is separate from the artwork regression.

The file handoff uses `scripts/private_sources.py` for descriptor validation and
private snapshots when another local principal can modify the reviewed source.
Focused unit and actual-submit/fake-backend regressions cover symlink replacement,
identity changes, failed preparation, copy bounds, cancellation, retention and
cleanup refusal. See [the exact contract](CONTRACTS.md#file-chooser-and-submission).
No native KDE exploit reproduction or general atomic descriptor transfer is claimed.

The contributor media fixture now writes its fake-call log inside its owned
private temporary directory. SMS launch arguments are bounded before reaching the
native launcher. These are isolation and validation hardening, not demonstrated
current-host privilege escalation or shell injection.

When a running helper is stopped without an explicit before-submission
acknowledgement, cancellation remains unconfirmed. A deterministic model regression
covers both unknown and acknowledged-before-submit results; no Qt event-order race
is claimed.

## Trusted CSO snapshot result

The separate trusted static/offline CSO run was
`1793302561724-25efd10c37549669`, snapshot
`56248b7f3ea0ea257e333d06d3dca80d647e2da88518605a870389a191514d58`.
It completed with **partial coverage and zero supported findings in that assessed
snapshot**. The reported gaps included three binary images, AGENTS/CLAUDE files,
redacted spans and 14 of 58 history entries. Docker, qualified runtime and the six
external scanner executions were unavailable. These later fixes and the upstream
watcher were not certified by that earlier snapshot. Manual/native QA and the
Standard scan retain their separate scope and findings.

## Marketplace private-text blocker

The maintainer's [comment 6504021105](https://github.com/omacom/omarchy-plugin-marketplace/issues/13289#issuecomment-6504021105)
identified typed text in `kdeconnect-cli --share-text` arguments at the published
0.1.0 revision. The same boundary also applied to custom Ping content.
Both routes now use a fixed Python helper command, bounded JSON stdin and the
existing native D-Bus method. Source no longer sends those payloads in process
arguments. A private fake-bus integration checks the received content, while
`/proc` checks the helper command/environment and captures sanitized output.
These checks establish the Plus process boundary; they do not audit the KDE daemon
or make the session bus private from other applications running as the user.
The exact fixed revision and hosted review belong to the final release receipt.

## Post-review availability and fixture isolation

CodeRabbit's full review identified optional cache housekeeping on protected
sources as an unnecessary prerequisite. That path now skips unsafe/unavailable
cache housekeeping and expiry I/O failures. Cancellation/deadline and held-source
identity checks remain; shared-source snapshots still require a safe cache. The
17 private-source tests and 7 transfer tests cover this boundary.

The standalone transfer child's HOME/cache now belong to its temporary fixture.
Canonical full runs already isolate HOME/XDG globally; direct focused runs must
also be safe. No production cache was present at the parent's review-time check.
This is a correction to test isolation, not retrospective proof about all earlier
machines. Cleanup/retention language now says best effort when cache is safe and
available. No maximum retention guarantee is added.
