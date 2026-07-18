#!/usr/bin/env python3
"""Generate the Been There app icon (Night Flight style) with Pillow.

Writes WorldTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024x1024).
iOS applies the rounded-corner mask itself, so this is a full square.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(
    ROOT, "WorldTracker", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"
)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()

    # Night sky: diagonal gradient deep indigo -> raised indigo
    top = (11, 17, 38)      # deep
    bottom = (27, 44, 85)   # raised
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x / SIZE * 0.35 + y / SIZE * 0.65)
            px[x, y] = lerp(top, bottom, 1 - t)

    draw = ImageDraw.Draw(img)

    # Faint stars
    import random

    rnd = random.Random(42)
    for _ in range(90):
        x = rnd.randint(0, SIZE - 1)
        y = rnd.randint(0, SIZE - 1)
        r = rnd.choice([1, 1, 2])
        a = rnd.randint(70, 160)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(220, 232, 255, a))

    # Globe: radial gradient sphere, aurora teal -> deep blue
    cx, cy, R = 470, 500, 300
    glow = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - R - 60, cy - R - 60, cx + R + 60, cy + R + 60], fill=(20, 60, 66))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    img = Image.blend(img, Image.blend(img, glow, 0.0), 0.0)  # keep img; glow applied below
    img = ImageChops_add(img, glow)

    draw = ImageDraw.Draw(img)
    c_in = (89, 227, 200)    # aurora teal
    c_mid = (46, 143, 184)   # ocean blue
    c_out = (24, 41, 84)     # deep
    lx, ly = cx - R * 0.38, cy - R * 0.42  # light source
    steps = 220
    for i in range(steps, 0, -1):
        t = i / steps
        r = R * t
        if t > 0.55:
            col = lerp(c_mid, c_out, (t - 0.55) / 0.45)
        else:
            col = lerp(c_in, c_mid, t / 0.55)
        ox = lx + (cx - lx) * t
        oy = ly + (cy - ly) * t
        draw.ellipse([ox - r, oy - r, ox + r, oy + r], fill=col)

    # Amber orbit arc (flight path)
    arc = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ad = ImageDraw.Draw(arc)
    bbox = [cx - R - 150, cy - R * 0.55, cx + R + 150, cy + R * 0.55]
    ad.arc(bbox, start=195, end=340, fill=(255, 183, 77, 255), width=26)
    arc = arc.rotate(-18, center=(cx, cy), resample=Image.BICUBIC)
    # soft shadow behind the arc for depth
    shadow = arc.filter(ImageFilter.GaussianBlur(14))
    img.paste((10, 14, 30), (0, 0), shadow)
    img.paste(arc, (0, 0), arc)

    # Plane dot at arc end
    pd = ImageDraw.Draw(img)
    ex, ey = cx + (R + 150) * math.cos(math.radians(-38)), cy + R * 0.55 * math.sin(
        math.radians(-38)
    )
    pd.ellipse([ex - 26, ey - 26, ex + 26, ey + 26], fill=(255, 210, 130))

    img.save(OUT, "PNG")
    print(f"wrote {OUT}")


def ImageChops_add(a, b):
    from PIL import ImageChops

    return ImageChops.add(a, b)


if __name__ == "__main__":
    main()
