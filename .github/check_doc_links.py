#!/usr/bin/env python3
"""Check repository-local inline Markdown links. No network or provider calls.

External URL availability, heading anchors and historical line numbers need
separate review. This check proves only that local file targets exist.
"""
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"!?\[[^\]\n]*\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+[^\n)]*)?\)")
FENCE = re.compile(r"^\s*(`{3,}|~{3,})")


def check(root: Path = ROOT) -> list[str]:
    errors = []
    for document in sorted(root.rglob("*.md")):
        if any(part in {".git", "node_modules", ".venv"} for part in document.parts):
            continue
        fence = None
        for number, line in enumerate(document.read_text(encoding="utf-8").splitlines(), 1):
            marker = FENCE.match(line)
            if marker:
                token = marker.group(1)
                if fence is None:
                    fence = token
                elif token[0] == fence[0] and len(token) >= len(fence):
                    fence = None
                continue
            if fence:
                continue
            for match in LINK.finditer(line):
                raw = match.group(1) or match.group(2)
                target = urlsplit(raw)
                if target.scheme or target.netloc or not target.path:
                    continue
                path = (document.parent / unquote(target.path)).resolve()
                try:
                    path.relative_to(root.resolve())
                except ValueError:
                    errors.append(f"{document.relative_to(root)}:{number}: target leaves repository: {raw}")
                    continue
                if not path.exists():
                    errors.append(f"{document.relative_to(root)}:{number}: missing target: {raw}")
    return errors


if __name__ == "__main__":
    findings = check()
    for finding in findings:
        print(finding)
    if findings:
        raise SystemExit(1)
    print("Local Markdown file targets exist. External URLs and anchors were not checked.")
