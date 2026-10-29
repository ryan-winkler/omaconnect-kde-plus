# Security policy

## Report a vulnerability privately

Use [GitHub private vulnerability reporting](https://github.com/ryan-winkler/omaconnect-kde-plus/security/advisories/new). If that form is unavailable, email the maintainer at **hi@ryanw.eu** with the subject **Omaconnect KDE Plus security report**. Do not open a public issue with an exploit, credential or personal configuration.

Include the affected version, a short description, impact and safe reproduction steps. Use invented device names and owned test files. Do not send VPN private keys, pairing material, passwords, tokens, raw configuration directories or personal file contents. Ask for a secure exchange method if sensitive evidence is necessary.

We acknowledge reports as maintainer capacity allows. We will agree on a disclosure plan with the reporter where possible. This small project does not promise a response deadline or a paid bounty.

## Scope and supported code

This project is in early release. Report issues against the latest published release or current default branch. Maintainers assess older versions case by case; there is no long-term-support branch.

Relevant surfaces include local helper execution, device and file input, icon imports, private state, settings writes, address approvals and documentation that could cause an unsafe action. A passing test does not establish that every desktop, device or network is safe.

KDE Connect owns its protocol and pairing. Tailscale, WireGuard, the existing Back to Home controller and Syncshell own their policy and keys. Report defects in those components to their maintainers. If the boundary is unclear, contact this project's maintainer first without posting private data.

## Contribute a security fix

Discuss a private vulnerability before publishing a patch that reveals it. Use fixed argument arrays, bounded I/O, private atomic state and explicit user actions. Add a focused fixture with invented data. Keep the protocol, trust and local appearance boundaries intact. Read [contribution guidance](CONTRIBUTING.md) and [contracts](docs/CONTRACTS.md).

Private reporting must be enabled in GitHub repository settings. This document alone does not enable that service. The maintainer setup checklist is in [the release plan](docs/contributor-release-plan.md).
