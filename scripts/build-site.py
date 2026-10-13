#!/usr/bin/env python3
"""Build the course website (MkDocs + the custom theme in site/theme) from the markdown in this repo.

The originals are never touched. This script stages a COPY into .site-build/docs, transforms only the copy,
generates the navigation from the lesson files (new lessons appear automatically), runs `mkdocs build --strict`
(which fails on any broken link) and then indexes the output with Pagefind for search.

    .venv-site/bin/python scripts/build-site.py            build  → .site-build/out
    .venv-site/bin/python scripts/build-site.py --serve    build the staging copy and run a local preview server
    .venv-site/bin/python scripts/build-site.py --stage    only stage + generate config (no mkdocs run)

One-time setup:  python3 -m venv .venv-site && .venv-site/bin/pip install -r site/requirements.txt
"""
import html
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
OUT = BUILD / "out"

PHASES = {
    "P0-foundations": ("Foundations", "Threads, cores, data races, atomics, locks, deadlock and thread explosion, starting from GCD."),
    "P1-async-await": ("async/await", "What await really does, the cooperative pool, tasks, continuations and async sequences."),
    "P2-isolation": ("Isolation", "Actors, reentrancy, MainActor, Sendable, sending, and the Swift 6 errors you will actually meet."),
    "P3-structured": ("Structured concurrency", "async let, task groups, bounded concurrency, cancellation, timeouts and task-locals."),
    "P4-classics": ("Classic problems", "Producer and consumer, readers and writers, semaphores, rate limits, single-flight, an image pipeline."),
    "P5-bug-zoo": ("Bug Zoo", "Real bug reports with no hints. Reproduce, make it deterministic, find the cause, prove the fix."),
    "P6-internals": ("Internals", "Executors, what tasks and hops cost when measured, the memory model, Swift Evolution."),
    "P7-interview": ("Interview mastery", "Output marathons, timed katas, system design rounds and a full mock interview."),
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
LINK_TO_ROADMAP = re.compile(r"(\]\((?:\.{1,2}/)*)(?:README|ROADMAP)\.md")
LESSON_H1 = re.compile(r"^# (P\d+\.\d+)\s*[—-]\s*(.*?)\s*$", re.MULTILINE)
META_LINE = re.compile(r"^⏱\s*(.*)$", re.MULTILINE)
DEK = re.compile(r"^<!--\s*dek:\s*(.*?)\s*-->\n?", re.MULTILINE | re.DOTALL)
MINUTES = re.compile(r"(\d+(?:–\d+)?)\s*min")
STEP_H2 = re.compile(r"^## (\d+)\.\s+(.*?)\s*$")
TIMEBOX = re.compile(r"\s*\((\d+(?:–\d+)?)\s*min\b[^)]*\)")
FAST_TRACK_TAG = '<span class="tag">Fast track</span>'
INTERVIEW_HEADING = re.compile(r"^#{2,3} (?:\d+\.\s+)?(Interview cards|Flashcards)\b")
BUG_HEADING = re.compile(r"^## Bug report\b")
EMOJI = re.compile(
    "[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\u2300-\u23FF\uFE0F\u200D]+"
)


def strip_emoji(text: str) -> str:
    return re.sub(r"\s{2,}", " ", EMOJI.sub("", text)).strip()


def lesson_front_matter(text: str, folder: str, position: int, total: int) -> tuple[dict, str]:
    """Pull the H1 and the '⏱ …' line out of the body into front matter the theme renders as the page header."""
    heading = LESSON_H1.search(text)
    meta: dict = {"lesson": True, "phase_code": folder[:2], "phase_name": PHASES[folder][0], "position": position, "total": total}
    if heading:
        code, raw_title = heading.groups()
        meta["code"] = code
        meta["fast_track"] = "⭐" in raw_title
        clean = strip_emoji(raw_title.replace("⭐", ""))
        meta["heading"] = clean.replace("`", "")
        meta["heading_html"] = re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(clean, quote=False))
        text = text[: heading.start()] + text[heading.end() :]
    dek = DEK.search(text)
    if dek:
        meta["dek"] = dek.group(1).replace("`", "")
        meta["dek_html"] = re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(dek.group(1), quote=False))
        text = text[: dek.start()] + text[dek.end() :]
    line = META_LINE.search(text)
    if line:
        rest = line.group(1).strip()
        minutes = MINUTES.search(rest)
        if minutes:
            meta["minutes"] = minutes.group(1)
        kit = re.sub(r"^\d+\s*min\s*·\s*", "", rest)
        replacement = f"{kit}\n{{: .kit }}\n" if kit else ""
        text = text[: line.start()] + replacement + text[line.end() :]
    return meta, text.lstrip("\n")


def transform_lesson(text: str) -> str:
    # The theme renders prev/next itself, so drop the hand-written nav blocks and the separator before the last one.
    text = NAV_BLOCK.sub("", text)
    text = TRAILING_RULES.sub("\n", text.rstrip() + "\n")
    # Python-Markdown does not parse markdown inside raw HTML blocks unless told to (md_in_html).
    # Without this every spoiler's code blocks and tables would render as literal text.
    text = text.replace("<details>", '<details markdown="1">')
    text = re.sub(r"<summary>Spoiler:\s*", "<summary>Answer, ", text)
    text = re.sub(r"<summary>(.*?)</summary>", lambda m: f"<summary>{strip_emoji(m.group(1))}</summary>", text)
    return text


def transform_headings(text: str) -> str:
    """Step headings lose their number and timebox (the theme draws them as a small label);
    interview cards and bug reports are wrapped so the theme can typeset them as Q&A and as a ticket."""
    lines = text.split("\n")
    out: list[str] = []
    inside_fence = False
    wrapper: str | None = None  # "cards" while inside the card list, "ticket" while inside the bug report quote
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            inside_fence = not inside_fence
        if inside_fence:
            out.append(line)
            continue
        if wrapper == "cards" and line.startswith("#"):
            out.extend(["", "</div>", ""])
            wrapper = None
        if wrapper == "ticket" and not line.startswith(">"):
            out.extend(["", "</div>", ""])
            wrapper = None
        if line.startswith("#"):
            line = strip_emoji(line.replace("⭐", ""))
        elif "⭐" in line:
            line = re.sub(r"\s*(⭐)+", " " + FAST_TRACK_TAG, line)
        step = STEP_H2.match(line)
        if step:
            number, name = step.groups()
            timebox = TIMEBOX.search(name)
            attrs = f'data-step="{number}"' if number != "0" else ""
            if timebox and attrs:
                attrs += f' data-min="{timebox.group(1)}"'
                name = (name[: timebox.start()] + name[timebox.end() :]).strip()
            line = f"## {name} {{ {attrs} }}" if attrs else f"## {name}"
        out.append(line)
        if INTERVIEW_HEADING.match(line):
            out.extend(["", '<div class="cards" markdown="1">', ""])
            wrapper = "cards"
        elif BUG_HEADING.match(line):
            nxt = next((n for n in lines[i + 1 :] if n.strip()), "")
            if nxt.startswith(">"):
                out.extend(["", '<div class="ticket" markdown="1">', ""])
                wrapper = "ticket-pending"
        if wrapper == "ticket-pending" and line.startswith(">"):
            wrapper = "ticket"
    if wrapper in ("cards", "ticket"):
        out.extend(["", "</div>", ""])
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
    """Sidebar label: drop the long '(bug: "...")' tail that the page's own heading keeps."""
    return re.sub(r"\s*\(bug:.*\)", "", title)


def with_front_matter(meta: dict, text: str) -> str:
    return "---\n" + yaml.safe_dump(meta, allow_unicode=True, sort_keys=False, width=1000) + "---\n\n" + text


def stage() -> dict[str, list[tuple[str, str]]]:
    """Stage and transform the copy. Returns, per phase folder, (nav title, staged path) for each lesson."""
    if BUILD.exists():
        shutil.rmtree(BUILD)
    DOCS.mkdir(parents=True)

    shutil.copytree(ROOT / "lessons", DOCS / "lessons")
    (DOCS / "interview").mkdir()
    for name in (n for _, n in INTERVIEW_PAGES):
        shutil.copy(ROOT / "interview" / name, DOCS / "interview" / name)
    shutil.copy(ROOT / "reading-list.md", DOCS / "reading-list.md")
    shutil.copy(ROOT / "ROADMAP.md", DOCS / "roadmap.md")
    shutil.copy(ROOT / "site" / "index.md", DOCS / "index.md")

    lessons: dict[str, list[tuple[str, str]]] = {folder: [] for folder in PHASES}
    lesson_meta: dict[Path, dict] = {}
    for folder in PHASES:
        files = sorted((DOCS / "lessons" / folder).glob("*.md"))
        for position, path in enumerate(files, start=1):
            meta, body = lesson_front_matter(path.read_text(), folder, position, len(files))
            path.write_text(body)
            lesson_meta[path] = meta
            lessons[folder].append((nav_title(meta.get("heading", path.stem)), path.relative_to(DOCS).as_posix()))

    for page in DOCS.rglob("*.md"):
        text = page.read_text()
        text = LINK_TO_ROADMAP.sub(r"\1roadmap.md", text)
        text = fix_table_spacing(text)
        text = fix_numbered_indent(text)
        text = fix_list_spacing(text)
        text = harden_blockquotes(text)
        if page in lesson_meta:
            text = with_front_matter(lesson_meta[page], transform_headings(transform_lesson(text)))
        elif page.name != "index.md":
            text = transform_headings(text)
        page.write_text(text)
    return lessons


def build_nav(lessons: dict[str, list[tuple[str, str]]]) -> list:
    nav: list = [{"Home": "index.md"}, {"Roadmap": "roadmap.md"}]
    for folder, (name, _) in PHASES.items():
        nav.append({f"{folder[:2]} · {name}": [{title: path} for title, path in lessons[folder]]})
    nav.append({"Interview bank": [{title: f"interview/{name}"} for title, name in INTERVIEW_PAGES]})
    nav.append({"Reading list": "reading-list.md"})
    return nav


def write_config(lessons: dict[str, list[tuple[str, str]]]) -> Path:
    config = yaml.safe_load((ROOT / "site" / "mkdocs.template.yml").read_text())
    config["theme"]["custom_dir"] = str(ROOT / "site" / "theme")
    config["nav"] = build_nav(lessons)
    config.setdefault("extra", {})["contents"] = [
        {
            "code": folder[:2],
            "name": name,
            "blurb": blurb,
            "count": len(lessons[folder]),
            "url": lessons[folder][0][1].removesuffix(".md") + "/",
        }
        for folder, (name, blurb) in PHASES.items()
    ]
    path = BUILD / "mkdocs.yml"
    path.write_text(yaml.safe_dump(config, allow_unicode=True, sort_keys=False, width=120))
    return path


def index_search() -> int:
    """Pagefind reads the built HTML (only elements marked data-pagefind-body) and writes out/pagefind/."""
    command = [sys.executable, "-m", "pagefind", "--site", str(OUT), "--exclude-selectors", ".headerlink"]
    return subprocess.call(command, stdout=subprocess.DEVNULL)


def main() -> int:
    stage_only = "--stage" in sys.argv
    serve = "--serve" in sys.argv
    lessons = stage()
    config = write_config(lessons)
    print(f"staged {sum(len(v) for v in lessons.values())} lessons → {BUILD.relative_to(ROOT)}")
    if stage_only:
        return 0
    command = [sys.executable, "-m", "mkdocs", "serve" if serve else "build", "-f", str(config)]
    if not serve:
        command.append("--strict")
    env = {**os.environ, "NO_MKDOCS_2_WARNING": "true"}
    status = subprocess.call(command, env=env)
    if status or serve:
        return status
    status = index_search()
    if status:
        print("pagefind failed: the site builds, but search will be empty")
    else:
        print(f"search index → {(OUT / 'pagefind').relative_to(ROOT)}")
    return status


if __name__ == "__main__":
    sys.exit(main())
