# Contribution architecture review

Date: 29 October 2026. Source base inspected: `b3bb4ff`.

**Recommendation: document and protect the current boundaries first.** Add one
small contribution guide, explicit facade contracts, and a preset parity check.
Extract a controller only when a real change needs that seam. Keep the existing
Omarchy plugin as one application. A second internal plugin loader is not needed.

This is a read-only source and contributor-experience review. This document is
the only change made by this reviewer. No tests, GUI, transfer, network control,
installation or activation ran during this review. Earlier acceptance receipts
remain in `VERIFICATION.md`; this review does not renew them. The parent owns the
full review workflow and outside-voice synthesis.

## Choose the scope

| Option | Concrete scope | Benefit | Cost and limit |
| --- | --- | --- | --- |
| **A. Contribution map and contract checks — recommended now** | Add a short contribution entry point, domain/file map, facade inventory, preset walkthrough, and one JS/Python preset parity check. Inventory retained legacy address callers. | The next small contribution has a clear route. No runtime or import migration. | About 0.5–1.5 engineer days including review. Large source files remain. |
| **B. One justified extraction** | Keep root entry points stable. Extract file selection/submission lifecycle into a sibling `KdeTransferController.qml`, preserve the facade, and adapt existing behavioral/native fixtures. Review legacy address retirement as a separate change. | Gives an actual second sharing provider a smaller integration seam. Limits changes to one lifecycle. | About 2–4 days for the transfer extraction and checks. Do not combine it with feature additions, state migrations or directory moves. |
| **C. Domain folders after the seam is stable** | Move one domain per change into `features/appearance`, `features/discovery`, `features/home-access`, then `providers/kdeconnect`. Keep `Service.qml`, `BarWidget.qml`, `Panel.qml`, manifest identity and bridge at stable public paths. Update relative imports, helper resolution, validator lists and fixtures together. | Easier file navigation when several contributors work on separate domains. | About 3–6 days across staged changes, with limited immediate behavior benefit. Folder names alone do not improve ownership or extensibility. |

These are planning estimates for one engineer familiar with QML and this fork.
They are not measured results. None includes a new sharing protocol, provider
installation, live-device acceptance or a framework for arbitrary plugins.

## Current domain map

| Domain | Current owner files | Owns | Must not own |
| --- | --- | --- | --- |
| Host composition | `Service.qml`, `BarWidget.qml`, `Panel.qml`, `bridge/` | Own-service lookup, shell integration, views, navigation and composition | Raw lookup of another plugin's private service |
| KDE devices and actions | `KdeConnectController.qml`, KDE helper scripts, device/media/action components | Stable KDE ID, capabilities, pairing, media and explicit KDE actions | Alias identity, VPN policy or Syncthing authentication |
| File submission | Transfer functions/processes inside `KdeConnectController.qml`, `TransferModel.js`, `portal_files.py`, Send/Activity components | Reviewed target, draft, queue, bounded history and request evidence | A claim of delivery from CLI acceptance |
| Appearance and local links | `Appearance.js`, `AppearanceStore.qml`, `appearance.py`, icon/chooser/link components | Alias, icon, private asset storage and an explicit local Syncthing association | Pairing, discovery trust or synchronization control |
| Address hints and rediscovery | `DiscoveryController.qml`, `DiscoveryModel.js`, `manage_addresses.py`, SavedAddresses component | Approved addresses, provenance, serialized reconciliation and opt-in scheduling | A device identity inferred from an address |
| Home access | `BthControlCard.qml`, `BthControlModel.js`, external reviewed helper | Fixed helper contract, selected mode, actual interface state and pending feedback | NetworkManager/WireGuard policy, credentials or profile provisioning |
| Migration | `migrate_settings.py`, migration fixtures | Explicit candidate preparation and conflict-aware recovery | Live activation during development |

These are bounded responsibilities, not a demand for entity/repository/service
layers. The current QML models, controllers, helpers and views already express
most of them. Keep domain names consistent in code, docs, tests and review.

## Findings that affect the next contribution

### 1. Preset IDs have two active sources

`Appearance.js:4` lists five presets with their labels, glyphs and theme names.
`scripts/appearance.py:25` separately allows the same five IDs. A contributor who
adds only the UI entry gets a save rejection. `tests/appearance.cjs:25` also
hardcodes a count of five.

**Small fix:** retain both validators and add a test that compares their allowed
IDs. Replace the count assertion with checks for required defaults, unique IDs,
and valid entries. The helper must still validate independently of the UI.
Do not add a runtime data loader or generator for five entries. If presets later
grow into a managed catalog, reconsider one data file then.

UI normalization and helper validation have different jobs. The UI can fall back
to Phone; the helper must reject unsafe persisted input. Do not merge these two
behaviors merely because their validation rules overlap.

### 2. Address ownership is clear in the new path but retained in the old path

The visible saved-address UI uses `DiscoveryController.qml` and
`scripts/manage_addresses.py`. The controller still contains
`addCustomAddress`, `removeCustomAddress` and `writeCustomAddress`, which invoke
`scripts/update_custom_address.sh`. `Service.qml` still forwards them.
`Panel.qml` hides `NetworkSection`; `legacyNetworkEnabled` disables Tailscale
refresh, but is not a guard on every legacy address write method.

This is retained maintenance surface, not proof that both writers are active in
normal use. Before removal, inventory callers and decide whether these methods
are supported facade compatibility or retired UI internals. Then remove the
retired path and its tests together, or make any compatibility route obey the
current approval/provenance contract. Do not simply forward the old unscoped
address method to the new peer-scoped API with an invented peer ID.

`appearance.py:88–99` also preserves an optional older `addresses` field whose
shape differs from `addresses.json`. Treat it as preserved legacy metadata.
Document its status; do not silently merge or delete it during a folder cleanup.

### 3. The facade is a useful boundary, but its scope is implicit

`Service.qml` is 259 lines and already composes appearance and discovery beside
the KDE controller. This is useful. Most KDE properties/actions are forwarded;
appearance and discovery are exposed as whole objects. BTH is composed directly
in `Panel.qml`. These choices are not automatically defects.

Document the surface intended for this plugin's views. State which members are
observed values, commands, return values and signals. A `true` return commonly
means a request started, not that its asynchronous result succeeded. Keep
`busy`, error and terminal state available to the consumer.

Keep feature-specific lifecycle state out of the composition layer. Do not add
another generic `runAction(provider, action, payload)` surface. It would weaken
the specific identity, approval and cancellation contracts already present.

### 4. File submission is the best next extraction, when needed

The KDE controller is 1,599 lines. The file draft/queue logic is concentrated at
approximately lines 541–769, with processes around 1275 and 1400. The pure
`TransferModel.js` already handles summary state. The UI uses Service aliases.
That is a concrete extraction seam.

If the next change needs it, move the draft, queue, processes, deadlines and
cleanup together into a sibling controller. Keep one owner for cancellation and
operation IDs. Pass KDE capability/reachability checks through a small explicit
interface. Preserve reviewed target identity when selection changes. Do not move
only helper functions and leave lifecycle state split across two owners.

Do not generalize the KDE queue to another provider before its actual contract is
known. Another provider may expose daemon-owned transfers, a different file-token
lifetime or a different cancellation guarantee.

### 5. A directory move has real runtime and test blast radius

QML uses implicit local types and relative imports. Components import
`../Appearance.js` or `../TransferModel.js`; stores/controllers resolve helpers
relative to their QML file. `BarWidget.qml` resolves `Panel.qml`. The bridge has
its own singleton declaration. Moving these files changes behavior unless all
resolution paths move together.

`scripts/validate.sh` explicitly names top-level QML files. Discovery fixtures
copy selected root files. Native fixtures import `plugin`, `plugin/components`
and `plugin/bridge`. Any domain-folder change must update these paths and verify
real QML loading. A passing Python model alone cannot establish that imports load.

### 6. Existing tests include useful behavior and substantial source coupling

`tests/test_state.py` is 2,573 lines: 88 test methods and 317 `assertIn` /
`assertNotIn` calls at this snapshot. These counts are source metrics, not a
test-run result. Some tests execute helper behavior; others inspect exact source
strings or model QML state in Python. `transfer_model_test.js` executes production
JS and extracts named functions from QML text using brace counting.

Preserve behavior coverage, but do not treat all string assertions as a public
contract. When a touched test fails after a move, ask which invariant it protects.
Use production pure-model tests for transformations and isolated native QML
fixtures for bindings/lifecycle. Replace a source-location assertion when it
blocks a justified extraction; do not rewrite all tests at once.

### 7. Similar helper plumbing is not yet a shared domain

Appearance, address and migration helpers repeat bounded JSON, private storage
and atomic-write patterns. Their lock, permission, failure and ownership rules
differ. A broad `common.py` would couple unrelated workflows. Keep the copies
until the same defect or required change must be fixed in several places. Then
extract the smallest operation with equivalent semantics and retain domain
validation with each owner.

## Facade contracts to make explicit

| Surface | Caller can do | Result and evidence | Boundary |
| --- | --- | --- | --- |
| KDE facade | Select known ID; request a capability-gated action | Observe availability, busy/error and async state | Selection or alias never changes a captured batch recipient |
| Appearance store | Preview, apply, import, reset, link/unlink IDs | Command acceptance plus saved/imageImported/operationFailed signals and validated snapshot | Import alone does not apply; local association does not verify provider ownership |
| Discovery controller | Approve/remove an address; opt into rediscovery; request refresh | Observe ready, busy, sanitized error and canonical rows | No identity/pairing from IP; closed panels stop automatic work |
| BTH card/model | Read public status; explicitly request Automatic/On/Off | Observe pending, mode and actual interface state separately | Helper owns policy; unknown status never grants action authority |
| Syncthing opener | Open a fixed owner panel | Report opened only after fixed IPC acknowledgement | No raw service object, key, second core or generic proxy |

This is an internal application contract. It is not a stable third-party plugin
API. A future external API requires versioning, ownership and consumer tests.

## Walkthrough: add one icon preset

1. Pick a unique stable ID. Add its label, glyph and theme fallback to
   `Appearance.js`. Preserve Phone as the default and fallback.
2. Add the ID to `appearance.py`'s allowlist. Do not change storage schema merely
   to extend this list. Do not change `typeIcon()` unless a device-type mapping is
   separately intended.
3. Test UI resolution, library visibility, helper save/reload, and fallback when
   the theme or font is absent. Add the proposed parity check. Update the existing
   fixed-count test so it checks the catalog's contract.
4. Run `./scripts/validate.sh` from the checkout. Use its temporary home/private
   bus and fake actions. Read skipped-prerequisite output. Do not activate the
   installed plugin to prove a metadata change.
5. Update the short capability documentation if the new preset changes choices
   described there. Record native visual acceptance separately if it is performed.

Expected code touch points are one JS file, one Python allowlist and the relevant
tests. A preset contribution should not require editing the KDE controller,
Service, migration or network policy.

## Walkthrough: add a provider later

1. Write its versioned owner contract first: identity, capabilities, availability,
   limits, errors, startup behavior, selection tokens, state and cancellation.
   Define what success proves. Keep identities namespaced by provider.
2. Add one explicit sibling controller and a pure model only where transformation
   rules need one. Let the existing provider daemon own protocol and secrets.
3. Compose it in `Service.qml`. Publish only the values/commands needed by the
   chosen view. Do not resolve another plugin's private service.
4. Add a provider-specific UI section. Share a small visual component only when
   both real uses have matching interaction semantics. Preserve distinct pending,
   accepted, delivered, unknown and cancelled evidence where contracts differ.
5. Add fake-service and isolated QML checks for absent/restarting provider,
   unsupported version, stale completion, bounds, error, timeout and cancellation.
   Extend the sandbox's fake-command/DBus inventory before executing native tests.
6. Check keyboard order, visible focus, accessible names, plain-text remote labels,
   large text, compact width and clear action feedback. A hidden section must not
   receive an action intended for the current view.
7. Update `CONTRACTS.md`, ownership map and verification limits. Perform physical
   device/provider acceptance as a separate explicit step.

Do not register arbitrary module paths, load scripts from metadata, add a generic
event bus, create transport factories or introduce repositories for every model.
Reconsider an internal extension registry only after two implemented providers
show repeated composition that a small explicit interface cannot handle clearly.

## Contributor entry point and review checklist

Keep the eventual contribution entry point short. It should fit on one screen:
start command, domain/file map link, one small example, safety boundary and done
checklist. Use links to `CONTRACTS.md` and `IMPLEMENTATION.md`; do not duplicate
their full contents in README, AGENTS and every feature folder.

Use consistent headings and short numbered tasks. Give one default path and put
optional native prerequisites after it. Label blocked prerequisites, test skips
and the next action clearly. This reduces working-memory load for ADHD/AuDHD
contributors without hiding decision-relevant evidence.

For each contribution, the reviewer checks:

- One domain owns each new mutable state and external action.
- IDs, local appearance, route hints and provider trust remain separate.
- Views use the documented facade; no new private cross-plugin access appears.
- Existing bounded input/output, cancellation and error semantics are preserved.
- Code, affected contracts and meaningful checks change together.
- Folder-only changes and behavior changes are separate reviewable steps.
- Full validation passes before commit; runtime/device claims cite separate evidence.

**Next decision:** choose A for the next small contribution. Choose B when a real
transfer/provider change needs it. Choose C only after file navigation is a measured
collaboration problem. This review does not authorize those code changes or a new
provider implementation.
