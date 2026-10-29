# First-release implementation boundary

The owner approved a narrow UI fork after product, engineering, persona and
red/blue reviews. The accepted direction is Devices / Send / Activity, with a
separate Appearance view. The design review retained one minor navigation concern.
The design pack remains in the audit workspace; this document records code scope.

| Package | First-release result | Required evidence |
| --- | --- | --- |
| T00 | Separate GitHub fork, upstream remote and pinned base, isolated worktree | Source identity and original installed-file hashes |
| T01 | Separate plugin ID, staged allowlisted migration and conflict-aware rollback | Native/ryan.bar fixture preservation; no live activation |
| T02 | Bar/device icon chooser, aliases, private assets and metadata | Validation, native Apply/Cancel/reload and missing-asset fallback |
| T03 | Portal multiselect, explicit recipient/file review | Private D-Bus portal and regular-file boundary fixtures |
| T04 | Sequential KDE request queue and bounded activity | Fixed-target, accepted/failure/unknown/cancelled lifecycle |
| T05 | Existing BTH helper card | Strict status validation, absent/unknown provider, fixed commands |
| T06 | Approved private addresses and opt-in rediscovery | Serialized merge/readback, provenance, route debounce and closed-panel stop |
| T10 | Explicit Syncthing ID link and owner-panel open | Independent IDs, local-only association, no new core or API key |
| T13 | Docs, CI and verification receipts | Full functional suite and native loading; physical checks recorded separately |

## Domain ownership

The own Service facade publishes presentation, discovery and KDE actions to this
plugin. It keeps the replacement-bar bridge fallback. It does not look up raw
services from other plugins. The host’s right-click guard remains unchanged.
KDE Connect keeps protocol identity, pairing, payloads and delivery. The BTH helper
keeps route policy. Syncshell keeps synchronization and authentication. Network
hints never grant trust or pairing. Local aliases never replace provider IDs.

## Deferred gates

- Quick Share requires a separately validated daemon contract and device tests.
- Router/UniFi rosters belong to the separate Banatik work. Consume a future
  sanitized public contract only after that owner defines it.
- New BTH/WireGuard onboarding requires its own profile/secret-store review.
- Syncthing status/pause/resume requires a narrow owner-side API and exact-device
  validation. No generic REST proxy or global pause exists in this release.
- Physical Linux/Android delivery, offsite routing, x86_64 native UI, actual
  replacement-bar mapping, assistive technology, RTL and scale acceptance require
  their own receipts. Do not promote a candidate on a fixture-only result.

## Maintenance

Keep generic UI improvements separate from the local BTH policy adapter. Rebase
against the pinned upstream only after reviewing changes. Use supported Omarchy
commands and user plugin storage. Do not edit `/usr/share/omarchy`, force-reset a
dirty tree, copy pairing data or run automatic dependency/firewall setup.
