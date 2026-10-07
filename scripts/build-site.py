#!/usr/bin/env python3
"""Build the course website (MkDocs Material) from the markdown in this repo.

The originals are never touched. This script stages a COPY into .site-build/docs, transforms only the copy,
generates the navigation from the lesson files (new lessons appear automatically), and runs `mkdocs build --strict`
(which fails on any broken link).

    .venv-site/bin/python scripts/build-site.py            build  → .site-build/out
    .venv-site/bin/python scripts/build-site.py --serve    build the staging copy and run a local preview server
    .venv-site/bin/python scripts/build-site.py --stage    only stage + generate config (no mkdocs run)

One-time setup:  python3 -m venv .venv-site && .venv-site/bin/pip install -r site/requirements.txt
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / ".site-build"
DOCS = BUILD / "docs"

PHASES = {
    "P0-foundations": "P0 · Foundations",
    "P1-async-await": "P1 · async/await",
    "P2-isolation": "P2 · Isolation",
    "P3-structured": "P3 · Structured concurrency",
    "P4-classics": "P4 · Classic problems",
    "P5-bug-zoo": "P5 · Bug Zoo",
    "P6-internals": "P6 · Internals",
    "P7-interview": "P7 · Interview mastery",
}
INTERVIEW_PAGES = [
    ("Flashcards", "flashcards.md"),
    ("Question bank", "question-bank.md"),
    ("Output puzzles", "output-puzzles.md"),
    ("Timed katas", "katas.md"),
]

NAV_BLOCK = re.compile(r"<!-- nav:start -->.*?<!-- nav:end -->\n*", re.DOTALL)
TRAILING_RULES = re.compile(r"(\n+---[ \t]*)+\s*$")
TABLE_SEPARATOR = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$")
LINK_TO_README = re.compile(r"(\]\((?:\.{1,2}/)*)README\.md")


def h1(path: Path) -> str:
    for line in path.read_text().splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


def transform_lesson(text: str) -> str:
    # Material's footer provides prev/next, so drop the hand-written nav blocks and the separator before the last one.
    text = NAV_BLOCK.sub("", text)
    text = TRAILING_RULES.sub("\n", text.rstrip() + "\n")
    # Python-Markdown does not parse markdown inside raw HTML blocks unless told to (md_in_html).
    # Without this every spoiler's code blocks and tables would render as literal text.
    text = text.replace("<details>", '<details markdown="1">')
    # The "⏱ 30 min · Demo … · Exercise …" line becomes a badge row (attr_list).
    out: list[str] = []
    lines = text.split("\n")
    for i, line in enumerate(lines):
        out.append(line)
        if line.startswith("⏱"):
            out.append("{ .lesson-meta }")
            if i + 1 < len(lines) and lines[i + 1].strip():
                out.append("")
    return "\n".join(out)


def fix_table_spacing(text: str) -> str:
    """GitHub renders a table that directly follows a paragraph line; Python-Markdown needs a blank line before it."""
    lines = text.split("\n")
    out: list[str] = []
    inside_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            inside_fence = not inside_fence
        starts_table = (
            not inside_fence
            and line.lstrip().startswith("|")
            and i + 1 < len(lines)
            and TABLE_SEPARATOR.match(lines[i + 1])
        )
        if starts_table and out and out[-1].strip() and not out[-1].lstrip().startswith("|"):
            out.append("")
        out.append(line)
    return "\n".join(out)


LIST_START = re.compile(r"^\s{0,3}([-*]|1\.)\s+\S")
LIST_ANY = re.compile(r"^\s*([-*+]|\d+\.)\s+")


def fix_list_spacing(text: str) -> str:
    """GitHub lets a list interrupt a paragraph and lets text follow a closing code fence directly;
    Python-Markdown needs a blank line in both places (otherwise the list/paragraph is swallowed)."""
    lines = text.split("\n")
    out: list[str] = []
    inside_fence = False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            inside_fence = not inside_fence
            out.append(line)
            closing = not inside_fence
            if closing and i + 1 < len(lines) and lines[i + 1].strip():
                out.append("")
            continue
        if not inside_fence and out and LIST_START.match(line):
            previous = out[-1]
            is_paragraph_text = (
                previous.strip()
                and not LIST_ANY.match(previous)
                and not previous.startswith((" ", "\t", ">", "|", "#", "<"))
            )
            if is_paragraph_text:
                out.append("")
        elif not inside_fence and out and NUMBERED_ITEM.match(line.lstrip()) and out[-1].startswith(" ") and out[-1].strip() and not LIST_ANY.match(out[-1]):
            out.append("")  # next numbered item right after an indented paragraph of the previous item
        out.append(line)
    return "\n".join(out)


NUMBERED_ITEM = re.compile(r"^\d+\.\s")


def fix_numbered_indent(text: str) -> str:
    """Content under '3. item' is indented 3 spaces (GitHub); Python-Markdown requires 4."""
    out: list[str] = []
    in_numbered = False
    for line in text.split("\n"):
        if NUMBERED_ITEM.match(line):
            in_numbered = True
        elif line.strip() and not line.startswith(" "):
            in_numbered = False
        if in_numbered and line.startswith("   ") and line.strip():
            line = " " + line
        out.append(line)
    return "\n".join(out)


def harden_blockquotes(text: str) -> str:
    """Keep the line structure of multi-line blockquotes (bug reports: Title / Steps / Expected / Actual)."""
    lines = text.split("\n")
    inside_fence = False
    for i, line in enumerate(lines[:-1]):
        if line.lstrip().startswith("```"):
            inside_fence = not inside_fence
        nxt = lines[i + 1]
        if not inside_fence and line.startswith(">") and nxt.startswith(">") and line.strip() != ">" and nxt.strip() != ">":
            lines[i] = line.rstrip() + "  "
    return "\n".join(lines)


def nav_title(title: str) -> str:
    """Sidebar label: drop the long '(bug: "...")' tail that the page's own H1 keeps."""
    return re.sub(r"\s*\(bug:.*\)", "", title)


def stage() -> None:
    if BUILD.exists():
        shutil.rmtree(BUILD)
    DOCS.mkdir(parents=True)

    shutil.copytree(ROOT / "lessons", DOCS / "lessons")
    (DOCS / "interview").mkdir()
    for name in (n for _, n in INTERVIEW_PAGES):
        shutil.copy(ROOT / "interview" / name, DOCS / "interview" / name)
    shutil.copy(ROOT / "reading-list.md", DOCS / "reading-list.md")
    # README.md would collide with index.md in MkDocs, so it becomes the "Roadmap" page.
    shutil.copy(ROOT / "README.md", DOCS / "roadmap.md")
    shutil.copy(ROOT / "site" / "index.md", DOCS / "index.md")
    shutil.copytree(ROOT / "site" / "stylesheets", DOCS / "stylesheets")
    js = ROOT / "site" / "javascripts"
    if any(js.glob("*.js")):
        shutil.copytree(js, DOCS / "javascripts")

    for page in DOCS.rglob("*.md"):
        text = page.read_text()
        text = LINK_TO_README.sub(r"\1roadmap.md", text)
        text = fix_table_spacing(text)
        text = fix_numbered_indent(text)
        text = fix_list_spacing(text)
        text = harden_blockquotes(text)
        if page.is_relative_to(DOCS / "lessons"):
            text = transform_lesson(text)
        page.write_text(text)


def build_nav() -> list:
    nav: list = [{"Home": "index.md"}, {"Roadmap": "roadmap.md"}]
    for folder, label in PHASES.items():
        files = sorted((DOCS / "lessons" / folder).glob("*.md"))
        nav.append({label: [{nav_title(h1(f)): f.relative_to(DOCS).as_posix()} for f in files]})
    nav.append({"Interview bank": [{title: f"interview/{name}"} for title, name in INTERVIEW_PAGES]})
    nav.append({"Reading list": "reading-list.md"})
    return nav


def write_config() -> Path:
    config = yaml.safe_load((ROOT / "site" / "mkdocs.template.yml").read_text())
    config["nav"] = build_nav()
    if (DOCS / "javascripts").exists():
        config["extra_javascript"] = sorted(f"javascripts/{p.name}" for p in (DOCS / "javascripts").glob("*.js"))
    path = BUILD / "mkdocs.yml"
    path.write_text(yaml.safe_dump(config, allow_unicode=True, sort_keys=False, width=120))
    return path


def main() -> int:
    stage_only = "--stage" in sys.argv
    serve = "--serve" in sys.argv
    stage()
    config = write_config()
    lessons = sum(1 for _ in (DOCS / "lessons").rglob("*.md"))
    print(f"staged {lessons} lessons → {BUILD.relative_to(ROOT)}")
    if stage_only:
        return 0
    command = [sys.executable, "-m", "mkdocs", "serve" if serve else "build", "-f", str(config)]
    if not serve:
        command.append("--strict")
    env = {**os.environ, "NO_MKDOCS_2_WARNING": "true"}
    return subprocess.call(command, env=env)


if __name__ == "__main__":
    sys.exit(main())
