# Settings integration decision, 50 personas and RICE — 29 October 2026

**Recommendation: continue the dedicated Plus Settings window with a searchable
feature view and a clear selected-device handoff to native KDE Connect. Do not
build a second complete native-plugin settings engine or an add-on installer in
this release.** A bounded spike for a specific frequent native setting remains a
valid next step if task evidence shows the handoff is the main failure point.

This is a decision about user outcomes and the work remaining. It is not an
argument against a new settings page: the new, domain-organized Plus Settings
window is already the selected design. The disputed extra scope is whether that
window should reproduce every native module control and install new modules.

## Correct the premise before comparing options

KDE Connect 26.08.2's native Plugin Settings page has search, per-module enabled
checkboxes and configuration actions when a module supplies a configuration
page. Its source contains no catalog, download or new-module installation action.
The device page only shows the Plugin Settings action for a paired, reachable
peer. An offline peer can therefore make this capability look missing.
[Native Plugin Settings](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/app/qml/PluginSettings.qml),
[native device page](https://github.com/KDE/kdeconnect-kde/blob/v26.08.2/app/qml/DevicePage.qml).

Here, **enable an installed feature** and **install a new native module** are
separate tasks. The first belongs to native device configuration. The second
needs a compatible package/build and a source-of-trust decision; it is not the
same operation as adding an Omarchy bar plugin. This source check establishes the
inspected native page's behavior, not the absence of every third-party packaging
project. Other KDE versions and platforms must be checked before claiming parity.

The inspected package has 31 native libraries. That number is neither the number
of supported features on each peer nor a permanent product contract. The fork
preserves safe unknown IDs. Supported, loaded, enabled and permitted remain
separate facts; a convenient toggle must not infer one from another.

## Alternatives and domain ownership

| Option | User-facing result | Responsibilities and cost |
| --- | --- | --- |
| **A — Dedicated Plus Settings plus native handoff** | One named Settings window, four domain pages, all active Plus preferences, native-feature search, selected-device link to KDE Plugin Settings and clear return guidance | Plus owns appearance, its action visibility and connection integration preferences. KDE owns native module configuration and permissions. Smallest remaining implementation and compatibility surface. |
| **B — A plus all native module controls inside Plus** | Search, enable/disable and every available native configuration page in one Plus window | Retains KDE's protocol engine but adds a complete configuration frontend, enabled-state reads/writes, loading/readback errors, per-device context and version/platform coverage. Embedding existing components needs an actual API and license review; source copy is not assumed permissible. |
| **C — B plus a new-module catalog/installer** | Find and install third-party native modules without leaving Plus | Adds package provenance, architecture/ABI compatibility, installation authority, update/removal/recovery and an explicit trust boundary. Requires concrete installable modules and a maintained distribution path. No native-store parity claim is available from the inspected source. |

DDD applies to navigation as well as source ownership. **Appearance** contains
icons/local names; **Connections** contains visibility, provider help and helper
configuration; **Sharing** contains file workflow and related quick actions;
**Device features** contains the selected peer, feature search, native owner link
and status/action preferences. Common tasks stay in Devices/Send/Activity. A
single place to start does not require a second owner for every setting.

## Evidence boundaries

The following 50 personas are synthetic task lenses from one review. They are
not 50 people, recruited research, independent models, medical evidence or an
accessibility certification. Checks below are proposed acceptance work, not
reported passing tests. Persona rows overlap; their count must not be converted
into reach, confidence or vote percentages. Existing fixture/native receipts
establish only their own narrow contracts. No real file, permission, plugin or
VPN setting was changed for this strategy audit.

## Fifty persona scenarios

**A, B and C below refer to the alternatives above.** A conditional advantage for
B is recorded when it could remove a real task obstacle. It does not authorize
building B without checking that obstacle and the native API.

| ID and task lens | A: value and friction | Challenge from B or C | Acceptance check / decision |
| --- | --- | --- | --- |
| **SP01 — ADHD user sending one photo** | Direct Send avoids configuration; separate Settings keeps the task quiet. | B's full module list could distract without improving sending. | Send a photo without visiting Settings; no plugin inventory in the daily task. Prefer A. |
| **SP02 — AuDHD user who needs stable categories** | Four named domains give a repeatable route. | An external native window changes layout and vocabulary. B could preserve context. | Find the same setting twice after a break; record wrong turns and handoff confusion before extending A. |
| **SP03 — User with low working-memory capacity** | Selected device and return guidance reduce context loss. | B removes the need to remember which window owns the setting. | Switch to native settings and back without changing the wrong peer. If failure persists after clear context, spike B. |
| **SP04 — User overwhelmed by choice** | Search and domain pages limit simultaneous choices. | B/C can add dozens of controls and installer choices to the same view. | Initial Settings screen shows one domain, with no automatic expansion of all feature controls. Prefer A. |
| **SP05 — User who interprets switches literally** | Visibility toggles can state Show; native module controls remain distinct. | B risks mixing Show action, Enable module and Grant permission. | Explain each switch's actual effect without trial and error. Never label all three Enable. |
| **SP06 — Keyboard-only user** | Native controls can provide predictable traversal. | Two windows add a focus transition; B might remove it but also adds traversal cost. | Open native settings, navigate search/toggles, close it and return with visible focus. Test both routes if A fails. |
| **SP07 — Screen-reader user** | Plus can label its own controls and context clearly. | The inspected native configuration action has an accessibility FIXME. A inherits that limitation; B may improve a specific task. | Test actual AT-SPI/Orca on the required native configuration page. A source label alone is no pass; use a narrow B adapter if needed. |
| **SP08 — Low-vision user at enlarged text** | A's smaller owned surface is easier to validate. | B avoids a differently scaled native window but increases layout density. | Run both windows with enlarged text; all controls remain reachable with vertical scrolling and no clipped labels. |
| **SP09 — User with motor tremor** | Persistent Settings window avoids a fragile bar popover. | B could reduce a small native menu target; C creates more risky confirmation targets. | Reach native settings with a labelled, adequately sized button; verify pointer hit targets before deciding B is needed. |
| **SP10 — User who disables animation** | Native window and standard controls fit the existing platform. | A/B both fail if added transitions ignore reduced-motion settings. | Open/close domains with animations disabled and preserve focus. No choice gains a blanket accessibility claim. |
| **SP11 — First-time KDE Connect user** | One native feature link explains where enabling happens. | B may feel simpler, but a new installer would reinforce a false store model. | User can distinguish enabling an installed feature from installing software. Prefer A with precise copy. |
| **SP12 — User asking to add clipboard sync** | Native Plugin Settings already enables the installed clipboard module. | B could save a handoff for a common operation; C adds nothing here. | Time enable-and-verify for clipboard under A. Only count B's benefit if this is a repeated material delay. |
| **SP13 — User asking to install a novel module** | A does not solve installation; it must say so. | C is relevant only if a concrete compatible module exists outside the package. | Identify module source, license, supported architectures and installation route. Do not invent a catalog entry. |
| **SP14 — User enabling notifications once** | Native one-time configuration has low recurring handoff cost. | B's convenience is real but small for an infrequent task. | Complete initial enablement and confirm phone permission requirements are explained. Prefer A unless repeated failures appear. |
| **SP15 — User changing notification rules daily** | Repeated native handoffs can be expensive. | B has a plausible recurring benefit for a stable, specific native configuration page. | Measure frequency and cumulative task time; consider a narrow shortcut or adapter before B's whole-module scope. |
| **SP16 — User looking for phone files** | Search Browse and the native route can reveal SFTP. | B may offer a direct launch but still cannot supply unsupported phone permissions. | Search task language, open native browsing and show a useful unavailable reason if the peer lacks it. |
| **SP17 — User who searches raw plugin IDs** | Full safe IDs stay searchable, including unknown IDs. | B is not needed merely to preserve identifiers. | An unknown valid third-party ID survives discovery and search. Prefer A. |
| **SP18 — User searching everyday words** | Friendly task labels reduce protocol jargon. | A's fixed label map can miss synonyms and unknown modules; B's native metadata may be richer. | Search files, notifications and commands, then inspect no-match recovery. Improve labels or native handoff before broad B. |
| **SP19 — User with two similar phones** | Both Plus and native launch must show the selected identity. | B removes a cross-window mismatch but still needs correct per-device state. | Switch peers before/after opening settings; no write targets the previously selected peer. Required for every option. |
| **SP20 — User who closes settings accidentally** | Saved toggles persist; explicit text Save shows unsaved edits. | B expands the amount of draft configuration that could be lost. | Close/reopen and inspect saved versus unsaved behavior. Define it before embedding module-specific editors. |
| **SP21 — Phone currently offline** | A must explain that native Plugin Settings can be hidden while offline. | B may expose cached enabled state, but stale support/permission information can mislead. | Read-only search remains honest; edits require an API-supported offline contract. Do not fake an enabled value. |
| **SP22 — Unpaired device owner** | Pairing remains with KDE Connect and precedes sensitive module settings. | B/C must not turn module discovery into implicit trust or pairing. | No module change occurs from selection/search alone. Offer the native pairing route with clear context. |
| **SP23 — Android user missing a permission** | Native Android permissions remain visible as a separate requirement. | B cannot grant phone permissions from the desktop; a desktop switch could falsely suggest completion. | Enable a desktop module with the phone permission denied; show pending/unavailable, not Ready. |
| **SP24 — iPhone user expecting Android parity** | A can acknowledge peer capability differences and use native documentation. | A uniform B/C list can imply features the phone platform does not support. | Filter by actual support and state platform limitations in task language. Required for all options. |
| **SP25 — Linux-to-Linux user** | Native settings already handle receiver/sender roles. | B could offer a better integrated presentation but must preserve direction semantics. | Remote commands/media use the correct sender interface; receiver-only modules never advertise a sender action. |
| **SP26 — ARM64 laptop maintainer** | A uses installed native packages and existing libraries. | C must distribute compatible modules for ARM64, not only x86 binaries. | Check architecture/Qt/KDE ABI before offering any install. No install option without a supported build. |
| **SP27 — x86 desktop maintainer** | A and its selected-device route can be validated independently on the desktop. | Passing x86 B/C does not establish ARM or phone behavior. | Record host-specific evidence and preserve both accepted package paths. |
| **SP28 — User on an older KDE release** | Launcher fallback can open the older device list with explicit guidance. | B depends on more version-sensitive state and configuration APIs. | Run declared supported versions; missing methods produce unavailable state and no guessed writes. |
| **SP29 — User with a third-party installed module** | Unknown IDs remain searchable and native configuration stays authoritative. | B needs that module's configuration contract; C also needs distribution ownership. | Unknown metadata is plain text and bounded. Missing configuration page does not become an error or a fabricated editor. |
| **SP30 — User testing a module from source** | A leaves build/install tooling with the developer. | C could ease repeated local development, but a consumer installer is not the smallest tool for that task. | Document the development package path and restart/recovery needs. Consider developer tooling separately from this UI. |
| **SP31 — Traveller using BTH Automatic** | Connection visibility is separate from actual VPN mode and native module state. | B/C add no inherent benefit to LAN/BTH policy correctness. | Hidden integration does not change the tunnel; Automatic/inactive at home remains normal. Prefer A. |
| **SP32 — Tailscale user** | Enable only that integration and approve the peer address. | A must avoid making BTH the only first-class path. | Tailscale help and owner route work with BTH hidden; no automatic enrollment or false connection claim. |
| **SP33 — Generic WireGuard user** | Existing profile owner controls connectivity. | An integrated B could tempt shared arbitrary tunnel controls beyond native KDE configuration. | Hide BTH/Tailscale, open the correct profile manager, and preserve keys/policy. No generic Automatic claim. |
| **SP34 — User with phone away and desktop on LAN** | Address hints can serve the peer's route without a local VPN daemon. | C's local installer does not solve remote reachability. | Verify selected KDE identity over the approved route; do not require a local Tailscale/BTH interface as proof. |
| **SP35 — Privacy-sensitive clipboard user** | Native permission/configuration boundary is visible. | B could reduce friction while making accidental enablement easier. | A switch explicitly names whose clipboard is shared; no bulk enable-all action. Required before any B adapter. |
| **SP36 — User enabling remote input** | Native settings preserve a familiar high-impact permission decision. | B gains convenience but must retain deliberate consent and peer context. | Search/opening settings makes no input permission change; verify actual native readback after explicit action. |
| **SP37 — User configuring remote commands** | Native command editor owns executable content and direction. | B would add security-sensitive text/configuration surfaces and failure recovery. | No command is executed by saving, focusing or previewing a setting; use fixed arguments and explicit execution. |
| **SP38 — Shared workstation user** | Existing per-user native settings and key storage remain authoritative. | C may introduce privileged system-wide installation from a per-user bar UI. | Define account/package scope and authorization before installation. No secret copying or silent privilege escalation. |
| **SP39 — User recovering from a failed plugin update** | A uses the normal package recovery route. | C must own rollback, dependency compatibility and removal without deleting pairings. | Demonstrate failure recovery using a disposable package fixture before shipping an installer. |
| **SP40 — User who clicks Enable all** | A has no misleading bulk shortcut. | B/C can encourage unnecessary permissions and increase background activity. | No default bulk enabling; each sensitive feature retains clear purpose and an explicit choice. |
| **SP41 — First-time contributor** | Domain pages and a task/file/check map give a small starting surface. | B/C require understanding native models, config pages, versions and packaging before a simple change. | Contributor can add a task label or preference without editing the protocol engine. Prefer A. |
| **SP42 — Native KDE maintainer reviewing upstream value** | A can contribute generic discovery/wording fixes without moving ownership. | A complete B may duplicate upstream fixes; C is a separate distribution product. | Separate generic UI patches from local BTH adapters and identify the upstream owner for each defect. |
| **SP43 — Maintainer with limited time** | A's remaining validation is bounded by the existing native contract. | B/C expand long-term obligations beyond initial coding time. | Include supported-version checks, regression work and release recovery in effort estimates. Prefer A until capacity exists. |
| **SP44 — Translator** | Four domains and native handoff reuse existing native translations. | B duplicates a large changing module vocabulary; C adds packaging and trust copy. | Keep complete translatable strings and task labels; test long labels and RTL before claiming support. |
| **SP45 — Documentation contributor** | A can explain one owner per kind of change. | B could reduce handoff instructions but needs module-specific configuration docs. | A reader can answer Where do I change this? for each setting without knowing source filenames. |
| **SP46 — Accessibility contributor** | Narrow Plus controls are practical to improve and verify. | A's native handoff can inherit an inaccessible module page; B could fix a specific proven gap. | Reproduce the obstacle with AT, then propose the smallest accessible native shortcut or adapter with upstream evidence. |
| **SP47 — Package distributor** | A remains a small MIT fork over the installed native engine. | Embedding/copying KDE QML and C's redistribution introduce license and build obligations. | Review each reused component's license and ABI; do not copy native GPL source into the MIT tree without a deliberate compatible plan. |
| **SP48 — Incident responder** | A has fewer writers and clearer ownership when a module fails. | B/C require tracing enable requests, stale reads, install jobs and recovery. | Show safe bounded diagnostics without payloads or secrets and identify the actual writer. |
| **SP49 — User running original and fork side by side** | Distinct icon/tooltip and existing native owner support comparison. | B creates another configuration frontend competing with the native app for writes. | Detect/read back outside native changes; never restore a stale settings snapshot over another window's edit. |
| **SP50 — Product owner deciding what to fund next** | A can be tested now for the actual file/connectivity/settings tasks. | B/C may pay off if native configuration is frequent and the handoff causes repeated abandonment. | Gather task completion, wrong-device errors, handoff frequency and support demand before increasing scope. Prefer evidence over persona vote counts. |

## What the 50 scenarios change

A is not a free pass. Its main risks are window handoff, selected-peer confusion,
native accessibility gaps, offline gating, and search that covers reported
compatible IDs rather than a complete installation catalog. These are acceptance
items, not reasons to claim all native features are usable. A should expose the
native route even when its own list is absent, state why the peer may need to
connect, and keep a clear route back to Plus preferences.

B has plausible value for frequent native configuration and specific proven
accessibility failures. That is an argument for a measured, narrow adapter or
upstream fix first. It does not establish demand for reproducing every module's
configuration interface. C answers a different, currently unsubstantiated task:
installing new native code. The source inspection does not justify calling it a
hidden native feature that only needs unhiding.

## RICE model: assumptions, not measured product data

**Horizon:** next 90 days. **Cohort:** a hypothetical 100 active Omarchy users
with KDE Connect. No user count, adoption rate or task frequency was measured.
The three rows are alternative release packages from the same current point.
B includes A; C includes B. Thus B/C receive at least A's assumed reach rather
than being penalized as if they benefited fewer users overall. Shared completed
work is a sunk cost and is excluded from every effort figure.

**Reach** is distinct users receiving a meaningful improvement in that cohort.
**Impact** uses the conventional ordinal RICE scale: 0.25 minimal, 0.5 low,
1 medium, 2 high, 3 massive. Intermediate scores are planning judgments.
**Confidence** is a declared discount for the assumptions, not a statistical
probability or a persona approval rate. **Effort** is remaining person-weeks to
a reviewed usable release, including integration, native/permission/error tests,
version/architecture checks, docs and recovery. It is not a time promise, and
agent execution time does not replace physical-device or human acceptance.

`RICE = Reach × Impact × Confidence / Effort`

| Option | Assumed reach / 100 | Assumed impact | Assumed confidence | Assumed remaining effort, person-weeks | RICE, relative units |
| --- | ---: | ---: | ---: | ---: | ---: |
| **A** | 80 | 1.5 | 0.65 | 0.8 | **97.50** |
| **B** | 85 | 1.8 | 0.45 | 3.5 | **19.67** |
| **C** | 90 | 2.0 | 0.25 | 8.0 | **5.63** |

Reasoning behind these assumptions:

- A improves routine configuration/findability for much of the assumed cohort.
  Reused native owners and existing code reduce remaining work, but untested
  human handoff/AT tasks limit confidence to 0.65.
- B reaches a few additional users for whom the handoff is a material obstacle,
  and gives somewhat higher task impact. Its larger API/readback/configuration
  surface, native-page variation and unmeasured frequency discount confidence
  and increase effort. These are hypotheses to test, not proof B is expensive.
- C adds another small reach increment and potential convenience. Concrete
  module demand, compatible distributions, trust/update ownership and recovery
  are not established, so confidence is low and effort includes those jobs.

This model ranks the current investment decision; it does not prove A is best
for every person. RICE does not waive permission, licensing or installation
safety requirements even if a higher-impact estimate makes B or C rank first.

### Range and sensitivity checks

These are deliberately broad planning envelopes. Their corner combinations are
not confidence intervals, do not represent a joint probability distribution,
and may combine correlated assumptions in unrealistic ways.

| Option | Reach range | Impact range | Confidence range | Effort range, person-weeks | Corner-score envelope |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 60–100 | 1.0–2.0 | 0.45–0.80 | 0.5–1.5 | 18.00–320.00 |
| B | 65–100 | 1.2–2.5 | 0.25–0.70 | 2.0–7.0 | 2.79–87.50 |
| C | 65–100 | 1.2–2.5 | 0.10–0.50 | 5.0–16.0 | 0.49–25.00 |

The envelopes overlap. A low-value, slow A can lose to a well-reused B. The model
is therefore useful for a bounded spike, not for closing discussion by score.

- With B's central reach/impact/confidence unchanged, B must finish in **less
  than 0.71 person-weeks** to exceed A's central 97.5 score. That is about 3.5
  five-day workdays, including all validation—not only drawing the checkboxes.
- If a verified native component/API raises B's confidence to **0.80**, central
  reach/impact put the crossover at **1.26 person-weeks**. A reuse spike could
  therefore change the result; its success must include readback/errors/license
  and representative module configuration, not only successful component load.
- With C's central inputs, its crossover is **less than 0.47 person-weeks**.
  Raising demand alone to the cohort maximum cannot overcome central effort.
- In an explicitly optimistic B scenario, 100 × 2.0 × 0.70 / 2.0 = **70**.
  In a pessimistic A scenario, 60 × 1.0 × 0.45 / 1.5 = **18**. B wins there.
  The decisive unknowns are actual handoff burden, safe reuse and remaining
  validation effort; the persona table does not resolve those unknowns.

For future incremental work after A ships, recalculate B using only its **extra**
reach/impact and **extra** effort over A. Do not credit all of A's routine benefit
again merely because B contains the existing settings page.

## Decision and reconsideration gates

**Continue A now.** Finish the explicit native Settings window, independent
provider display choices/help, searchable reported features, visible native owner
route and persistent Send window with review-only file drop. Preserve all native
capabilities through the owner link. No new module loader or installer is needed
to enable an already installed KDE feature.

Before choosing B, collect a small task sample with consenting actual users.
Include a novice, a person using keyboard/AT, and a frequent native-setting user.
Report the sample's limits; it is not statistical or clinical validation. Measure
completion, wrong-peer edits, handoff failures and repeat frequency on concrete
module tasks. Set a prospective trigger such as **at least two distinct users
cannot complete the same important task because of the handoff**, or **a task
repeated weekly spends at least half its observed time on navigation**. These
thresholds are proposed decision rules, not current findings. First test a direct
native shortcut or one adapter, then compare against A with the same tasks.

Before choosing C, name at least one demanded external module not supplied by the
installed package, prove a maintained compatible distribution for both claimed
architectures, and specify package authority, provenance, updates and recovery.
A developer build workflow alone does not establish a consumer catalog need.

Recalculate RICE from the task observations and a bounded API spike. If B's measured
completion advantage and credible remaining effort cross A's score, fund the
narrow integration. If the native window already solves the task with a clear
link, keep that owner and spend the next effort on reliable file sharing and
connection recovery. The user's goal is a successful task, not one more place to
maintain every configuration page.

## Subsequent implementation refinement

The owner's later request made toolbar membership and order a first-class local
preference. The four Settings domains are now Appearance, Connections, Quick
actions and Device features. A shared verified action catalog replaces the fixed
six-button list. This stays within A: it configures Plus shortcuts and delegates
native module enable/config to KDE. It does not implement B's full native settings
frontend or C's installer. The hypothetical strategic comparison is unchanged.
