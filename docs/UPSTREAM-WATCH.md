# Upstream watch

**Use one review queue to notice upstream changes. A maintainer decides what belongs in Plus.** The watcher uses GitHub Actions, Python's standard library and public APIs. It needs no paid review service, new dependency, personal access token or upstream account.

The scheduled job uses the standard Ubuntu runner. Check [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) before changing repository visibility or runner type. Public metadata access can still be rate-limited or blocked.

## Sources and decisions

| Source | Fixed official API | What the watcher checks |
| --- | --- | --- |
| [KDE Connect desktop](https://invent.kde.org/network/kdeconnect-kde) | `https://invent.kde.org/api/v4/projects/network%2Fkdeconnect-kde` | Default-branch head, tags, releases and changed-file comparison |
| [KDE Connect Android](https://invent.kde.org/network/kdeconnect-android) | `https://invent.kde.org/api/v4/projects/network%2Fkdeconnect-android` | Default-branch head, tags, releases and changed-file comparison |
| [Original OmaConnect](https://github.com/jitendradara12/omaconnect) | `https://api.github.com/repos/jitendradara12/omaconnect` | The same metadata, plus the latest 100 updated PRs and relevant changed paths |

All new release records and tag changes enter the queue. A tag is not proof of a stable release. Code comparisons and original OmaConnect PRs enter the queue when paths or commit summaries match a small set of review areas: **security/privacy, protocol/discovery, API/capabilities and native plugins**. Authentication keywords use word boundaries, so `Co-authored-by` does not become a security alert. Pairing matches a word prefix, so `repair` does not become a pairing alert. The match publishes a static category, not the source text. This filter can miss a change or include an irrelevant change. It is a triage aid, not a vulnerability feed or security scan.

The watcher does not merge code, open automatic port PRs, install software, update a transfer engine, read local device state or contact a phone/router. Existing [Dependabot configuration](../.github/dependabot.yml) handles supported dependency update PRs. Keep dependency updates separate from native provider compatibility decisions.

For each relevant row:

1. Open the fixed upstream evidence link.
2. Compare the change with current Plus behavior and [the dated upstream audit](UPSTREAM-REVIEW.md). Confirm that the work is still absent.
3. Check the owning domain. KDE Connect owns native capabilities; the existing network controller owns policy.
4. Open a focused issue or PR for a confirmed need. Credit the upstream source. Include the smallest meaningful regression check.

## Enable and run

The workflow file is [upstream-watch.yml](../.github/workflows/upstream-watch.yml). Scheduled workflows must be present on the default branch. GitHub can delay schedules, and it can disable schedules in inactive public repositories. See [scheduled workflow behavior](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).

1. Ensure the labels **`upstream`** and **`triage`** exist. Repository maintainers own label setup.
2. In **Actions → Upstream watch → Run workflow**, keep **dry_run** enabled for the first check. Review the source statuses in the job log.
3. Run it once with **dry_run disabled**. This creates one issue, **Upstream watch: KDE Connect and OmaConnect**, and one marked bot comment. The first successful observation of each source sets its baseline. It does not import its historical changes.
4. Set the Actions repository variable **`UPSTREAM_WATCH_ENABLED`** to **`true`** to enable daily checks at **07:23 UTC**. The setting lives in **Settings → Secrets and variables → Actions → Variables**. A manual run does not require this variable.

Set that variable to `false` to pause scheduled checks. The manual default remains read-only. The repository's `GITHUB_TOKEN` has only `contents: read` and `issues: write`; checkout does not persist Git credentials. The job has a five-minute limit and a single concurrency group. It does not run on pull requests and does not use `pull_request_target`.

For a local read-only check, use:

```sh
python3 .github/upstream_watch.py --dry-run --repository OWNER/REPOSITORY
```

Replace `OWNER/REPOSITORY` with this repository's GitHub route. A public read-only run can work without a token, subject to the unauthenticated API rate limit. `--apply` is accepted only in a scheduled or manual GitHub Actions environment with `GITHUB_TOKEN`. Do not add credentials to a command, issue, log or configuration file.

## One issue, quiet updates

The issue body begins with an exact automation marker and must belong to `github-actions[bot]`. The watcher leaves that body and human comments unchanged. It stores public baseline data and the latest **24 evidence rows** in a separate bot-owned comment. Only its exact marked region is replaced; text outside the region is preserved.

The public state contains source SHAs, safe tag names, PR IDs/update timestamps, source status and evidence categories. Base64 encoding in an HTML comment keeps the state compact; it is **not encryption** and contains no secrets. Tag evidence links point to the observed commit SHA. Code comparisons use fixed official source roots and validated SHAs; PR links identify the observed head commit. No upstream titles, bodies, API-provided URLs, HTML or mention text are copied into posts.

An unchanged snapshot produces no write. A source failure changes its durable status once. Repeated identical failures do not create daily issues or repeat the status edit. Recovery resumes from the last good baseline; a source that has never been reachable gets its first baseline on recovery. The watcher reopens its closed queue only when the stored queue changes.

Older evidence rows rotate out after 24 rows. Review important work into a focused human issue before it rotates out. Previous edits remain accessible through GitHub's comment edit history while the comment exists. Do not use this rolling queue as a permanent security-finding register.

## Missing coverage and recovery

**Unavailable is not up to date.** HTTP/WAF/rate-limit failures, a non-JSON response or malformed metadata leave the affected source's last good baseline intact. The queue shows a fixed error code and no current coverage claim. Other reachable sources can still advance. A comparison that exceeds its response or classification limit is handled separately: the queue records the validated old/new heads as a **coverage gap** and advances to the newly observed head. This preserves the missed range for manual review and lets later small changes resume. It does not claim the skipped comparison was inspected.

An apply run that successfully stores this unavailable status can complete successfully: the durable warning is the result. It emits a workflow warning when the queue first changes. A repeated identical failure stays quiet. A dry-run returns nonzero if any upstream source cannot be checked. Target GitHub read/write failures, ambiguous owned markers or corrupt stored state fail the job without overwriting arbitrary content.

| Bound or condition | Behavior / maintainer action |
| --- | --- |
| 1 MiB per API response; 12 seconds per request; 150 seconds total HTTP budget | Stop reading an oversized response. An oversized **comparison** becomes a coverage-gap row with its validated old/new heads; other oversized API responses keep the previous baseline and mark that source unavailable. Timeouts remain unavailable. Response bodies and request details are not logged. |
| Tags and releases: latest 20 records per source | New observed records are compared with the previous bounded feed. A long outage can miss records that have rotated out. Inspect the official release/tag list after an outage. |
| Original OmaConnect PRs: latest 100 updated records; at most 8 changed PR file requests per run | A larger changed-PR batch stops that source with `pull-review-limit`. Review it manually before setting a fresh baseline. It does not silently skip the batch. |
| Comparison paths/commits and API truncation flags | Known truncation, GitLab timeout/collapsed diffs or divergent GitHub history adds an explicit **coverage gap** evidence row. For valid GitLab responses, every list entry is type-checked before classification is capped at the first 100 commit summaries and 300 diff records. A larger valid list advances the baseline with a gap; malformed entries, including those beyond the cap, still fail and preserve the prior baseline. Remote APIs can have other undocumented limits; this is not exhaustive monitoring. |
| Safe tag grammar | Tags outside ASCII letters/digits plus `.`, `_`, `+`, `-` are rejected as `unsupported-tag`. Inspect the official tag and adapt the parser deliberately. Do not bypass validation with raw remote text. |
| Issue/comment lookup: 10 pages of 100 each | Refuse creation if the lookup cannot be exhausted. This avoids creating a duplicate after a partial search. Duplicate bot markers or corrupt state require maintainer review. |
| Stored state exceeds its bounded comment capacity | Fail with `state-capacity`. A maintainer must review/compact the public state before retrying. No partial comment is posted. |

To reset a stuck baseline, first review and copy any still-actionable evidence to normal issues. A repository maintainer can then delete **only the dedicated bot state comment** and run the watcher manually. The next apply run creates a fresh baseline comment in the same marked issue; it does not replay history. Deleting that comment removes its edit history, so preserve required evidence first. Do not delete the issue marker or edit arbitrary source records to force a green run.

The APIs and limits are declared in [upstream_watch.py](../.github/upstream_watch.py). Its JSON state format is versioned and validated before rendering. This small internal polling tool does not expose a server API. Keep its fixed source adapters and issue ownership checks explicit.

## Validation and feedback

Run the focused fake-HTTP suite with:

```sh
python3 -m unittest discover -s tests -p test_upstream_watch.py -v
```

The suite covers baselines, deduplication, scoped writes, malformed/oversized/WAF responses, token routing, remote-text injection, ownership, pagination and coverage gaps. Tests make no real network request or GitHub write. The 29 October 2026 read-only live dry-run returned `desktop=ok, android=ok, omaconnect=ok`. This verifies those public metadata reads at that time. The first real Actions apply, issue creation, schedule and later change detection still need a repository receipt after merge.

Use **Experience feedback** for a concrete task, what helped/blocked it and one useful next result. The form requests no private configuration. Use **Discussions** for open questions and ideas, a bug issue for reproducible failures, and the private route in [SECURITY.md](../SECURITY.md) for security concerns. Maintainers enable Discussions and own its categories; this watcher does not create discussion posts or send cross-service messages.
