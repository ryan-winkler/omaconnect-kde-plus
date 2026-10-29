# Contributor and release checks

Date: 2026-10-29. Public name: **Omaconnect KDE Plus**. Stable plugin ID: **`ryan.omaconnect`**. Canonical repository: [ryan-winkler/omaconnect-kde-plus](https://github.com/ryan-winkler/omaconnect-kde-plus).

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

- [x] Renamed the existing public fork to `ryan-winkler/omaconnect-kde-plus`; retained upstream history. The stable plugin ID remains `ryan.omaconnect`. No pairing or provider migration is part of this rename.
- [x] Enabled Issues and Discussions. Applied the 16 label definitions additively and set repository topics.
- [x] Enabled private vulnerability reporting. The security policy includes the maintainer email fallback.
- [ ] Open the advisory route without submitting a report and confirm its live public entry point after publication.
- [x] Enabled Dependabot alerts, secret scanning and push protection for the public repository.
- [ ] Check whether default CodeQL setup is active before using the supplied advanced workflow; choose one setup and avoid duplicate scans.
- [ ] Install or grant the official CodeRabbit GitHub app access to this repository. Confirm the organization/account's public-repository plan. Do not buy a plan to complete this release.
- [ ] Open a real pull request after app access is set. Confirm a CodeRabbit review and configuration acceptance. If needed, comment `@coderabbitai review` on that PR. Record a link and outcome.
- [ ] Confirm Functional checks and both CodeQL jobs run successfully on the actual release revision. Inspect any skip or warning. Add required branch checks only after the actual check names exist.
- [ ] Confirm the issue chooser, forms, private security route, contributor links and release notes configuration work on GitHub after the rename.
- [ ] Complete separately authorized installed-desktop and device checks. Report ARM, x86, fixture, physical receipt, keyboard and assistive-technology evidence separately.
- [ ] Publish the reviewed version and source revision only after release gates pass. Automatic release notes can use `.github/release.yml`; they do not replace current known limits.

The GitHub CLI token available during preparation could not list user GitHub App installations (`GET /user/installations` returned 403). That is a token-capability limit, not proof that CodeRabbit is missing. An authorized browser/admin check or actual PR review is needed.

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
