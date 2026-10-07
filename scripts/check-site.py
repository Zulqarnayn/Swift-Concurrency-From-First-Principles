#!/usr/bin/env python3
"""Post-build assertions for the course website (run after scripts/build-site.py).

    python3 scripts/check-site.py

Checks (stdlib only):
  1. every expected page exists
  2. no leaked build artifacts (nav comments, markdown="1", literal <details>, attr_list text)
  3. per page: number of <pre> in the output == number of fenced code blocks in the staged source
     (catches markdown that stayed unparsed inside <details>)
  4. per page: number of list items in the source == number of <li> in the article
     (catches lists that collapsed into a paragraph)
  5. per page: number of <table> == number of markdown tables in the source, and every row has the header's cell count
     (catches Python-Markdown vs GitHub differences, e.g. pipes inside backticks)
  6. every relative <a href> in the built HTML points at a file that exists
"""
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / ".site-build" / "docs"
OUT = ROOT / ".site-build" / "out"

FENCE = re.compile(r"^\s*```")
LIST_ITEM = re.compile(r"^\s*([-*+]|\d+\.)\s+\S")
ARTICLE = re.compile(r"<article.*?</article>", re.DOTALL)
TABLE_SEPARATOR = re.compile(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$")


def output_for(source: Path) -> Path:
    relative = source.relative_to(DOCS).with_suffix("")
    return OUT / ("index.html" if relative.as_posix() == "index" else f"{relative.as_posix()}/index.html")


def source_stats(text: str) -> tuple[int, int, int]:
    """(fenced code blocks, markdown tables, list items) outside of fences."""
    fences = 0
    tables = 0
    items = 0
    inside = False
    for line in text.splitlines():
        if FENCE.match(line):
            inside = not inside
            if inside:
                fences += 1
            continue
        if inside:
            continue
        if TABLE_SEPARATOR.match(line):
            tables += 1
        elif LIST_ITEM.match(line) and not line.lstrip().startswith("|"):
            items += 1
    return fences, tables, items


class PageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.links: list[str] = []
        self.pre = 0
        self.tables: list[list[int]] = []  # per table: cell count for each row
        self._row: list[str] | None = None
        self._in_table = False

    def handle_starttag(self, tag: str, attrs: list) -> None:
        if tag == "a":
            href = dict(attrs).get("href")
            if href:
                self.links.append(href)
        elif tag == "pre":
            self.pre += 1
        elif tag == "table":
            self.tables.append([])
            self._in_table = True
        elif tag == "tr" and self._in_table:
            self._row = []
        elif tag in ("td", "th") and self._row is not None:
            self._row.append(tag)

    def handle_endtag(self, tag: str) -> None:
        if tag == "tr" and self._row is not None:
            self.tables[-1].append(len(self._row))
            self._row = None
        elif tag == "table":
            self._in_table = False


def link_target_exists(page_html: Path, href: str) -> bool:
    parsed = urlparse(href)
    if parsed.scheme or href.startswith(("mailto:", "#")) or not parsed.path:
        return True
    page_url = "/" + page_html.parent.relative_to(OUT).as_posix().rstrip(".") + "/"
    page_url = page_url.replace("//", "/")
    target = unquote(urlparse(urljoin("http://site" + page_url, parsed.path)).path)
    candidate = OUT / target.lstrip("/")
    if target.endswith("/"):
        return (candidate / "index.html").exists()
    return candidate.exists() or (candidate / "index.html").exists()


def main() -> int:
    if not OUT.exists():
        print("no build output: run scripts/build-site.py first")
        return 2
    problems: list[str] = []
    pages = sorted(DOCS.rglob("*.md"))
    expected = 86 + 1 + 1 + 4 + 1  # lessons, home, roadmap, interview pages, reading list
    if len(pages) != expected:
        problems.append(f"expected {expected} pages, staged {len(pages)}")

    checked_links = 0
    for source in pages:
        label = source.relative_to(DOCS).as_posix()
        out = output_for(source)
        if not out.exists():
            problems.append(f"{label}: no built page")
            continue
        html = out.read_text()
        for leak in ("<!-- nav", 'markdown="1"', "&lt;details", "&lt;summary", "{ .lesson-meta }", "{: .lesson-meta"):
            if leak in html:
                problems.append(f"{label}: leaked '{leak}'")
        parser = PageParser()
        parser.feed(html)
        fences, tables, items = source_stats(source.read_text())
        article = ARTICLE.search(html)
        rendered_items = article.group(0).count("<li") if article else 0
        if rendered_items != items and source.name != "index.md":
            problems.append(f"{label}: {items} list items in source but {rendered_items} <li> in output (list not parsed?)")
        if parser.pre != fences:
            problems.append(f"{label}: {fences} fenced blocks in source but {parser.pre} <pre> in output")
        if len(parser.tables) != tables:
            problems.append(f"{label}: {tables} tables in source but {len(parser.tables)} <table> in output")
        for index, rows in enumerate(parser.tables):
            if len(set(rows)) > 1:
                problems.append(f"{label}: table {index + 1} has uneven rows {rows}")
        for href in parser.links:
            checked_links += 1
            if not link_target_exists(out, href):
                problems.append(f"{label}: broken link {href}")

    print(f"checked {len(pages)} pages, {checked_links} links")
    for problem in problems:
        print("✘", problem)
    if not problems:
        print("✔ site checks passed")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
