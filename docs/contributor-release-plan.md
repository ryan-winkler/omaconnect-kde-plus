# Contributor and release checks

Date: 2026-10-29. Public name: **Omaconnect KDE Plus**. Stable plugin ID: **`Omaconnect.plus`**. Canonical repository: [ryan-winkler/omaconnect-kde-plus](https://github.com/ryan-winkler/omaconnect-kde-plus).

**Repository files prepare the process. GitHub settings and a real run prove that a service works.** Do not describe an app, scan or branch rule as enabled because its configuration exists.

## Contributor routes

| Need | Surface |
| --- | --- |
| Find a small task or domain owner | [Contribution guide](../CONTRIBUTING.md), [CODEOWNERS](../.github/CODEOWNERS) |
| Report a defect, idea, barrier or question | [Issue forms](../.github/ISSUE_TEMPLATE/) |
| Report a vulnerability privately | [Security policy](../SECURITY.md); private GitHub reporting or maintainer email |
| Explain a change and its evidence | [PR template](../.github/PULL_REQUEST_TEMPLATE.md) |
| Ask for support or report conduct | [Support](../SUPPORT.md), [code of conduct](../CODE_OF_CONDUCT.md) |
| Keep triage consistent | [Label definitions](../.github/labels.json); apply without deleting unrelated labels |

No external DCO service is required. Encourage sign-off for new contributions after the author reads DCO 1.1. Do not rewrite upstream history to add sign-offs. Keep useful first tasks small, with an entry point and acceptance check. Contributors can ask for help without disclosing a diagnosis or private state.

## Checks supplied in this repository

| Check | What it establishes | Limits |
| --- | --- | --- |
| Functional checks | Existing Python fixtures, JS models and shell syntax run under private temporary state. | Hosted Ubuntu needs `python3-gi`, D-Bus, Node and ripgrep. Native prerequisites can be absent. |
| Local documentation links | Inline Markdown links target files inside the repository. | Does not check remote URL availability, heading anchors, reference-style links or historical source line numbers. |
| Native manifest validator in `validate.sh` | Validates the plugin manifest with the actual Omarchy tool **when installed**. | An unavailable tool is an explicit skip. Do not substitute a guessed schema or call the skip a pass. |
| QML checks in `validate.sh` | Uses available native tooling and reports its diagnostics. | Hosted CI is not an installed Omarchy shell or proof of focus, screen-reader use or device acceptance. |
| CodeQL | Intended hosted analysis of Python helpers and GitHub Actions workflows. | Does not analyze QML as a supported language or prove correct provider behavior. First hosted results must be reviewed. |
| Dependabot | Monthly update proposals for pinned GitHub Actions. | No npm, Cargo or container dependency graph is invented for this project. Review each proposed SHA update. |
| CodeRabbit | Additional English review with project-specific safety, domain and accessibility instructions. | Requires the GitHub app and repository access. Availability and output depend on the service. It is not a security or native QA guarantee. |

Workflows use verified full commit SHAs, read-only checkout credentials, bounded jobs and normal `pull_request` events. CodeQL grants `security-events: write` only to its analysis job. No workflow publishes a release or changes a desktop. Check actual status names after the first run before configuring required branch checks.

The local link gate deliberately makes no network calls from untrusted pull requests. Review new external links directly and check official support links during a release. A missing or blocked remote check must remain open; a local link pass is not external availability evidence.

## Preparation evidence

These checks ran locally on 2026-10-29:

- CodeRabbit YAML validated against the then-current official JSON schema. All added YAML files parsed.
- Actionlint `v1.7.12` accepted both workflows. ShellCheck was unavailable for that local command; no ShellCheck pass is claimed.
- Zizmor accepted both workflows in offline auditor mode with no findings after permission comments and job names were added.
- The link-checker fixture covered spaces, code fences, external URLs, missing files and paths outside the repository. It produced the expected results.

The full functional suite, GitHub workflow results, live app review and installed-device acceptance remain the release task's responsibility. A parser or local tool pass does not establish those results.

## Maintainer setup and first-run evidence

Checked items record administrative actions confirmed by the release task on 2026-10-29. Unchecked items still need live evidence; repository configuration alone does not complete them.

- [x] Renamed the existing public fork to `ryan-winkler/omaconnect-kde-plus`; retained upstream history. That rename preserved the previous development ID. The later technical identity update selects `Omaconnect.plus`; its migration/readback is a separate gate.
- [x] Enabled Issues and Discussions. Applied the 16 label definitions additively and set repository topics.
- [x] Enabled private vulnerability reporting. The security policy includes the maintainer email fallback.
- [ ] Open the advisory route without submitting a report and confirm its live public entry point after publication.
- [x] Enabled Dependabot alerts, secret scanning and push protection for the public repository. Automated security-fix PRs are now enabled and not paused, confirmed by live API readback.
- [x] Live API readback confirms default CodeQL is not configured. The supplied advanced workflow is the only configured CodeQL scan path.
- [x] Owner confirms the official CodeRabbit GitHub app is enabled for this repository. The public-repository offer is the documented free route; no purchase is authorized or needed.
- [x] Observed CodeRabbit `COMMENTED` [review on PR #3](https://github.com/ryan-winkler/omaconnect-kde-plus/pull/3#pullrequestreview-5703659944) at `b6860b9`. It used repository YAML and raised one minor G5 wording issue; the documentation now distinguishes pre-Send acceptance from untested post-drop Send. This review does not cover the later identity/security changes.
- [x] Confirm Functional checks and both CodeQL jobs run on preparation revision `a5c3470`: all passed. Inspect native skips. Required branch checks and final release revision are recorded separately.
- [ ] Confirm the issue chooser, forms, private security route, contributor links and release notes configuration work on GitHub after the rename.
- [x] Updated and verified the earlier published revision under the previous development identity on ARM and x86 comparison installs. [Current verification](VERIFICATION.md) keeps mapped UI, fixtures, physical receipt and open AT/drag/away checks separate.
- [x] Published the earlier reviewed `v0.1.0` at `256d50c` under the previous development identity. Release notes record actual checks and open acceptance limits. [Marketplace submission](https://github.com/omacom/omarchy-plugin-marketplace/issues/13289) is open; maintainer review is separate.

The GitHub CLI token available during preparation could not list user GitHub App installations (`GET /user/installations` returned 403). That is a token-capability limit, not proof that CodeRabbit is missing. The observed PR #3 review now proves scoped app activity; this API limit still does not reveal every account installation.

## Fasti patterns and source decisions

The requested comparison was [Scrobble-dev/Fasti](https://github.com/Scrobble-dev/Fasti), default branch `dev`, inspected on 2026-10-29. Its [contribution guide](https://github.com/Scrobble-dev/Fasti/blob/dev/CONTRIBUTING.md), [CodeRabbit configuration](https://github.com/Scrobble-dev/Fasti/blob/dev/.coderabbit.yaml), [issue setup](https://github.com/Scrobble-dev/Fasti/tree/dev/.github/ISSUE_TEMPLATE), [security policy](https://github.com/Scrobble-dev/Fasti/blob/dev/SECURITY.md) and [security workflow](https://github.com/Scrobble-dev/Fasti/blob/dev/.github/workflows/security.yml) provided the comparison.

Adopted patterns: welcome non-code work, state ownership, keep PRs small, use task-based forms, route vulnerabilities privately, use clear labels, keep automated review advisory, pin actions and limit token permissions. Adapted DCO guidance remains lightweight. This project does not copy Fasti's Rust/npm audits, importer domains, commercial claims, organizational teams or larger governance process. Those do not match this repository.

Official sources checked during preparation:

- [CodeRabbit pricing](https://www.coderabbit.ai/pricing): the public-repository open-source offer is free. Repository app access is still required.
- [CodeRabbit setup](https://docs.coderabbit.ai/getting-started/quickstart) and [automatic review](https://docs.coderabbit.ai/configuration/auto-review): app access, default-branch targeting and review behavior.
- [CodeRabbit configuration schema](https://coderabbit.ai/integrations/schema.v2.json): accepted config fields; `enable_free_tier` does not enroll a repository by itself.
- [GitHub private reporting](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/privately-reporting-a-security-vulnerability): a repository must enable private reporting.
- [CodeQL action](https://github.com/github/codeql-action): supported scan setup, permissions and interpreted-language build mode.
- [Actions checkout](https://github.com/actions/checkout): official checkout action. The v7 ref was verified as `3d3c42e5aac5ba805825da76410c181273ba90b1`; the CodeQL v4 annotated tag resolved to `9b3254085494b55a0f7c4c2b3d2d52cc712ce370`.

These service details can change. Recheck them at a later release rather than treating this dated inspection as a permanent service guarantee.


Live setup receipt: main now requires the observed Functional, Analyze Python and
Analyze Actions checks, PRs and conversation resolution. Main’s actual release
checks passed `256d50c`; force pushes and branch deletion are disabled. CodeRabbit
app access is owner-confirmed and the scoped PR #3 review is observed. Its metadata reports the existing account tier as Advanced; no purchase or plan change was made for this release. See [current verification](VERIFICATION.md).


## Current 0.2.0 identity-update gates

- [ ] Validate the exact `Omaconnect.plus` ID across manifest, IPC, preferences, metadata paths, examples and migration. Historical receipts remain labelled with their prior scope.
- [ ] Review removal of inherited privileged setup entry points. Manual prerequisite guidance uses supported Omarchy commands; the fork must not keep a hidden installer/firewall execution path.
- [ ] Run final source checks and actual hosted scans on the identity/security revision. Preserve the real scanner results and limits.
- [ ] Obtain installed new-ID readback separately for ARM and x86 without losing previous appearance, address records or provider settings.
- [ ] Publish the new revision and update marketplace identity only after their own gates pass. The earlier release/catalog submission does not establish the new ID.

## Fasti comparison

The owner's [Fasti contribution guide](https://github.com/Scrobble-dev/Fasti/blob/main/CONTRIBUTING.md),
[issue routes](https://github.com/Scrobble-dev/Fasti/blob/main/.github/ISSUE_TEMPLATE/config.yml)
and contributor-task form were inspected live on 29 October 2026. Plus adopts the
useful pattern: welcome different contributor skills, route questions to
Discussions and vulnerabilities privately, label bounded work, ask for outcome/
owner/acceptance evidence, preserve DCO/source credit, and link related upstream
work. The new task form enters triage; it does not claim every submission is
contributor-ready. Maintainers choose good-first-issue scope after review.

Fasti's media identity rules, YouTrack references, AGPL terms, Rust/Cargo monorepo,
contract generators and development/release branch gates are specific to Fasti.
They are not copied into this small MIT-licensed native UI fork. Plus retains its
existing domain helpers, native owner routes and isolated validation command.
