#!/usr/bin/env python3
"""Build the mdpre.app website.

Pages are body fragments with a front matter block. Each is injected into
templates/base.html and written to dist/, which is what gets deployed.
"""

import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEBSITE = ROOT / "website"
DIST = WEBSITE / "dist"

# Screenshots are shared with the README, so the website copies them from docs/
# at build time instead of keeping a second set in git.
IMAGES = [
    "icon.png",
    "preview.png",
    "edit.png",
    "split.png",
    "speech.png",
    "folder-mode.png",
    "dark-mode.png",
]

PLACEHOLDER = re.compile(r"\{\{\s*(\w+)\s*\}\}")


def parse(path):
    text = path.read_text(encoding="utf-8")
    meta = {}
    if text.startswith("---"):
        _, front, text = text.split("---", 2)
        for line in front.strip().splitlines():
            key, _, value = line.partition(":")
            meta[key.strip()] = value.strip()
    return meta, text.strip()


def render(template, meta, body):
    values = dict(meta, content=body)
    return PLACEHOLDER.sub(lambda m: values.get(m.group(1), ""), template)


def main():
    template = (WEBSITE / "templates" / "base.html").read_text(encoding="utf-8")

    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)

    shutil.copytree(WEBSITE / "assets", DIST / "assets")
    images = DIST / "assets" / "img"
    images.mkdir(parents=True, exist_ok=True)
    for name in IMAGES:
        shutil.copy2(ROOT / "docs" / name, images / name)

    for page in sorted((WEBSITE / "pages").glob("*.html")):
        meta, body = parse(page)
        (DIST / page.name).write_text(render(template, meta, body), encoding="utf-8")
        print(f"built {page.name}")


if __name__ == "__main__":
    main()
