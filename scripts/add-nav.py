#!/usr/bin/env python3
"""Add (or refresh) prev/next navigation to every lesson. Idempotent: re-run after adding lessons."""
import re, glob, os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = sorted(glob.glob(os.path.join(root, "lessons", "P*", "*.md")),
               key=lambda p: (int(re.search(r"/P(\d+)-", p).group(1)), os.path.basename(p)))

def title(path):
    first = open(path).read().split("\n", 1)[0]
    m = re.match(r"# (P\d+\.\d+)", first)
    return m.group(1) if m else os.path.basename(path)

START, END = "<!-- nav:start -->", "<!-- nav:end -->"

def strip(text):
    return re.sub(rf"{START}.*?{END}\n*", "", text, flags=re.S)

for i, f in enumerate(files):
    d = os.path.dirname(f)
    def link(label, other):
        rel = os.path.relpath(other, d)
        if not rel.startswith("."):
            rel = "./" + rel
        return f"[{label}]({rel})"
    parts = []
    parts.append(link(f"← {title(files[i-1])}", files[i-1]) if i > 0 else "[← Roadmap](../../ROADMAP.md)")
    parts.append(f"[Roadmap](../../ROADMAP.md)") if 0 < i < len(files) - 1 else None
    parts.append(link(f"{title(files[i+1])} →", files[i+1]) if i < len(files) - 1 else "[Roadmap →](../../ROADMAP.md)")
    nav = f"{START}\n" + " · ".join(parts) + f"\n{END}\n"

    text = strip(open(f).read()).rstrip("\n")
    text = re.sub(r"(\n+---)+$", "", text).rstrip("\n")  # drop separators left by earlier runs
    head, _, rest = text.partition("\n")
    text = f"{head}\n\n{nav}\n{rest.lstrip(chr(10))}\n\n---\n\n{nav}"
    open(f, "w").write(text)
print(f"nav added to {len(files)} lessons")
