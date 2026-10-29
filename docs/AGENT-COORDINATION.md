# Agent coordination

**Two agents work on this repository for the maintainer: Codex on the maintainer's
computers and Claude in cloud sessions. Each owns separate domains. GitHub is the
shared board, because neither can see the other's working folder.**

Both agents follow [AGENTS.md](../AGENTS.md) and [CONTRIBUTING.md](../CONTRIBUTING.md)
like any other contributor. The maintainer reviews and merges every change.

## Where each agent works

| Agent | Works in | Never does |
| --- | --- | --- |
| Codex | `~/Projects/omaconnect-kde-plus` on the maintainer's computers. Owns installs, `omarchy plugin` commands, private metadata, native QML runs and phone or device checks. | Merges its own PRs or pushes to `main`. |
| Claude | Cloud sessions against the GitHub repository. Opens draft PRs from session branches. | Writes on the maintainer's computers, installs, runs native or device checks, merges, tags or posts outside the repository without the maintainer's go. |

## Local workspace

- The canonical development clone on each of the maintainer's computers is
  `~/Projects/omaconnect-kde-plus`. Develop, run tests and keep branches there.
- Directories under `~/.config/omarchy/plugins/` are installs, not workspaces.
  Do not edit, commit or switch branches in them; update an install only through
  `omarchy plugin` after a change is merged.
- Release-proof copies, such as those under `~/.local/state/`, are evidence.
  Leave them unchanged.
- Before starting work, fetch and confirm the clone's `main` matches `origin/main`.

## Domain ownership

Domains follow the [domain map](2026-10-29-contribution-architecture.md#current-domain-map).

| Domain | Owner | Notes |
| --- | --- | --- |
| Host composition (`Service.qml`, `BarWidget.qml`, `Panel.qml`, `bridge/`) | Claude | Includes the controller/panel split. |
| File submission (transfer code, `TransferModel.js`, `send_text.py`, `private_sources.py`, `portal_files.py`, Send/Activity components) | Claude | |
| Release and repository (`manifest.json` version, `.github/`, labels, templates, release notes) | Claude prepares | Tags, releases and marketplace posts need the maintainer's go. |
| Appearance and local links | Codex | |
| Address hints and rediscovery | Codex | |
| Home access (BTH) | Codex | |
| Migration | Codex | |
| Native verification (`tests/NATIVE-QA.md`, receipts in `docs/VERIFICATION.md`) | Codex | Only Codex can produce device evidence. |
| KDE devices and actions (`KdeConnectController.qml`, `ActionCatalog.js`, device/media/action components) | Shared, lock required | Split ownership after the controller split lands. |

**Shared files, lock required:** `KdeConnectController.qml`, `Panel.qml`,
`Service.qml`, `manifest.json`, `ActionCatalog.js`, `scripts/validate.sh`,
`AGENTS.md`, `CONTRIBUTING.md`, `docs/HELP.md`, `docs/CONTRACTS.md`,
`.github/workflows/`.

Upstream-owned files need the extra care described in [AGENTS.md](../AGENTS.md),
whoever owns their domain.

## Branches and pull requests

- Codex branches: `codex/<domain>/<topic>`. Claude branches keep their session
  name; the domain goes in the PR title.
- PR title: `[<domain>] <outcome>`. Domains: `host`, `kde`, `transfer`,
  `appearance`, `discovery`, `home-access`, `migration`, `release`, `native-qa`.
- One domain per PR. List any shared file under **Shared files touched** in the
  PR body.
- Base every PR on `main`. Do not stack one agent's PR on another agent's branch.
- Only a `[release]` PR changes the `manifest.json` version.

## Locks and handoffs

1. **Claim:** open a draft PR when work starts. An open draft PR locks its domain
   and the shared files it lists.
2. **Check:** before editing, list open PRs. If another agent's PR lists a file
   you need, wait or ask the maintainer.
3. **Hand off:** comment `HANDOFF to <codex|claude>` with state, last commit,
   checks run and next step. The receiver replies `ACCEPTED` before pushing.
4. **Release:** the lock ends when the PR merges or closes. Rebase on `main`
   before the next change.
5. **Freeze:** announce a structural change to a shared file, such as the
   controller split, on its draft PR. Nobody else edits that file until it merges.
