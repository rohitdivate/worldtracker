#!/usr/bin/env python3
"""Build countries50m.bin (format WTC1) from Natural Earth 1:50m admin-0.

Layout (little-endian):
  magic 'WTC1'
  u32 countryCount, polyCount, ringCount, pointCount
  countries: countryCount * ( 2s isoCode, u32 firstPoly, u16 polyCount )
  polygons:  polyCount * ( u32 firstRing, u16 ringCount,
                           f32 minLon, f32 minLat, f32 maxLon, f32 maxLat )
  rings:     ringCount * ( u32 firstPoint, u32 pointCount,
                           f32 minLon, f32 minLat, f32 maxLon, f32 maxLat )
  points:    pointCount * ( f32 lon, f32 lat )
  grid:      360*180 i16   (cell = latIdx*360 + lonIdx; latIdx 0 => lat -90..-89,
                            lonIdx 0 => lon -180..-179)
             value >= 0 : single candidate polygon index
             -1         : no candidates (open ocean)
             -2         : mixed -> look up candidate list
  u32 mixedCount
  mixed:     mixedCount * ( u32 cellIndex, u16 n, n * u16 polyIndex )

Ring 0 of each polygon is the outer boundary; further rings are holes.
Point-in-polygon = even-odd ray cast over all rings (bbox-prefiltered).
"""
import json
import os
import struct
import sys

RAW = os.path.join(os.path.dirname(__file__), "raw", "ne_50m.geojson")
OUT = os.path.join(
    os.path.dirname(__file__),
    "..", "..", "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData",
    "countries50m.bin",
)

# ADM0_A3 -> ISO2 for features where ISO_A2_EH is -99 or unusable.
A3_FIX = {
    "FRA": "FR", "NOR": "NO", "KOS": "XK", "CYN": "CY", "SOL": "SO",
    "SDS": "SS", "PSX": "PS", "SAH": "EH", "ATC": "AU", "KAS": "IN",
    "IOA": "IO", "USG": "CU", "BJN": "CO", "SER": "RS", "SCR": "CN",
    "CNM": "CY", "ESB": "CY", "WSB": "CY", "PGA": "CN", "SPI": "ES",
}


def iso2(props):
    for key in ("ISO_A2_EH", "ISO_A2"):
        v = props.get(key)
        if v and v != "-99" and len(v) == 2:
            return v.upper()
    a3 = props.get("ADM0_A3")
    if a3 in A3_FIX:
        return A3_FIX[a3]
    raise SystemExit(
        f"Unmapped country: NAME={props.get('NAME')} ADM0_A3={a3} "
        f"ISO_A2_EH={props.get('ISO_A2_EH')} — extend A3_FIX"
    )


def rings_of(geom):
    if geom["type"] == "Polygon":
        yield geom["coordinates"]
    elif geom["type"] == "MultiPolygon":
        yield from geom["coordinates"]


def sanity_check_ring(ring, name):
    prev = None
    for lon, lat in ring:
        if not (-180.0001 <= lon <= 180.0001 and -90.0001 <= lat <= 90.0001):
            raise SystemExit(f"{name}: coordinate out of range ({lon},{lat})")
        if prev is not None and abs(lon - prev) > 180:
            raise SystemExit(
                f"{name}: ring crosses the antimeridian (lon jump {prev}->{lon}); "
                "needs splitting"
            )
        prev = lon


def main():
    with open(RAW, encoding="utf-8") as f:
        fc = json.load(f)

    # country iso -> list of polygons; polygon = list of rings; ring = [(lon,lat)]
    countries = {}
    for feat in fc["features"]:
        code = iso2(feat["properties"])
        name = feat["properties"].get("NAME", code)
        for poly in rings_of(feat["geometry"]):
            clean = []
            for ring in poly:
                pts = [(float(lon), float(lat)) for lon, lat in ring]
                if len(pts) >= 4:
                    sanity_check_ring(pts, f"{name}")
                    clean.append(pts)
            if clean:
                countries.setdefault(code, []).append(clean)

    codes = sorted(countries)
    print(f"{len(codes)} countries")

    country_recs = []
    poly_recs = []
    ring_recs = []
    points = []
    poly_owner = []  # polygon index -> country index

    for ci, code in enumerate(codes):
        first_poly = len(poly_recs)
        for poly in countries[code]:
            first_ring = len(ring_recs)
            pminlon = pminlat = 1e9
            pmaxlon = pmaxlat = -1e9
            for ring in poly:
                first_pt = len(points)
                rminlon = min(p[0] for p in ring)
                rmaxlon = max(p[0] for p in ring)
                rminlat = min(p[1] for p in ring)
                rmaxlat = max(p[1] for p in ring)
                points.extend(ring)
                ring_recs.append((first_pt, len(ring), rminlon, rminlat, rmaxlon, rmaxlat))
                pminlon = min(pminlon, rminlon)
                pminlat = min(pminlat, rminlat)
                pmaxlon = max(pmaxlon, rmaxlon)
                pmaxlat = max(pmaxlat, rmaxlat)
            poly_recs.append(
                (first_ring, len(poly), pminlon, pminlat, pmaxlon, pmaxlat)
            )
            poly_owner.append(ci)
        country_recs.append((code, first_poly, len(poly_recs) - first_poly))

    # Grid: candidate polygons per 1-degree cell (bbox intersection).
    grid = [[] for _ in range(360 * 180)]
    for pi, (_, _, minlon, minlat, maxlon, maxlat) in enumerate(poly_recs):
        x0 = max(0, int(minlon + 180))
        x1 = min(359, int(maxlon + 180))
        y0 = max(0, int(minlat + 90))
        y1 = min(179, int(maxlat + 90))
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                grid[y * 360 + x].append(pi)

    grid_vals = []
    mixed = []
    for idx, cands in enumerate(grid):
        if not cands:
            grid_vals.append(-1)
        elif len(cands) == 1:
            grid_vals.append(cands[0])
        else:
            grid_vals.append(-2)
            mixed.append((idx, cands))

    single_ok = all(0 <= v < 32767 or v in (-1, -2) for v in grid_vals)
    if not single_ok:
        raise SystemExit("polygon index exceeds i16 grid capacity")

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(b"WTC1")
        f.write(
            struct.pack(
                "<IIII", len(country_recs), len(poly_recs), len(ring_recs), len(points)
            )
        )
        for code, fp, np_ in country_recs:
            f.write(struct.pack("<2sIH", code.encode("ascii"), fp, np_))
        for fr, nr, a, b, c, d in poly_recs:
            f.write(struct.pack("<IHffff", fr, nr, a, b, c, d))
        for fp, np_, a, b, c, d in ring_recs:
            f.write(struct.pack("<IIffff", fp, np_, a, b, c, d))
        for lon, lat in points:
            f.write(struct.pack("<ff", lon, lat))
        f.write(struct.pack(f"<{len(grid_vals)}h", *grid_vals))
        f.write(struct.pack("<I", len(mixed)))
        for idx, cands in mixed:
            f.write(struct.pack("<IH", idx, len(cands)))
            f.write(struct.pack(f"<{len(cands)}H", *cands))

    size = os.path.getsize(OUT)
    print(
        f"wrote {OUT}: {size/1e6:.2f} MB, "
        f"{len(poly_recs)} polygons, {len(ring_recs)} rings, "
        f"{len(points)} points, {len(mixed)} mixed cells"
    )


if __name__ == "__main__":
    main()
