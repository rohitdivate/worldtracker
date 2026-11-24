#!/usr/bin/env python3
"""Generate the Been There app icon (Paper skin) with Pillow.

    python3 Tools/make_appicon.py                 # writes the asset
    python3 Tools/make_appicon.py --out /tmp/x.png --view pacific

The icon is the Home hero's globe: a matte ink ball on the paper ground,
countries you've been to inlaid in paper, the one you're in lit in the "now"
colour. It is drawn from the same 110m outlines the app ships
(WorldTrackerKit/.../GeoData/map110m.bin), so the icon and the app can't
drift apart.

iOS applies the rounded-corner mask itself, so this is a full, opaque square.
"""
import math
import os
import struct
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
SS = 2                      # supersampling for the vector layer
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MAP = os.path.join(
    ROOT, "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData", "map110m.bin"
)
OUT = os.path.join(
    ROOT, "WorldTracker", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"
)

# The Paper skin (ThemePalettes.swift), with "now" at fill strength.
PAPER = (233, 233, 230)
INK = (17, 17, 17)
LAND = (52, 52, 51)
NOW = (255, 74, 20)

# name: (centre longitude, centre latitude, current country, visited)
VIEWS = {
    "atlantic": (-42, 36, "US", ["GB", "IE", "FR", "ES", "PT", "IS", "MX", "MA", "IT", "DE", "NO"]),
    "americas": (-97, 33, "US", ["MX", "CO", "PE", "CU", "IS", "GB", "IE", "PT", "ES"]),
    "pacific": (128, -4, "AU", ["JP", "ID", "TH", "VN", "NZ", "IN", "PH", "MY", "KR"]),
}
DEFAULT_VIEW = "americas"


def read_shapes():
    """WTM1: header, countries (code, firstPoly, polyCount), polys
    (firstRing, ringCount), rings (firstPoint, count), points (lon, lat)."""
    with open(MAP, "rb") as f:
        data = f.read()
    assert data[:4] == b"WTM1", "unexpected map format"
    n_countries, n_polys, n_rings = struct.unpack_from("<III", data, 4)
    countries_off = 20
    polys_off = countries_off + n_countries * 8
    rings_off = polys_off + n_polys * 6
    points_off = rings_off + n_rings * 8

    shapes = {}
    for i in range(n_countries):
        base = countries_off + i * 8
        code = data[base:base + 2].decode("ascii")
        first_poly, poly_count = struct.unpack_from("<IH", data, base + 2)
        rings = []
        for p in range(first_poly, first_poly + poly_count):
            first_ring, ring_count = struct.unpack_from("<IH", data, polys_off + p * 6)
            for r in range(first_ring, first_ring + ring_count):
                first_point, count = struct.unpack_from("<II", data, rings_off + r * 8)
                rings.append([
                    struct.unpack_from("<ff", data, points_off + (first_point + k) * 8)
                    for k in range(count)
                ])
        shapes[code] = rings
    return shapes


def projector(lon0, lat0, cx, cy, radius):
    """Orthographic projection. Points on the far side are pulled to the
    limb, which keeps a polygon that straddles the horizon filled."""
    l0, p0 = math.radians(lon0), math.radians(lat0)
    sin_p0, cos_p0 = math.sin(p0), math.cos(p0)

    def project(lon, lat):
        lam, phi = math.radians(lon) - l0, math.radians(lat)
        cos_phi = math.cos(phi)
        x = cos_phi * math.sin(lam)
        y = cos_p0 * math.sin(phi) - sin_p0 * cos_phi * math.cos(lam)
        z = sin_p0 * math.sin(phi) + cos_p0 * cos_phi * math.cos(lam)
        if z < 0:
            norm = math.hypot(x, y) or 1.0
            x, y = x / norm, y / norm
        return (cx + radius * x, cy - radius * y), z

    return project


def light_layers(size, cx, cy, radius):
    """Per-pixel sphere lighting at low resolution (it is smooth, so it
    scales up cleanly): a multiply layer for the key light and an additive
    layer for the rim and the highlight."""
    small = 384
    scale = small / size
    shade = Image.new("L", (small, small), 255)
    glow = Image.new("RGB", (small, small), (0, 0, 0))
    sp, gp = shade.load(), glow.load()
    lx, ly, lz = -0.48, 0.62, 0.62                    # key: top left, in front
    norm = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / norm, ly / norm, lz / norm
    for j in range(small):
        for i in range(small):
            x = (i / scale - cx) / radius
            y = -(j / scale - cy) / radius
            d2 = x * x + y * y
            if d2 >= 1:
                continue
            z = math.sqrt(1 - d2)
            diffuse = max(0.0, x * lx + y * ly + z * lz)
            sp[i, j] = int(255 * min(1.0, 0.46 + 0.7 * diffuse))
            rim = max(0.0, 0.72 * x - 0.6 * y) * (1 - z) ** 2.4
            spec = diffuse ** 24 * 0.2
            gp[i, j] = (
                min(255, int(255 * (rim * 1.0 + spec))),
                min(255, int(255 * (rim * 0.32 + spec))),
                min(255, int(255 * (rim * 0.1 + spec))),
            )
    return (
        shade.resize((size, size), Image.BICUBIC),
        glow.resize((size, size), Image.BICUBIC),
    )


def render(view):
    lon0, lat0, current, visited = VIEWS[view]
    size = SIZE * SS
    cx, cy, radius = size * 0.5, size * 0.48, size * 0.395
    shapes = read_shapes()
    project = projector(lon0, lat0, cx, cy, radius)

    # The globe, flat: ocean disc, then countries, unvisited first.
    globe = Image.new("RGB", (size, size), INK)
    draw = ImageDraw.Draw(globe)

    def tone(code):
        if code == current:
            return NOW
        return PAPER if code in visited else LAND

    order = sorted(shapes, key=lambda c: (c == current, c in visited))
    for code in order:
        for ring in shapes[code]:
            projected = [project(lon, lat) for lon, lat in ring]
            if len(projected) < 3 or all(z < 0 for _, z in projected):
                continue
            points = [p for p, _ in projected]
            draw.polygon(points, fill=tone(code))
            draw.line(points + [points[0]], fill=INK, width=max(2, size // 700))

    shade, glow = light_layers(size, cx, cy, radius)
    globe = ImageChops.multiply(globe, Image.merge("RGB", (shade, shade, shade)))
    globe = ImageChops.add(globe, glow)

    disc = Image.new("L", (size, size), 0)
    ImageDraw.Draw(disc).ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius], fill=255
    )

    # Paper ground with a soft contact shadow, so the ball sits on the page.
    canvas = Image.new("RGB", (size, size), PAPER)
    shadow = Image.new("L", (size, size), 0)
    ImageDraw.Draw(shadow).ellipse(
        [cx - radius * 0.74, cy + radius * 0.95, cx + radius * 0.74, cy + radius * 1.11],
        fill=120,
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.022))
    canvas.paste(Image.new("RGB", (size, size), (60, 60, 58)), mask=shadow)
    canvas.paste(globe, mask=disc)
    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    args = sys.argv[1:]
    view = args[args.index("--view") + 1] if "--view" in args else DEFAULT_VIEW
    out = args[args.index("--out") + 1] if "--out" in args else OUT
    icon = render(view)
    assert icon.mode == "RGB" and icon.size == (SIZE, SIZE)
    icon.save(out)
    print(f"wrote {out} ({view})")


if __name__ == "__main__":
    main()
