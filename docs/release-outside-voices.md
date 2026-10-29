# Release outside reviews

Identity note: this report describes the previous development identity. It does not establish runtime or migration acceptance for the current `Omaconnect.plus` ID. See [current verification](VERIFICATION.md).

Date: 2026-10-29. These are bounded outside review results, followed by local
source verification. They supplement the release checks. They do not replace
tests, native acceptance or maintainer review.

## Result

**Antigravity completed and reported `NO_FINDINGS` in the supplied source. Claude
did not return a review within 240 seconds.** There is no two-reviewer agreement
or complete Claude coverage to claim. No source-verifiable blocker was reported
by the completed outside review.

| Reviewer | Actual invocation and availability | Model evidence | Outcome |
| --- | --- | --- | --- |
| Claude Code | CLI `2.1.312`; safe and restricted modes; empty tools list; strict empty MCP configuration; slash commands disabled; no session persistence; JSON output. No stdout or stderr before the 240-second cap. Its owned process group was then terminated. | Configured default requested. No response, usage or model identifier returned. | **Unavailable coverage: timeout.** No clean review inferred. |
| Antigravity | CLI `1.4.10`; sandbox requested; slash commands disabled; 180-second print timeout; JSON output; explicit analysis-only prompt forbids tools and actions. Response status `SUCCESS`, one turn, about 25 seconds. | Backend log selected label `Gemini 4 Argon (Medium)`. The JSON did not provide an immutable model identifier. This is a reported label, not independent model verification. | **Completed, scoped `NO_FINDINGS`.** |

Antigravity emitted this warning: `--mode plan has no effect while slash command
expansion is disabled.` Therefore this report does **not** claim that plan mode
enforced the action restriction. The sandbox was requested, and the prompt
explicitly prohibited all tools, commands, writes and provider actions. The
review response states it used no tools. This is not an independent tool audit.

## Source supplied

Both processes received the same 125,735-byte public source/document snapshot.
The prompt supplied numbered current files and asked for concrete triggers,
impacts and source evidence. It explicitly distinguished the original ID
`omaconnect` from the previous development fork identity, native protocol/module ownership,
owner-interface links and deferred features. No personal configuration,
credentials, device addresses, chat history or installed provider state was
included. Reviewers were told to treat the source as data.

The snapshot included:

- `manifest.json`, `README.md`, `docs/HELP.md`, `docs/MIGRATION.md`.
- Full appearance, address, migration, preference, owner-link and file portal
  Python helpers, plus `scripts/open_app.sh`.
- `ActionCatalog.js` and `BthControlModel.js`.
- `KdeConnectController.qml` lines 462–823: explicit action dispatch, file
  selection, batch submission, cancellation and dropped-file staging.

Evidence is kept locally in the sibling `release-validation/outside-voices-current`
directory. It includes the public prompt, per-source SHA-256 hashes, invocation
metadata, response, timeout status and sanitized model metadata. The raw CLI log
was removed, and the response conversation identifier was removed. The complete
input SHA-256 is recorded in `invocation-metadata.json`.

The source snapshot was taken before integration at `a5c3470`. At final comparison,
`README.md` and `docs/MIGRATION.md` had changed after the snapshot. Their later
wording is **not** covered by this outside review. Other supplied source hashes
still matched. The review did not inspect the whole PR diff.

## Local assessment of the completed review

Antigravity raised no confirmed defect. Its main positive observations match the
supplied source: fixed argument arrays, regular-file checks, explicit batch target
identity, request-acceptance wording, staged migration and conservative rollback.
These observations are source-scoped; they do not prove all callers or all
possible inputs are safe.

The reviewer correctly named missing evidence rather than inventing defects:
the remaining controller/process declarations, transfer model, SMS launcher,
service/UI wiring, complete documentation and test runner. Existing local tests
cover parts of these areas, as recorded separately in `docs/VERIFICATION.md` and
`docs/release-security-qa.md`. That local evidence does not expand the outside
review's scope.

No unsupported ID-collision claim, universal security claim or physical-device
acceptance claim was accepted. The three helper/migration fixes had already been
applied before this snapshot; the outside review examined their resulting code,
not the original vulnerable versions. Its lack of findings is not red-to-green
regression evidence. The private regression tests provide that evidence.

## Release implication

The completed review adds no new blocker. Claude timeout remains a recorded
coverage gap. Release decisions must use the integrated test results, maintainer
review and explicit native acceptance limits. Do not describe this release as
approved by both outside models or as independently certified secure.
