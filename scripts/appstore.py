#!/usr/bin/env python3
"""Builds the App Store screenshot set from the raw window captures in docs/.

    python3 scripts/appstore.py

Raw captures come from `screencapture -o -x -l <windowID>` on a 1280x800 window,
which yields 2560x1600 with transparent corners. See the screenshot notes in
memory for how to take them. This script only composes; it never captures.

Output is 2880x1800 RGB with no alpha, which is what the store requires.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 2880, 1800
SF = "/System/Library/Fonts/SFNS.ttf"
DOCS = "docs"
OUT = "docs/screenshot-appstore"

# The app icon's own gradient, lightened. Lightening desaturates it slightly,
# which is the grey cast we wanted; the raw icon colours read too heavy.
ICON_TOP, ICON_BOTTOM = (86, 122, 216), (43, 81, 209)
LIGHTEN = 0.28

# Hero geometry. The list aligns to the top of the back window, and the cascade
# bleeds off the bottom right so the set implies more app than fits.
HERO_WIN = (960, 400, 1500)          # x, y, width of the back window
HERO_STEP = (280, 340)               # each successive window shifts by this
HERO_LIST_GAP = 130
HERO_OPTICAL = 22                    # text draws from its ascent box, not cap height

TITLE = "The Markdown previewer for developers"
FEATURES = [
    "Preview in GitHub style",
    "Make quick edits",
    "Write and preview side by side",
    "Reload as you save",
    "Listen while you work",
    "Open from the terminal",
    "Browse a whole folder",
    "Export as PDF and HTML",
    "Count words and tokens",
]

# Order matters: proven core first, then the differentiators. AI cost estimation is
# deliberately absent, see the positioning notes in memory.
SHOTS = [
    ("2-preview.png", "preview.png",     "Renders exactly like GitHub"),
    ("3-edit.png",    "edit.png",        "Quick edits without switching apps"),
    ("4-speech.png",  "speech.png",      "Listen to any document, and follow along"),
    ("5-split.png",   "split.png",       "Edit on the left, see the result on the right"),
    ("7-folder.png",  "folder-mode.png", "Browse a whole folder of documentation"),
    ("8-dark.png",    "dark-mode.png",   "Light and dark, follows your system"),
]


def font(size, weight="Bold"):
    f = ImageFont.truetype(SF, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def lighten(colour, amount):
    return tuple(round(v + (255 - v) * amount) for v in colour)


def gradient():
    top, bottom = lighten(ICON_TOP, LIGHTEN), lighten(ICON_BOTTOM, LIGHTEN)
    strip = Image.new("RGB", (1, H))
    px = strip.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return strip.resize((W, H)).convert("RGBA")


def place(canvas, path, width, xy):
    """Pastes a window with a soft shadow built from its own alpha, so the
    rounded corners are respected rather than boxed."""
    shot = Image.open(path).convert("RGBA")
    shot = shot.resize((width, round(shot.height * width / shot.width)), Image.LANCZOS)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.paste(Image.new("RGBA", shot.size, (0, 0, 0, 115)), (xy[0], xy[1] + 32), shot)
    canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(48)))
    canvas.paste(shot, xy, shot)
    return canvas


def wrap(draw, text, f, max_width):
    words, lines, current = text.split(), [], ""
    for word in words:
        trial = (current + " " + word).strip()
        if draw.textlength(trial, font=f) <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def build_hero(out_path):
    x, y, width = HERO_WIN
    canvas = gradient()
    canvas = place(canvas, f"{DOCS}/speech.png", width, (x, y))
    canvas = place(canvas, f"{DOCS}/edit.png", width, (x + HERO_STEP[0], y + HERO_STEP[1]))
    canvas = place(canvas, f"{DOCS}/preview.png", width,
                   (x + HERO_STEP[0] * 2, y + HERO_STEP[1] * 2))

    d = ImageDraw.Draw(canvas)
    ft = font(108)
    d.text(((W - d.textlength(TITLE, font=ft)) / 2, 120), TITLE, font=ft, fill=(255, 255, 255))

    fl = font(50, "Medium")
    ly = y - HERO_OPTICAL
    for item in FEATURES:
        d.text((190, ly), item, font=fl, fill=(240, 245, 255))
        ly += HERO_LIST_GAP

    canvas.convert("RGB").save(out_path)


def place_opaque(canvas, path, width, xy):
    """Like place, but flattens the window onto black first.

    Terminal profiles often have transparency on, and the capture keeps that
    alpha, so whatever sits behind shows through the terminal body. Compositing
    onto black gives what it looks like over an opaque backdrop. The original
    alpha is thresholded back on so the rounded corners survive.
    """
    shot = Image.open(path).convert("RGBA")
    flat = Image.alpha_composite(Image.new("RGBA", shot.size, (0, 0, 0, 255)), shot)
    flat.putalpha(shot.getchannel("A").point(lambda v: 255 if v > 8 else 0))
    tmp = path + ".opaque.png"
    flat.save(tmp)
    try:
        return place(canvas, tmp, width, xy)
    finally:
        os.remove(tmp)


def build_cli(out_path):
    """Terminal in front of the app, since the point is that one drives the other.
    Two windows rather than one, so it cannot use the plain feature layout."""
    canvas = gradient()
    canvas = place(canvas, f"{DOCS}/preview.png", 1900, (490, 400))
    canvas = place_opaque(canvas, f"{DOCS}/terminal.png", 1150, (300, 1240))
    d = ImageDraw.Draw(canvas)
    f = font(104)
    text = "Open it from your terminal with mdp"
    d.text(((W - d.textlength(text, font=f)) / 2, 150), text, font=f, fill=(255, 255, 255))
    canvas.convert("RGB").save(out_path)


def build_feature(shot_path, caption, out_path):
    canvas = gradient()
    canvas = place(canvas, shot_path, 2080, ((W - 2080) // 2, 400))
    d = ImageDraw.Draw(canvas)
    f = font(104)
    lines = wrap(d, caption, f, 2400)
    ty = 150
    for line in lines:
        d.text(((W - d.textlength(line, font=f)) / 2, ty), line, font=f, fill=(255, 255, 255))
        ty += 126
    canvas.convert("RGB").save(out_path)


def main():
    os.makedirs(OUT, exist_ok=True)
    build_hero(f"{OUT}/1-hero.png")
    print(f"  1-hero.png")

    missing = []
    for out_name, shot, caption in SHOTS:
        src = f"{DOCS}/{shot}"
        if not os.path.exists(src):
            missing.append(shot)
            continue
        build_feature(src, caption, f"{OUT}/{out_name}")
        print(f"  {out_name}")

    if os.path.exists(f"{DOCS}/terminal.png"):
        build_cli(f"{OUT}/6-cli.png")
        print("  6-cli.png")
    else:
        print("  SKIPPED, no docs/terminal.png yet", file=sys.stderr)

    for name in missing:
        print(f"  SKIPPED, no docs/{name} yet", file=sys.stderr)

    for name in sorted(os.listdir(OUT)):
        if name.endswith(".png"):
            im = Image.open(f"{OUT}/{name}")
            flag = "" if (im.size == (W, H) and im.mode == "RGB") else "  <-- WRONG, store will reject"
            print(f"  {name:16} {im.size} {im.mode}{flag}")


if __name__ == "__main__":
    main()
