#!/usr/bin/env python3
"""Compose App Store panels: a caption over a framed device shot.

    python3 Tools/make_screenshot_panels.py docs/screenshots docs/screenshots/framed

Reads the raw 1320x2868 captures named in SHOTS below and writes same-size
panels. Search results show roughly three screenshots inline, at a size where
11pt UI text is unreadable, so the caption is what actually gets read. Keep
each one under about five words and check it at thumbnail size.

Ground and typeface deliberately match the app's Night Flight theme (SF
Rounded, indigo, aurora bloom) so the device edge dissolves into the panel
instead of reading as a sticker. Needs Pillow.
"""

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
import sys, os

W, H = 1320, 2868
ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"

# Raw capture -> caption. Order is the listing order.
SHOTS = [
    ("01-overview.png", "Every day, logged automatically"),
    ("02-calendar.png", "A year of flags"),
    ("03-globe.png", "Your world, lit up"),
    ("04-trips.png", "Trips it built for you"),
    ("05-wrapped-days-away.png", "Days away from home"),
]


def font(size, weight="Bold"):
    f = ImageFont.truetype(ROUNDED, size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass  # non-variable build of the face; the default weight still reads
    return f


def ground():
    """Indigo gradient plus two blurred blooms, added rather than blended so
    the blooms lift the gradient instead of washing it out."""
    bg = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(bg)
    top, bot = (9, 13, 28), (17, 25, 51)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)],
               fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

    glow = Image.new("RGB", (W, H), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for cx, cy, radius, col in ((430, 300, 620, (14, 92, 84)),
                                (980, 120, 520, (44, 40, 110))):
        for i in range(28):
            k = 1 - i / 28
            r = int(radius * k)
            gd.ellipse([cx - r, cy - r, cx + r, cy + r],
                       fill=tuple(int(c * (1 - k) * 0.5) for c in col))
    return ImageChops.add(bg, glow.filter(ImageFilter.GaussianBlur(150)))


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def wrap(draw, text, f, maxw):
    lines, cur = [], ""
    for word in text.split():
        trial = (cur + " " + word).strip()
        if draw.textlength(trial, font=f) <= maxw:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def panel(shot_path, caption, out_path, dev_w=980, dev_top=540):
    bg = ground()
    d = ImageDraw.Draw(bg)

    f = font(84)
    lines = wrap(d, caption, f, W - 200)
    if len(lines) > 2:                      # drop a size rather than run three deep
        f = font(72)
        lines = wrap(d, caption, f, W - 180)
    lh = int(f.size * 1.16)
    y = 250 - (len(lines) - 1) * lh // 2
    for line in lines:
        d.text((W // 2, y), line, font=f, fill=(245, 248, 255), anchor="mt")
        y += lh

    shot = Image.open(shot_path).convert("RGB")
    dev_h = round(dev_w * shot.height / shot.width)
    dev = rounded(shot.resize((dev_w, dev_h), Image.LANCZOS), round(dev_w * 0.055))
    r = round(dev_w * 0.055)
    x = (W - dev_w) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x + 10, dev_top + 26, x + dev_w - 10, dev_top + dev_h + 26], r,
        fill=(0, 0, 0, 150))
    out = Image.alpha_composite(bg.convert("RGBA"),
                               shadow.filter(ImageFilter.GaussianBlur(38)))

    out.alpha_composite(dev, (x, dev_top))
    ImageDraw.Draw(out).rounded_rectangle(
        [x, dev_top, x + dev_w - 1, dev_top + dev_h - 1], r,
        outline=(255, 255, 255, 34), width=3)

    out.convert("RGB").save(out_path, quality=95)
    print("wrote", out_path)


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "docs/screenshots"
    dst = sys.argv[2] if len(sys.argv) > 2 else "docs/screenshots/framed"
    os.makedirs(dst, exist_ok=True)
    for name, caption in SHOTS:
        panel(os.path.join(src, name), caption, os.path.join(dst, name))
