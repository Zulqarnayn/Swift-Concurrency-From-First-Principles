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
  7. theme: every lesson has an eyebrow and a pager, no heading contains emoji, the Pagefind index exists,
     every font the stylesheet references exists and the fonts weigh < 300 KB together
  8. contrast: every text colour in site.css meets WCAG AA on the ground it is used on, in both schemes
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
HEADING = re.compile(r"<h[1-6][^>]*>(.*?)</h[1-6]>", re.DOTALL)
EMOJI = re.compile("[\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\u2300-\u23FF]")
STYLESHEET = ROOT / "site" / "theme" / "assets" / "site.css"
FONT_BUDGET = 300 * 1024

# (text token, ground token, minimum ratio). 4.5 for body-size text, 3 for large or purely decorative-adjacent text.
CONTRAST_PAIRS = [
    ("ink", "paper", 4.5),
    ("muted", "paper", 4.5),
    ("green", "paper", 4.5),
    ("ink", "code-bg", 4.5),
    ("muted", "code-bg", 4.5),
    ("green", "code-bg", 4.5),
    ("ink", "highlight", 4.5),
    ("tok-keyword", "code-bg", 4.5),
    ("tok-type", "code-bg", 4.5),
    ("tok-string", "code-bg", 4.5),
    ("tok-number", "code-bg", 4.5),
    ("tok-comment", "code-bg", 4.5),
    ("tok-attr", "code-bg", 4.5),
]


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


def relative_luminance(hex_colour: str) -> float:
    channels = [int(hex_colour[i : i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


def contrast(a: str, b: str) -> float:
    la, lb = sorted((relative_luminance(a), relative_luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def scheme_tokens(css: str) -> dict[str, dict[str, str]]:
    """Light tokens from the first :root block; dark tokens from the explicit [data-scheme="dark"] block."""
    def tokens(block: str) -> dict[str, str]:
        return dict(re.findall(r"--([\w-]+):\s*(#[0-9A-Fa-f]{6})\s*;", block))

    light = re.search(r":root\s*\{(.*?)\}", css, re.DOTALL)
    dark = re.search(r':root\[data-scheme="dark"\]\s*\{(.*?)\}', css, re.DOTALL)
    return {"light": tokens(light.group(1)) if light else {}, "dark": tokens(dark.group(1)) if dark else {}}


def check_contrast(problems: list[str]) -> list[str]:
    css = STYLESHEET.read_text()
    report = []
    automatic = re.search(r':root:not\(\[data-scheme="light"\]\)\s*\{(.*?)\}', css, re.DOTALL)
    explicit = re.search(r':root\[data-scheme="dark"\]\s*\{(.*?)\}', css, re.DOTALL)
    if not automatic or not explicit or automatic.group(1).split() != explicit.group(1).split():
        problems.append("dark tokens differ between the prefers-color-scheme block and the [data-scheme=dark] block")
    for scheme, tokens in scheme_tokens(css).items():
        for text, ground, minimum in CONTRAST_PAIRS:
            if text not in tokens or ground not in tokens:
                problems.append(f"contrast ({scheme}): token --{text} or --{ground} missing")
                continue
            ratio = contrast(tokens[text], tokens[ground])
            report.append(f"  {scheme:5} {text:>12} on {ground:<9} {ratio:5.2f}")
            if ratio < minimum:
                problems.append(f"contrast ({scheme}): --{text} on --{ground} is {ratio:.2f}, needs {minimum}")
    return report


def check_theme(problems: list[str]) -> None:
    if not (OUT / "pagefind" / "pagefind.js").exists():
        problems.append("no Pagefind index (out/pagefind/pagefind.js missing)")
    css = STYLESHEET.read_text()
    fonts = sorted(set(re.findall(r'url\("\.\./(fonts/[^"]+)"\)', css)))
    total = 0
    for font in fonts:
        built = OUT / font
        if not built.exists():
            problems.append(f"stylesheet references {font}, which is not in the build")
        else:
            total += built.stat().st_size
    if total > FONT_BUDGET:
        problems.append(f"fonts weigh {total // 1024} KB, budget is {FONT_BUDGET // 1024} KB")
    print(f"fonts: {len(fonts)} files, {total // 1024} KB")


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
        for leak in ("<!-- nav", 'markdown="1"', "&lt;details", "&lt;summary", "{: .kit }", "data-step=&quot;", "⭐"):
            if leak in html:
                problems.append(f"{label}: leaked '{leak}'")
        if label.startswith("lessons/"):
            if 'class="eyebrow"' not in html:
                problems.append(f"{label}: no eyebrow")
            if 'class="pager"' not in html:
                problems.append(f"{label}: no pager")
        for heading in HEADING.findall(html):
            if EMOJI.search(heading):
                problems.append(f"{label}: emoji in heading {re.sub(r'<[^>]+>', '', heading)[:60]!r}")
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

    check_theme(problems)
    report = check_contrast(problems)
    print(f"checked {len(pages)} pages, {checked_links} links, {len(report)} contrast pairs")
    if "-v" in sys.argv:
        print("\n".join(report))
    for problem in problems:
        print("✘", problem)
    if not problems:
        print("✔ site checks passed")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
