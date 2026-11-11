#!/usr/bin/env python3
"""Compose App Store panels: a caption over a framed device shot.

    python3 Tools/make_screenshot_panels.py docs/screenshots docs/screenshots/framed

Reads the raw 1320x2868 captures named in SHOTS below and writes same-size
panels. Search results show roughly three screenshots inline, at a size where
11pt UI text is unreadable, so the caption is what actually gets read. Keep
each one under about five words and check it at thumbnail size.

Ground and type match the app's default Paper skin: the flat paper grey, a
compressed black caps headline (the app's poster face) and a tracked mono
label in the "now" colour. The device sits in an ink bezel so its white cards
don't dissolve into the light ground. Needs Pillow and macOS system fonts.
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os
import sys

W, H = 1320, 2868
SANS = "/System/Library/Fonts/SFNS.ttf"
MONO = "/System/Library/Fonts/SFNSMono.ttf"

# The Paper skin (ThemePalettes.swift).
PAPER = (233, 233, 230)
INK = (17, 17, 17)
NOW = (185, 58, 8)

# Raw capture -> (label, caption). Order is the listing order.
SHOTS = [
    ("01-overview.png", "Automatic", "Every day abroad, counted"),
    ("02-limit.png", "Schengen 90/180", "Know your days left"),
    ("03-forecast.png", "Planned trips", "See trouble before you book"),
    ("04-calendar.png", "Calendar", "A year of flags"),
    ("05-passport.png", "Passport", "Stamps for every country"),
    ("06-countries.png", "Your world", "Every country, ranked by days"),
]


def poster(size):
    """SF at its narrowest width and heaviest weight: the app's poster role."""
    f = ImageFont.truetype(SANS, size)
    try:
        axes = f.get_variation_axes()
        values = []
        for axis in axes:
            name = axis["name"]
            name = name.decode() if isinstance(name, bytes) else name
            if name == "Width":
                values.append(axis["minimum"])
            elif name == "Weight":
                values.append(900)
            elif name == "Optical Size":
                values.append(axis["maximum"])
            else:
                values.append(axis["minimum"])
        f.set_variation_by_axes(values)
    except Exception:
        pass  # non-variable build of the face; the default cut still reads
    return f


def mono(size):
    f = ImageFont.truetype(MONO, size)
    try:
        f.set_variation_by_name("Bold")
    except Exception:
        pass
    return f


def tracked(draw, centre_x, y, text, f, fill, tracking):
    """Pillow has no letter spacing, so place the glyphs one at a time."""
    widths = [draw.textlength(ch, font=f) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = centre_x - total / 2
    for ch, w in zip(text, widths):
        draw.text((x, y), ch, font=f, fill=fill)
        x += w + tracking


def wrap(draw, text, f, maxw):
    """One line if it fits, otherwise the two-line break with the most even
    halves, so a caption never strands a single word. Three or more lines
    come back only when no two-line break fits; the caller drops a size."""
    words = text.split()
    if draw.textlength(text, font=f) <= maxw:
        return [text]
    best = None
    for k in range(1, len(words)):
        a, b = " ".join(words[:k]), " ".join(words[k:])
        wa, wb = draw.textlength(a, font=f), draw.textlength(b, font=f)
        if max(wa, wb) <= maxw and (best is None or abs(wa - wb) < best[0]):
            best = (abs(wa - wb), [a, b])
    return best[1] if best else words


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def panel(shot_path, label, caption, out_path, dev_w=960, bezel=18, bottom=96):
    bg = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(bg)

    tracked(d, W // 2, 150, label.upper(), mono(40), NOW, 9)

    size = 176
    f = poster(size)
    lines = wrap(d, caption.upper(), f, W - 150)
    while len(lines) > 2:                   # drop a size rather than run three deep
        size -= 12
        f = poster(size)
        lines = wrap(d, caption.upper(), f, W - 150)
    lh = int(size * 0.98)
    y = 236 if len(lines) == 2 else 236 + lh // 2
    for line in lines:
        d.text((W // 2, y), line, font=f, fill=INK, anchor="mt")
        y += lh

    shot = Image.open(shot_path).convert("RGB")
    dev_h = round(dev_w * shot.height / shot.width)
    r = round(dev_w * 0.115)
    dev = rounded(shot.resize((dev_w, dev_h), Image.LANCZOS), r)
    x = (W - dev_w) // 2
    top = H - bottom - bezel - dev_h

    body = [x - bezel, top - bezel, x + dev_w + bezel, top + dev_h + bezel]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [body[0] + 8, body[1] + 30, body[2] - 8, body[3] + 30], r + bezel,
        fill=(40, 40, 38, 110))
    out = Image.alpha_composite(bg.convert("RGBA"),
                               shadow.filter(ImageFilter.GaussianBlur(34)))
    ImageDraw.Draw(out).rounded_rectangle(body, r + bezel, fill=INK + (255,))
    out.alpha_composite(dev, (x, top))

    out.convert("RGB").save(out_path, optimize=True)
    print("wrote", out_path)


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots"
    dst = sys.argv[2] if len(sys.argv) > 2 else "docs/screenshots/framed"
    os.makedirs(dst, exist_ok=True)
    for name, label, caption in SHOTS:
        panel(os.path.join(src, name), label, caption, os.path.join(dst, name))
