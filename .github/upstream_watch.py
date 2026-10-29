#!/usr/bin/env python3
"""Watch fixed public upstreams. Store a baseline in one owned GitHub comment."""

import argparse
import base64
import copy
import json
import os
import re
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ISSUE_MARKER = "<!-- omaconnect-upstream-watch:issue:v1 -->"
COMMENT_MARKER = "<!-- omaconnect-upstream-watch:comment:v1 -->"
START = "<!-- omaconnect-upstream-watch:start:v1 -->"
END = "<!-- omaconnect-upstream-watch:end:v1 -->"
STATE_RE = re.compile(r"<!-- omaconnect-upstream-watch:state:v1 ([A-Za-z0-9+/=]+) -->")
BOT = "github-actions[bot]"
TITLE = "Upstream watch: KDE Connect and OmaConnect"
MAX_BYTES = 1024 * 1024
MAX_STATE = 42000
MAX_EVENTS = 24
SHA_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?\Z")
TAG_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+-]{0,79}\Z")
REPO_RE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")
SOURCES = {
    "desktop": ("KDE Connect desktop", "gitlab", "network/kdeconnect-kde"),
    "android": ("KDE Connect Android", "gitlab", "network/kdeconnect-android"),
    "omaconnect": ("Original OmaConnect", "github", "jitendradara12/omaconnect"),
}
TOPICS = {
    "security/privacy": r"secur|vulnerab|\bcve\b|certificat|\btls\b|\bssl\b|encrypt|\b(?:un)?authenticat|\bauthori[sz]|\bauth\b|\bpair|permiss|privacy|saniti|escap",
    "protocol/discovery": r"protocol|packet|payload|networkpackage|lanlink|discovery|wireguard|tailscale|\budp\b|\btcp\b",
    "API/capabilities": r"dbus|d-bus|interface|capabilit|kdeconnect-cli|service|deviceaction|actioncatalog|discover_devices|manifest\.json|(^|/)(core|daemon)/",
    "native plugins": r"plugin|share|findmyphone|\bping\b|battery|sms|clipboard|mpris|notification|runcommand|remotecommands|sftp|systemvolume",
}


class WatchError(Exception):
    """Only a fixed, safe status code crosses the output boundary."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Client:
    def __init__(self, repository, token="", opener=None):
        if not REPO_RE.fullmatch(repository) or ".." in repository:
            raise WatchError("invalid-repository")
        self.repository = repository
        self.token = token
        self.opener = opener or urllib.request.build_opener(NoRedirect)
        self.deadline = time.monotonic() + 150

    def request(self, host, path, query=None, method="GET", data=None):
        if host not in {"api.github.com", "invent.kde.org"}:
            raise WatchError("invalid-endpoint")
        # Paths are constructed below from constants and validated IDs, never API URLs.
        if not path.startswith("/") or any(c in path for c in "\r\n?#"):
            raise WatchError("invalid-endpoint")
        if method != "GET" and not (
            host == "api.github.com" and path.startswith(f"/repos/{self.repository}/issues")
        ):
            raise WatchError("invalid-write-endpoint")
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise WatchError("deadline")
        url = "https://" + host + path
        if query:
            url += "?" + urllib.parse.urlencode(query)
        headers = {"Accept": "application/json", "User-Agent": "Omaconnect.plus-upstream-watch/1"}
        if host == "api.github.com":
            headers["X-GitHub-Api-Version"] = "2022-11-28"
            if self.token:
                headers["Authorization"] = "Bearer " + self.token
        payload = None if data is None else json.dumps(data, ensure_ascii=True).encode("utf-8")
        if payload is not None:
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=payload, headers=headers, method=method)
        try:
            with self.opener.open(req, timeout=min(12, remaining)) as response:
                content_type = response.headers.get("Content-Type", "").split(";", 1)[0].lower()
                if content_type not in {"application/json", "application/vnd.github+json"}:
                    raise WatchError("non-json-response")
                raw = response.read(MAX_BYTES + 1)
        except urllib.error.HTTPError as exc:
            code = exc.code
            exc.close()
            raise WatchError(f"http-{code}") from None
        except (TimeoutError, socket.timeout):
            raise WatchError("timeout") from None
        except (urllib.error.URLError, OSError):
            raise WatchError("network-unavailable") from None
        if len(raw) > MAX_BYTES:
            raise WatchError("oversized-response")
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeError, ValueError, RecursionError):
            raise WatchError("invalid-json") from None

    def github(self, path, **kwargs):
        return self.request("api.github.com", path, **kwargs)


def array(value, limit=100):
    if not isinstance(value, list) or (limit is not None and len(value) > limit) or any(not isinstance(x, dict) for x in value):
        raise WatchError("invalid-payload")
    return value


def sha(value):
    if not isinstance(value, str) or not SHA_RE.fullmatch(value):
        raise WatchError("invalid-sha")
    return value


def tag(value):
    if not isinstance(value, str) or not TAG_RE.fullmatch(value):
        raise WatchError("unsupported-tag")
    return value


def number(value):
    if type(value) is not int or not 0 < value < 10**12:
        raise WatchError("invalid-id")
    return value


def topics(strings):
    text = "\n".join(s[:2000] for s in strings if isinstance(s, str)).lower()
    return [name for name, pattern in TOPICS.items() if re.search(pattern, text)]


def file_paths(files, keys):
    paths = []
    for item in files:
        for key in keys:
            value = item.get(key)
            if not isinstance(value, str) or len(value) > 1024 or any(ord(c) < 32 for c in value):
                raise WatchError("invalid-payload")
            paths.append(value)
    return paths


def base_path(source):
    _, kind, project = SOURCES[source]
    if kind == "github":
        return f"/repos/{project}", kind
    return "/api/v4/projects/" + urllib.parse.quote(project, safe=""), kind


def read_snapshot(client, source):
    base, kind = base_path(source)
    host = "api.github.com" if kind == "github" else "invent.kde.org"
    commits = array(client.request(host, base + ("/commits" if kind == "github" else "/repository/commits"), {"per_page": 1}), 1)
    if not commits:
        raise WatchError("missing-head")
    head = sha(commits[0].get("sha" if kind == "github" else "id"))
    tags = array(client.request(host, base + ("/tags" if kind == "github" else "/repository/tags"), {"per_page": 20}), 20)
    releases = array(client.request(host, base + "/releases", {"per_page": 20}), 20)
    snapshot = {"head": head, "tags": {}, "releases": [], "pulls": {}}
    for item in tags:
        name = tag(item.get("name"))
        commit = item.get("commit")
        if not isinstance(commit, dict):
            raise WatchError("invalid-payload")
        snapshot["tags"][name] = sha(commit.get("sha" if kind == "github" else "id"))
    for item in releases:
        if kind == "github" and item.get("draft"):
            continue
        snapshot["releases"].append(tag(item.get("tag_name")))
    if kind == "github":
        # The latest 100 updated PRs bound work; timestamp prevents old tail items becoming new alerts.
        pulls = array(client.request(host, base + "/pulls", {"state": "all", "sort": "updated", "direction": "desc", "per_page": 100}), 100)
        for item in pulls:
            ident = str(number(item.get("number")))
            head_data = item.get("head")
            updated = item.get("updated_at")
            if not isinstance(head_data, dict) or not isinstance(updated, str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", updated):
                raise WatchError("invalid-payload")
            snapshot["pulls"][ident] = {"head": sha(head_data.get("sha")), "updated": updated}
    return snapshot


def code_change(client, source, old, current):
    base, kind = base_path(source)
    previous, head = sha(old["head"]), sha(current["head"])
    host = "api.github.com" if kind == "github" else "invent.kde.org"
    path = base + "/compare/" + previous + "..." + head if kind == "github" else base + "/repository/compare"
    query = {"per_page": 100} if kind == "github" else {"from": previous, "to": head, "straight": "true"}
    try:
        result = client.request(host, path, query)
    except WatchError as error:
        if str(error) == "oversized-response":
            # The old/new heads came from validated metadata. Preserve the gap
            # for manual review, then advance so later small changes can resume.
            return event(source, "code", head, ["coverage gap"], previous)
        raise
    if kind == "github":
        if not isinstance(result, dict) or result.get("status") not in {"ahead", "identical", "behind", "diverged"}:
            raise WatchError("invalid-comparison")
        files, commits = array(result.get("files"), 300), array(result.get("commits"), 100)
        if type(result.get("total_commits")) is not int or result["total_commits"] < 0:
            raise WatchError("invalid-payload")
        incomplete = result["status"] in {"behind", "diverged"} or result["total_commits"] > len(commits) or len(files) == 300
        paths = file_paths(files, ["filename"])
        messages = []
        for commit in commits:
            metadata = commit.get("commit")
            if not isinstance(metadata, dict) or not isinstance(metadata.get("message"), str):
                raise WatchError("invalid-payload")
            messages.append(metadata["message"])
    else:
        if not isinstance(result, dict):
            raise WatchError("invalid-comparison")
        # GitLab can return larger lists. The transport already bounds JSON at
        # 1 MiB. Validate every entry before capping classification work.
        files, commits = array(result.get("diffs"), None), array(result.get("commits"), None)
        if type(result.get("compare_timeout", False)) is not bool:
            raise WatchError("invalid-payload")
        for item in files:
            if any(type(item.get(flag, False)) is not bool for flag in ("too_large", "collapsed")):
                raise WatchError("invalid-payload")
        incomplete = result.get("compare_timeout", False) or len(files) >= 300 or len(commits) >= 100 or any(f.get("too_large") or f.get("collapsed") for f in files)
        paths = file_paths(files, ["new_path", "old_path"])
        messages = []
        for commit in commits:
            if not isinstance(commit.get("title"), str):
                raise WatchError("invalid-payload")
            messages.append(commit["title"])
        paths, messages = paths[:600], messages[:100]
    found = topics(paths + messages)
    if incomplete:
        found.append("coverage gap")
    return event(source, "code", head, found, previous) if found else None


def event(source, kind, ident, found, previous=""):
    return {"source": source, "kind": kind, "id": ident, "topics": sorted(set(found)), "base": previous}


def update_source(client, source, old):
    current = read_snapshot(client, source)
    events = []
    if old.get("head"):
        for name, commit in current["tags"].items():
            if old["tags"].get(name) != commit:
                events.append(event(source, "tag", name, ["release/tag"], commit))
        for name in current["releases"]:
            if name not in old["releases"]:
                events.append(event(source, "release", name, ["release/tag"]))
        if current["head"] != old["head"]:
            evidence = code_change(client, source, old, current)
            if evidence:
                events.append(evidence)
        cutoff = max((p["updated"] for p in old.get("pulls", {}).values()), default="")
        changed = [(ident, value) for ident, value in current["pulls"].items() if value != old.get("pulls", {}).get(ident) and (ident in old.get("pulls", {}) or value["updated"] >= cutoff)]
        if len(changed) > 8:
            # Keep the old snapshot and surface bounded coverage honestly. A maintainer can rebaseline.
            raise WatchError("pull-review-limit")
        for ident, value in changed:
            base, _ = base_path(source)
            files = array(client.request("api.github.com", base + f"/pulls/{number(int(ident))}/files", {"per_page": 100}), 100)
            found = topics(file_paths(files, ["filename"]))
            if len(files) == 100:
                found.append("coverage gap")
            if found:
                events.append(event(source, "pull", ident + ":" + value["head"], found))
    current["status"] = "ok"
    return current, events


def empty_state():
    return {"version": 1, "sources": {}, "events": []}


def evolve(client, state):
    result = copy.deepcopy(state)
    for source in SOURCES:
        old = state["sources"].get(source, {})
        try:
            current, events = update_source(client, source, old)
            result["sources"][source] = current
            for item in events:
                # Stable source/kind/id/base evidence identity prevents duplicate rows.
                if item not in result["events"]:
                    result["events"].append(item)
            result["events"] = result["events"][-MAX_EVENTS:]
        except WatchError as exc:
            failed = copy.deepcopy(old)
            failed["status"] = str(exc)
            result["sources"][source] = failed
    return result


def validate_state(state):
    if not isinstance(state, dict) or set(state) != {"version", "sources", "events"} or state["version"] != 1 or not isinstance(state["sources"], dict) or set(state["sources"]) - set(SOURCES):
        raise WatchError("invalid-state")
    allowed_status = {"ok", "deadline", "timeout", "network-unavailable", "non-json-response", "oversized-response", "invalid-json", "invalid-payload", "invalid-sha", "unsupported-tag", "invalid-id", "missing-head", "invalid-comparison", "pull-review-limit"}
    for source, record in state["sources"].items():
        if not isinstance(record, dict) or set(record) - {"head", "tags", "releases", "pulls", "status"}:
            raise WatchError("invalid-state")
        status = record.get("status")
        if status not in allowed_status and not (isinstance(status, str) and re.fullmatch(r"http-[1-5][0-9]{2}", status)):
            raise WatchError("invalid-state")
        if "head" not in record:
            if set(record) != {"status"}:
                raise WatchError("invalid-state")
            continue
        sha(record["head"])
        tags, releases, pulls = record.get("tags"), record.get("releases"), record.get("pulls")
        if not isinstance(tags, dict) or len(tags) > 20 or not isinstance(releases, list) or len(releases) > 20 or not isinstance(pulls, dict) or len(pulls) > 100:
            raise WatchError("invalid-state")
        for name, commit in tags.items():
            tag(name)
            sha(commit)
        for name in releases:
            tag(name)
        for ident, pull in pulls.items():
            if not isinstance(ident, str) or not ident.isascii() or not ident.isdecimal() or str(number(int(ident))) != ident or not isinstance(pull, dict) or set(pull) != {"head", "updated"}:
                raise WatchError("invalid-state")
            sha(pull["head"])
            if not isinstance(pull["updated"], str) or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", pull["updated"]):
                raise WatchError("invalid-state")
    for item in array(state["events"], MAX_EVENTS):
        if set(item) != {"source", "kind", "id", "topics", "base"} or item["source"] not in SOURCES or item["kind"] not in {"code", "tag", "release", "pull"}:
            raise WatchError("invalid-state")
        found = item["topics"]
        if not isinstance(found, list) or len(found) > 6 or any(t not in {*TOPICS, "coverage gap", "release/tag"} for t in found):
            raise WatchError("invalid-state")
        if item["kind"] in {"tag", "release"}:
            tag(item["id"])
            if item["kind"] == "tag":
                sha(item["base"])
        elif item["kind"] == "code":
            sha(item["id"])
            sha(item["base"])
        else:
            if item["source"] != "omaconnect" or not isinstance(item["id"], str) or ":" not in item["id"]:
                raise WatchError("invalid-state")
            ident, commit = item["id"].split(":", 1)
            if not ident.isascii() or not ident.isdecimal() or str(number(int(ident))) != ident:
                raise WatchError("invalid-state")
            sha(commit)
        if item["kind"] in {"pull", "release"} and item["base"] != "":
            raise WatchError("invalid-state")
    return state


def evidence_link(item):
    _, kind, project = SOURCES[item["source"]]
    root = ("https://github.com/" if kind == "github" else "https://invent.kde.org/") + project
    ident = urllib.parse.quote(item["id"], safe="")
    if item["kind"] == "code":
        return root + ("/compare/" if kind == "github" else "/-/compare/") + item["base"] + "..." + item["id"]
    if item["kind"] == "pull":
        num, commit = item["id"].split(":", 1)
        return root + "/pull/" + num + "/commits/" + commit
    if item["kind"] == "release":
        return root + ("/releases/tag/" if kind == "github" else "/-/releases/") + ident
    return root + ("/commit/" if kind == "github" else "/-/commit/") + item["base"]


def render(state):
    validate_state(state)
    encoded = base64.b64encode(json.dumps(state, sort_keys=True, separators=(",", ":")).encode()).decode()
    if len(encoded) > MAX_STATE:
        raise WatchError("state-capacity")
    lines = [START, "## Upstream review queue", "", "One rolling queue. No code is merged, installed or executed by this watcher.", "", "| Source | Observation |", "| --- | --- |"]
    for source, (label, _, _) in SOURCES.items():
        record = state["sources"].get(source, {})
        status = record.get("status", "not-checked")
        text = "Baseline recorded; no historical import" if status == "ok" and not state["events"] else "Public metadata checked" if status == "ok" else "**Unavailable: " + status + "**; no current coverage claim"
        lines.append(f"| {label} | {text} |")
    lines += ["", "### Evidence for maintainer triage", ""]
    if not state["events"]:
        lines.append("No new relevant evidence recorded since this watch baseline. This is not a security audit or an all-clear.")
    else:
        lines += ["| Source | Evidence | Review area |", "| --- | --- | --- |"]
        for item in reversed(state["events"]):
            ident = item["id"][:12] if item["kind"] == "code" else item["id"].split(":", 1)[0]
            if item["kind"] == "tag":
                ident += " (" + item["base"][:8] + ")"
            label = f"{item['kind']} {ident}"
            lines.append(f"| {SOURCES[item['source']][0]} | [{label}]({evidence_link(item)}) | {', '.join(item['topics'])} |")
    lines += ["", "Review relevance, current Plus behavior and native ownership. Create a focused issue/PR only for confirmed work. A tag is not proof of a stable release. Limited or missing API coverage needs manual review.", "", "Only the latest 24 evidence rows are retained. Older edits remain in this comment’s GitHub edit history. State contains public SHAs/tags/PR IDs only.", f"<!-- omaconnect-upstream-watch:state:v1 {encoded} -->", END]
    return "\n".join(lines)


def decode_comment(body):
    if not isinstance(body, str) or len(body.encode()) > 60000 or body.count(COMMENT_MARKER) != 1 or body.count(START) != 1 or body.count(END) != 1:
        raise WatchError("invalid-owned-comment")
    start, end = body.index(START), body.index(END) + len(END)
    if end <= start:
        raise WatchError("invalid-owned-comment")
    matches = STATE_RE.findall(body[start:end])
    if len(matches) != 1 or len(matches[0]) > MAX_STATE:
        raise WatchError("invalid-state")
    try:
        state = json.loads(base64.b64decode(matches[0], validate=True))
    except (ValueError, UnicodeError, RecursionError):
        raise WatchError("invalid-state") from None
    return validate_state(state), body[:start], body[end:]


def owned(item):
    user = item.get("user")
    return isinstance(user, dict) and user.get("login") == BOT and user.get("type") == "Bot"


def find_owned(client):
    base = f"/repos/{client.repository}"
    matches = []
    # Exhaust pagination, or refuse creation. This avoids duplicates in larger repos.
    for page in range(1, 11):
        rows = array(client.github(base + "/issues", query={"state": "all", "per_page": 100, "page": page}), 100)
        matches += [item for item in rows if not item.get("pull_request") and owned(item) and isinstance(item.get("body"), str) and item["body"].splitlines()[:1] == [ISSUE_MARKER]]
        if len(rows) < 100:
            break
    else:
        raise WatchError("issue-search-limit")
    if len(matches) > 1:
        raise WatchError("duplicate-owned-issues")
    if not matches:
        return None, None
    issue = matches[0]
    ident = number(issue.get("number"))
    comments = []
    for page in range(1, 11):
        rows = array(client.github(base + f"/issues/{ident}/comments", query={"per_page": 100, "page": page}), 100)
        comments += [item for item in rows if owned(item) and isinstance(item.get("body"), str) and item["body"].splitlines()[:1] == [COMMENT_MARKER]]
        if len(rows) < 100:
            break
    else:
        raise WatchError("comment-search-limit")
    if len(comments) > 1:
        raise WatchError("duplicate-owned-comments")
    return issue, comments[0] if comments else None


def run(client, apply=False):
    issue, comment = find_owned(client)
    state, prefix, suffix = decode_comment(comment["body"]) if comment else (empty_state(), COMMENT_MARKER + "\n", "")
    current = evolve(client, state)
    body = prefix + render(current) + suffix
    changed = current != state or comment is None
    if apply and changed:
        base = f"/repos/{client.repository}"
        if issue is None:
            issue = client.github(base + "/issues", method="POST", data={"title": TITLE, "body": ISSUE_MARKER + "\nThis issue is the upstream watch queue. The bot updates only its marked comment. Add human triage notes below. See docs/UPSTREAM-WATCH.md in this repository for scope, limits and controls.", "labels": ["upstream", "triage"]})
            if not isinstance(issue, dict):
                raise WatchError("invalid-write-response")
        issue_number = number(issue.get("number"))
        if comment:
            client.github(base + f"/issues/comments/{number(comment.get('id'))}", method="PATCH", data={"body": body})
        else:
            client.github(base + f"/issues/{issue_number}/comments", method="POST", data={"body": body})
        # Never change human issue text. Reopen only when the queue actually changes.
        if issue.get("state") == "closed":
            client.github(base + f"/issues/{issue_number}", method="PATCH", data={"state": "open"})
    statuses = ", ".join(source + "=" + current["sources"][source]["status"] for source in SOURCES)
    print(("applied" if apply else "dry-run") + ": " + ("queue changed; " if changed else "no queue change; ") + statuses)
    unavailable = [source for source in SOURCES if current["sources"][source]["status"] != "ok"]
    if unavailable and changed and apply:
        print("::warning::Upstream coverage is unavailable for " + ", ".join(unavailable) + "; see the rolling queue. This is not an all-clear.")
    # In apply mode the durable status is the result; unchanged failures do not notify daily.
    # A dry-run remains nonzero when it cannot validate all fixed sources.
    return 1 if unavailable and not apply else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--dry-run", action="store_true", help="read only; default")
    group.add_argument("--apply", action="store_true", help="update the owned queue from a scheduled/manual GitHub Actions run")
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
    args = parser.parse_args(argv)
    try:
        token = os.environ.get("GITHUB_TOKEN", "")
        if args.apply and (not token or os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("GITHUB_EVENT_NAME") not in {"schedule", "workflow_dispatch"}):
            raise WatchError("apply-requires-scheduled-or-manual-actions")
        return run(Client(args.repository, token), apply=args.apply)
    except WatchError as exc:
        print("upstream-watch: " + str(exc), file=sys.stderr)
        return 1
    except Exception:
        # Never dump HTTP requests, tokens, upstream bodies or arbitrary exception text.
        print("upstream-watch: internal-error (no request details logged)", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
