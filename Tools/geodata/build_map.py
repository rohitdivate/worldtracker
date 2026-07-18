#!/usr/bin/env python3
"""Build map110m.bin (format WTM1) — lightweight country outlines for the Map tab.

Layout (little-endian):
  magic 'WTM1'
  u32 countryCount, polyCount, ringCount, pointCount
  countries: countryCount * ( 2s isoCode, u32 firstPoly, u16 polyCount )
  polygons:  polyCount * ( u32 firstRing, u16 ringCount )
  rings:     ringCount * ( u32 firstPoint, u32 pointCount )
  points:    pointCount * ( f32 lon, f32 lat )

Only outer rings are kept (holes don't matter for filled map overlays at 110m).
"""
import json
import os
import struct

import importlib.util

HERE = os.path.dirname(__file__)
spec = importlib.util.spec_from_file_location(
    "build_countries", os.path.join(HERE, "build_countries.py")
)
bc = importlib.util.module_from_spec(spec)
spec.loader.exec_module.__self__ if False else None
spec.loader.exec_module(bc)  # reuse iso2 + rings_of

RAW = os.path.join(HERE, "raw", "ne_110m.geojson")
OUT = os.path.join(
    HERE, "..", "..", "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData",
    "map110m.bin",
)


def main():
    with open(RAW, encoding="utf-8") as f:
        fc = json.load(f)

    countries = {}
    for feat in fc["features"]:
        code = bc.iso2(feat["properties"])
        for poly in bc.rings_of(feat["geometry"]):
            outer = [(float(lon), float(lat)) for lon, lat in poly[0]]
            if len(outer) >= 4:
                countries.setdefault(code, []).append([outer])

    codes = sorted(countries)
    country_recs, poly_recs, ring_recs, points = [], [], [], []
    for code in codes:
        fp = len(poly_recs)
        for poly in countries[code]:
            fr = len(ring_recs)
            for ring in poly:
                ring_recs.append((len(points), len(ring)))
                points.extend(ring)
            poly_recs.append((fr, len(poly)))
        country_recs.append((code, fp, len(poly_recs) - fp))

    with open(OUT, "wb") as f:
        f.write(b"WTM1")
        f.write(struct.pack("<IIII", len(country_recs), len(poly_recs), len(ring_recs), len(points)))
        for code, fp, np_ in country_recs:
            f.write(struct.pack("<2sIH", code.encode("ascii"), fp, np_))
        for fr, nr in poly_recs:
            f.write(struct.pack("<IH", fr, nr))
        for fpt, npt in ring_recs:
            f.write(struct.pack("<II", fpt, npt))
        for lon, lat in points:
            f.write(struct.pack("<ff", lon, lat))

    print(f"wrote {OUT}: {os.path.getsize(OUT)/1e6:.2f} MB, {len(codes)} countries")


if __name__ == "__main__":
    main()
