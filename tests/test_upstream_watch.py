"""Owned fake HTTP/API checks. Never open a network connection or write to GitHub."""

import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest import mock
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("upstream_watch", ROOT / ".github/upstream_watch.py")
watch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(watch)
A, B, C = "a" * 40, "b" * 40, "c" * 40
BOT = {"login": watch.BOT, "type": "Bot"}


class FakeAPI:
    def __init__(self):
        self.repository = "example/plus"
        self.routes = {}
        self.calls = []
        self.issues = []
        self.comments = []
        self.writes = []
        for source in watch.SOURCES:
            self.set_snapshot(source)

    def set_snapshot(self, source, head=A, tags=None, releases=None, pulls=None):
        base, kind = watch.base_path(source)
        host = "api.github.com" if kind == "github" else "invent.kde.org"
        self.routes[(host, base + ("/commits" if kind == "github" else "/repository/commits"))] = [{"sha" if kind == "github" else "id": head}]
        self.routes[(host, base + ("/tags" if kind == "github" else "/repository/tags"))] = [{"name": name, "commit": {"sha" if kind == "github" else "id": value}} for name, value in (tags or {"v1.0": A}).items()]
        self.routes[(host, base + "/releases")] = [{"tag_name": name} for name in (releases or [])]
        if kind == "github":
            self.routes[(host, base + "/pulls")] = pulls or []

    def compare(self, source, old=A, new=B, paths=None, messages=None, incomplete=False):
        base, kind = watch.base_path(source)
        if kind == "github":
            self.routes[("api.github.com", base + "/compare/" + old + "..." + new)] = {"status": "ahead", "total_commits": 2 if incomplete else 1, "commits": [{"commit": {"message": (messages or ["Change"])[0]}}], "files": [{"filename": p} for p in (paths or ["plugins/share/send.cpp"])]}
        else:
            self.routes[("invent.kde.org", base + "/repository/compare")] = {"commits": [{"title": (messages or ["Change"])[0]}], "diffs": [{"new_path": p, "old_path": p} for p in (paths or ["plugins/share/send.cpp"])], "compare_timeout": incomplete}

    def own(self, state, before="", after=""):
        self.issues = [{"number": 7, "state": "open", "user": BOT, "body": watch.ISSUE_MARKER + "\nHuman issue text"}]
        self.comments = [{"id": 8, "user": BOT, "body": watch.COMMENT_MARKER + "\n" + before + watch.render(state) + after}]

    def request(self, host, path, query=None, method="GET", data=None):
        self.calls.append((method, host, path, query, data))
        base = "/repos/" + self.repository
        if method != "GET":
            self.writes.append((method, path, copy.deepcopy(data)))
            if path == base + "/issues":
                item = {"number": 7, "state": "open", "user": BOT, **data}
                self.issues.append(item)
                return copy.deepcopy(item)
            if path == base + "/issues/7/comments":
                item = {"id": 8, "user": BOT, **data}
                self.comments.append(item)
                return copy.deepcopy(item)
            if path == base + "/issues/comments/8":
                self.comments[-1].update(data)
                return copy.deepcopy(self.comments[-1])
            if path == base + "/issues/7":
                self.issues[-1].update(data)
                return copy.deepcopy(self.issues[-1])
            raise AssertionError("Unexpected write path")
        if path == base + "/issues":
            return copy.deepcopy(self.issues) if (query or {}).get("page", 1) == 1 else []
        if path == base + "/issues/7/comments":
            return copy.deepcopy(self.comments) if (query or {}).get("page", 1) == 1 else []
        value = self.routes[(host, path)]
        if isinstance(value, Exception):
            raise value
        return copy.deepcopy(value)

    def github(self, path, **kwargs):
        return self.request("api.github.com", path, **kwargs)


def baseline(client):
    return watch.evolve(client, watch.empty_state())


class WatchTests(unittest.TestCase):
    def test_first_baseline_does_not_import_history_and_stable_run_has_no_change(self):
        client = FakeAPI()
        client.set_snapshot("omaconnect", releases=["v1.0"], pulls=[{"number": 31, "head": {"sha": A}, "updated_at": "2026-10-01T12:00:00Z"}])
        state = baseline(client)
        self.assertEqual(state["events"], [])
        self.assertEqual(watch.evolve(client, state), state)
        self.assertTrue(all(r["status"] == "ok" for r in state["sources"].values()))
        self.assertFalse(any("/files" in call[2] for call in client.calls))

    def test_new_protocol_tag_release_and_pull_are_recorded_once(self):
        client = FakeAPI()
        state = baseline(client)
        client.set_snapshot("omaconnect", head=B, tags={"v1.0": A, "v1.1": B}, releases=["v1.1"], pulls=[{"number": 35, "head": {"sha": C}, "updated_at": "2026-10-29T12:00:00Z"}])
        client.compare("omaconnect")
        base, _ = watch.base_path("omaconnect")
        client.routes[("api.github.com", base + "/pulls/35/files")] = [{"filename": "scripts/discover_devices.sh"}]
        current = watch.evolve(client, state)
        self.assertEqual({e["kind"] for e in current["events"]}, {"tag", "release", "code", "pull"})
        self.assertEqual(watch.evolve(client, current), current)
        self.assertIn(B, watch.render(current))
        self.assertIn("/pull/35/commits/" + C, watch.render(current))

    def test_irrelevant_change_advances_baseline_without_a_triage_row(self):
        client = FakeAPI()
        state = baseline(client)
        client.set_snapshot("desktop", head=B)
        client.compare("desktop", paths=["po/fr/messages.po"], messages=["Translate strings"])
        current = watch.evolve(client, state)
        self.assertEqual(current["sources"]["desktop"]["head"], B)
        self.assertEqual(current["events"], [])

    def test_failure_preserves_last_good_baseline_and_is_not_reposted_daily(self):
        client = FakeAPI()
        state = baseline(client)
        client.own(state)
        base, _ = watch.base_path("desktop")
        client.routes[("invent.kde.org", base + "/repository/commits")] = watch.WatchError("http-403")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(watch.run(client, apply=True), 0)
            self.assertEqual(len(client.writes), 1)
            self.assertEqual(watch.run(client, apply=True), 0)
        self.assertEqual(len(client.writes), 1)
        stored, _, _ = watch.decode_comment(client.comments[0]["body"])
        self.assertEqual(stored["sources"]["desktop"]["head"], A)
        self.assertEqual(stored["sources"]["desktop"]["status"], "http-403")
        self.assertEqual(out.getvalue().count("::warning::"), 1)
        self.assertIn("no current coverage claim", client.comments[0]["body"])

    def test_first_unavailable_source_is_baselined_without_flood_on_recovery(self):
        client = FakeAPI()
        base, _ = watch.base_path("android")
        client.routes[("invent.kde.org", base + "/releases")] = watch.WatchError("http-429")
        failed = baseline(client)
        self.assertNotIn("head", failed["sources"]["android"])
        client.set_snapshot("android", head=B, releases=["v1.2"])
        recovered = watch.evolve(client, failed)
        self.assertEqual(recovered["sources"]["android"]["status"], "ok")
        self.assertEqual(recovered["events"], [])

    def test_incomplete_comparison_is_explicit_evidence_not_an_all_clear(self):
        client = FakeAPI()
        state = baseline(client)
        client.set_snapshot("desktop", head=B)
        client.compare("desktop", incomplete=True)
        current = watch.evolve(client, state)
        self.assertIn("coverage gap", current["events"][0]["topics"])
        self.assertIn("coverage gap", watch.render(current))

    def test_bad_head_and_missing_paths_cannot_advance_the_baseline(self):
        for fault in ("bad-head", "missing-path"):
            with self.subTest(fault=fault):
                client = FakeAPI()
                state = baseline(client)
                client.set_snapshot("omaconnect", head=B if fault == "missing-path" else "not-a-sha")
                client.compare("omaconnect")
                if fault == "missing-path":
                    base, _ = watch.base_path("omaconnect")
                    client.routes[("api.github.com", base + "/compare/" + A + "..." + B)]["files"] = [{}]
                current = watch.evolve(client, state)
                self.assertNotEqual(current["sources"]["omaconnect"]["status"], "ok")
                self.assertEqual(current["sources"]["omaconnect"]["head"], A)

    def test_remote_text_and_urls_do_not_cross_the_post_boundary(self):
        client = FakeAPI()
        state = baseline(client)
        client.set_snapshot("android", head=B)
        client.compare("android", messages=['security @everyone <img src="https://attacker.invalid"> ```'])
        rendered = watch.render(watch.evolve(client, state))
        self.assertNotIn("@everyone", rendered)
        self.assertNotIn("attacker.invalid", rendered)
        self.assertIn("security/privacy", rendered)
        # Even a modified stored state cannot publish a malicious tag or URL.
        state["events"] = [watch.event("desktop", "release", "@everyone<script>", ["release/tag"])]
        with self.assertRaises(watch.WatchError):
            watch.render(state)

    def test_unsupported_remote_tag_is_visible_failure_not_copied_text(self):
        client = FakeAPI()
        client.set_snapshot("android", tags={"v1.0 @everyone": A})
        current = baseline(client)
        self.assertEqual(current["sources"]["android"]["status"], "unsupported-tag")
        self.assertNotIn("@everyone", watch.render(current))

    def test_dry_run_never_writes_even_when_new_queue_is_needed(self):
        client = FakeAPI()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(watch.run(client), 0)
        self.assertEqual(client.writes, [])

    def test_first_apply_creates_only_one_owned_issue_and_comment(self):
        client = FakeAPI()
        with contextlib.redirect_stdout(io.StringIO()):
            watch.run(client, apply=True)
            watch.run(client, apply=True)
        self.assertEqual([w[0] for w in client.writes], ["POST", "POST"])
        self.assertEqual(len(client.issues), 1)
        self.assertEqual(len(client.comments), 1)

    def test_unknown_post_outcome_is_recovered_without_a_second_issue(self):
        client = FakeAPI()
        original = client.github

        def fail_after_comment(path, **kwargs):
            result = original(path, **kwargs)
            if kwargs.get("method") == "POST" and path.endswith("/comments"):
                raise watch.WatchError("timeout")
            return result

        with mock.patch.object(client, "github", side_effect=fail_after_comment):
            with self.assertRaisesRegex(watch.WatchError, "timeout"):
                watch.run(client, apply=True)
        with contextlib.redirect_stdout(io.StringIO()):
            watch.run(client, apply=True)
        self.assertEqual(len(client.issues), 1)
        self.assertEqual(len(client.comments), 1)
        self.assertEqual(len(client.writes), 2)

    def test_large_changed_pull_batch_preserves_the_previous_source(self):
        client = FakeAPI()
        state = baseline(client)
        client.set_snapshot("omaconnect", pulls=[{"number": i, "head": {"sha": B}, "updated_at": "2026-10-29T12:00:00Z"} for i in range(1, 10)])
        current = watch.evolve(client, state)
        self.assertEqual(current["sources"]["omaconnect"]["status"], "pull-review-limit")
        self.assertEqual(current["sources"]["omaconnect"]["pulls"], {})
        self.assertFalse(any("/files" in call[2] for call in client.calls))

    def test_unavailable_dry_run_is_nonzero_and_never_writes(self):
        client = FakeAPI()
        base, _ = watch.base_path("desktop")
        client.routes[("invent.kde.org", base + "/repository/commits")] = watch.WatchError("http-503")
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(watch.run(client), 1)
        self.assertIn("desktop=http-503", out.getvalue())
        self.assertEqual(client.writes, [])

    def test_only_bot_owned_marker_comment_is_updated_and_outside_text_survives(self):
        client = FakeAPI()
        state = baseline(client)
        client.own(state, before="Human prefix\n", after="\nHuman suffix")
        issue_body = client.issues[0]["body"]
        client.comments.insert(0, {"id": 9, "user": {"login": "human", "type": "User"}, "body": watch.COMMENT_MARKER + "\nHuman feedback"})
        client.set_snapshot("android", head=B)
        client.compare("android")
        with contextlib.redirect_stdout(io.StringIO()):
            watch.run(client, apply=True)
        self.assertEqual(client.writes[0][1], "/repos/example/plus/issues/comments/8")
        self.assertIn("Human prefix", client.writes[0][2]["body"])
        self.assertIn("Human suffix", client.writes[0][2]["body"])
        self.assertEqual(client.issues[0]["body"], issue_body)
        self.assertIn("Human feedback", client.comments[0]["body"])

    def test_ambiguous_or_corrupt_owned_state_refuses_writes(self):
        client = FakeAPI()
        client.own(baseline(client))
        client.comments.append(copy.deepcopy(client.comments[0]))
        with self.assertRaisesRegex(watch.WatchError, "duplicate-owned-comments"):
            watch.run(client, apply=True)
        self.assertEqual(client.writes, [])
        client.comments.pop()
        client.comments[0]["body"] = watch.COMMENT_MARKER + "\n" + watch.START + watch.END
        with self.assertRaises(watch.WatchError):
            watch.run(client, apply=True)
        self.assertEqual(client.writes, [])

    def test_issue_pagination_is_exhausted_before_creation(self):
        client = FakeAPI()
        client.issues = [{"number": n + 10, "user": {"login": "human"}, "body": "Feedback"} for n in range(100)]
        with contextlib.redirect_stdout(io.StringIO()):
            watch.run(client)
        pages = [call[3]["page"] for call in client.calls if call[2] == "/repos/example/plus/issues"]
        self.assertEqual(pages, [1, 2])

    def test_untrusted_event_cannot_apply_and_secret_is_not_printed(self):
        secret = "SECRET-DO-NOT-PRINT"
        with mock.patch.dict(watch.os.environ, {"GITHUB_TOKEN": secret, "GITHUB_ACTIONS": "true", "GITHUB_EVENT_NAME": "pull_request_target"}, clear=True):
            with contextlib.redirect_stderr(io.StringIO()) as err:
                self.assertEqual(watch.main(["--apply", "--repository", "example/plus"]), 1)
        self.assertNotIn(secret, err.getvalue())
        self.assertIn("apply-requires", err.getvalue())


class FakeResponse:
    def __init__(self, raw=b"[]", content_type="application/json"):
        self.raw = raw
        self.headers = {"Content-Type": content_type}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def read(self, size):
        return self.raw[:size]


class HTTPTests(unittest.TestCase):
    def client(self, response):
        opener = mock.Mock()
        if isinstance(response, Exception):
            opener.open.side_effect = response
        else:
            opener.open.return_value = response
        return watch.Client("example/plus", token="SECRET-DO-NOT-PRINT", opener=opener), opener

    def test_bounded_bad_missing_json_and_waf_responses(self):
        cases = [(FakeResponse(b"["), "invalid-json"), (FakeResponse(b"x" * (watch.MAX_BYTES + 1)), "oversized-response"), (FakeResponse(b"<html>WAF</html>", "text/html"), "non-json-response"), (urllib.error.HTTPError("https://example.invalid", 429, "secret-reason", {}, None), "http-429")]
        for response, status in cases:
            with self.subTest(status=status):
                client, _ = self.client(response)
                with self.assertRaisesRegex(watch.WatchError, "^" + status + "$"):
                    client.request("invent.kde.org", "/api/v4/projects/network%2Fkdeconnect-kde/releases")

    def test_token_goes_only_to_github_and_request_timeout_is_bounded(self):
        client, opener = self.client(FakeResponse())
        client.request("invent.kde.org", "/api/v4/projects/network%2Fkdeconnect-kde/releases")
        req = opener.open.call_args.args[0]
        self.assertIsNone(req.get_header("Authorization"))
        self.assertLessEqual(opener.open.call_args.kwargs["timeout"], 12)
        client.request("api.github.com", "/repos/example/plus/issues")
        self.assertEqual(opener.open.call_args.args[0].get_header("Authorization"), "Bearer SECRET-DO-NOT-PRINT")

    def test_unknown_host_and_non_issue_write_are_rejected(self):
        client, opener = self.client(FakeResponse())
        with self.assertRaises(watch.WatchError):
            client.request("attacker.invalid", "/api")
        with self.assertRaises(watch.WatchError):
            client.request("invent.kde.org", "/api/v4/projects/1/issues", method="POST", data={})
        self.assertFalse(opener.open.called)

    def test_redirect_is_not_followed_and_error_text_has_no_secret(self):
        handler = watch.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, "redirect", {}, "https://attacker.invalid"))
        client, _ = self.client(urllib.error.URLError("SECRET-DO-NOT-PRINT"))
        with self.assertRaisesRegex(watch.WatchError, "^network-unavailable$"):
            client.request("api.github.com", "/repos/example/plus/issues")


if __name__ == "__main__":
    unittest.main()
