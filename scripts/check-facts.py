#!/usr/bin/env python3
"""Guard against changing a verified fact while rewriting a lesson's prose.

Compares each lesson in the working tree with the same file at a git revision (default HEAD) and fails if:
  1. any fenced code block changed, was dropped or was reordered (program output lives in these)
  2. an inline `code` span disappeared (unless listed in scripts/check-facts.allow)
  3. a number inside a spoiler (<details>) disappeared from the rewritten spoilers (measured results)
  4. a `swift run …` / `swift test …` / script command, a demo id (p0.02b) or a link target disappeared

    python3 scripts/check-facts.py                       every lesson that differs from HEAD
    python3 scripts/check-facts.py lessons/P0-foundations/02-data-race.md
    python3 scripts/check-facts.py --base a136e43        compare against an older revision

Allow-file format (one per line, '#' comments):  lessons/P0-foundations/02-data-race.md: `span that may go`
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALLOW_FILE = ROOT / "scripts" / "check-facts.allow"

FENCE = re.compile(r"^[ \t]*```[^\n]*\n.*?^[ \t]*```[ \t]*$", re.MULTILINE | re.DOTALL)
INLINE_CODE = re.compile(r"`([^`\n]+)`")
DETAILS = re.compile(r"<details>.*?</details>", re.DOTALL)
NUMBER = re.compile(r"(?<![\w.])\d[\d,_]*(?:\.\d+)?(?:\s?(?:ms|µs|ns|s|x|×|%|KB|MB|GB))?(?![\w])")
COMMAND = re.compile(r"(?:swift (?:run|test|build)|scripts/[\w-]+\.sh|xcrun simctl)[^\n`|]*")
DEMO_ID = re.compile(r"\bp\d\.\d\d[a-z]?\b")
LINK = re.compile(r"\]\(([^)\s]+)\)")
NAV_BLOCK = re.compile(r"<!-- nav:start -->.*?<!-- nav:end -->", re.DOTALL)


def dedent_block(block: str) -> str:
    lines = block.split("\n")
    indent = min((len(l) - len(l.lstrip()) for l in lines if l.strip()), default=0)
    return "\n".join(l[indent:] for l in lines)


def without_fences(text: str) -> str:
    return FENCE.sub("", text)


def normalise_number(raw: str) -> str:
    return raw.replace(",", "").replace("_", "").replace(" ", "")


LIST_MARKER = re.compile(r"^\s*\d+\.\s", re.MULTILINE)


def numbers(text: str) -> set[str]:
    return {normalise_number(n) for n in NUMBER.findall(LIST_MARKER.sub("", text))}


def allowed() -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    if not ALLOW_FILE.exists():
        return result
    for line in ALLOW_FILE.read_text().splitlines():
        if line.lstrip().startswith("#"):
            continue
        match = re.match(r"\s*([^:]+):\s*`(.+)`\s*$", line)
        if match:
            result.setdefault(match.group(1).strip(), set()).add(match.group(2))
    return result


def git_show(base: str, path: str) -> str | None:
    result = subprocess.run(["git", "show", f"{base}:{path}"], cwd=ROOT, capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else None


def changed_lessons(base: str) -> list[str]:
    result = subprocess.run(["git", "diff", "--name-only", base, "--", "lessons"], cwd=ROOT, capture_output=True, text=True)
    return [p for p in result.stdout.split() if p.endswith(".md")]


def check(path: str, before: str, after: str, allow: set[str]) -> list[str]:
    problems: list[str] = []
    before = NAV_BLOCK.sub("", before)
    after = NAV_BLOCK.sub("", after)

    old_fences = [dedent_block(b) for b in FENCE.findall(before)]
    new_fences = [dedent_block(b) for b in FENCE.findall(after)]
    if old_fences != new_fences:
        for index, block in enumerate(old_fences):
            if index >= len(new_fences) or new_fences[index] != block:
                first = block.split("\n", 2)[1] if block.count("\n") > 1 else block
                problems.append(f"code block {index + 1} changed or moved (starts: {first.strip()[:60]!r})")
                break
        if len(new_fences) != len(old_fences):
            problems.append(f"{len(old_fences)} code blocks before, {len(new_fences)} after")

    old_prose, new_prose = without_fences(before), without_fences(after)
    new_spans = set(INLINE_CODE.findall(new_prose))
    for span in sorted(set(INLINE_CODE.findall(old_prose)) - new_spans - allow):
        problems.append(f"inline code `{span}` is gone")

    new_spoilers = " ".join(DETAILS.findall(after))
    new_spoiler_numbers = numbers(new_spoilers)
    for spoiler in DETAILS.findall(before):
        for number in sorted(numbers(spoiler) - new_spoiler_numbers):
            problems.append(f"spoiler number {number} is gone")

    for pattern, label in ((COMMAND, "command"), (DEMO_ID, "demo id"), (LINK, "link")):
        new_items = set(pattern.findall(after))
        for item in sorted(set(pattern.findall(before)) - new_items):
            problems.append(f"{label} {item.strip()!r} is gone")
    return problems


def main() -> int:
    args = sys.argv[1:]
    base = "HEAD"
    if "--base" in args:
        index = args.index("--base")
        base = args[index + 1]
        del args[index : index + 2]
    paths = args or changed_lessons(base)
    if not paths:
        print(f"no lessons differ from {base}")
        return 0
    allow = allowed()
    failures = 0
    for path in paths:
        before = git_show(base, path)
        if before is None:
            print(f"? {path}: not in {base}, skipped")
            continue
        after = (ROOT / path).read_text()
        problems = check(path, before, after, allow.get(path, set()))
        if problems:
            failures += 1
            print(f"✘ {path}")
            for problem in problems:
                print(f"    {problem}")
        else:
            print(f"✔ {path}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
