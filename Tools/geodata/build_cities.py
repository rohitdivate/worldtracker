#!/usr/bin/env python3
"""Build cities.bin (format WTC2) + tz_countries.json from GeoNames.

cities.bin layout (little-endian):
  magic 'WTC2'
  u32 cityCount
  u32 stringPoolSize
  u16 tzCount, u16 countryCount
  cities: cityCount * ( f32 lat, f32 lon, u32 nameOff, u32 admin1Off,
                        u16 countryIdx, u16 tzIdx, u32 population )   [24 B]
          sorted by 1-degree cell (cell = latIdx*360 + lonIdx), then by -population
  cellIndex: (360*180 + 1) * u32  — first city index per cell (CSR style;
             count = next - current)
  stringPool: UTF-8 bytes (offsets point here; strings are length-prefixed u8)
  tzTable: tzCount * u32 offsets into string pool
  countryTable: countryCount * 2s ISO codes

Cities kept: population >= 500 (cities1000 floor) — everything; the file
stays small because strings dominate and repeat little.
"""
import io
import json
import os
import struct
import zipfile

HERE = os.path.dirname(__file__)
RAW = os.path.join(HERE, "raw")
OUTDIR = os.path.join(
    HERE, "..", "..", "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData"
)


def load_admin1():
    m = {}
    with open(os.path.join(RAW, "admin1.txt"), encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                m[parts[0]] = parts[1]  # "GB.ENG" -> "England"
    return m


def build_tz_countries():
    out = {}
    with open(os.path.join(RAW, "timeZones.txt"), encoding="utf-8") as f:
        next(f)  # header
        for line in f:
            parts = line.split("\t")
            if len(parts) >= 2:
                out[parts[1].strip()] = parts[0].strip()
    path = os.path.join(OUTDIR, "tz_countries.json")
    with open(path, "w") as f:
        json.dump(out, f, separators=(",", ":"), sort_keys=True)
    print(f"wrote {path}: {len(out)} timezones")
    return out


def main():
    admin1 = load_admin1()
    build_tz_countries()

    cities = []
    with zipfile.ZipFile(os.path.join(RAW, "cities1000.zip")) as z:
        data = z.read("cities1000.txt").decode("utf-8")
    # Exclude sections-of-cities and defunct places: keeping districts like
    # "Eixample" or "Mitte" makes nearest-city return neighborhoods instead of
    # the city people actually name.
    excluded_fcodes = {"PPLX", "PPLQ", "PPLW", "PPLH", "PPLCH"}
    for line in io.StringIO(data):
        p = line.rstrip("\n").split("\t")
        if len(p) < 18:
            continue
        if p[7] in excluded_fcodes:
            continue
        name = p[1]
        lat, lon = float(p[4]), float(p[5])
        cc = p[8]
        a1 = admin1.get(f"{cc}.{p[10]}", "") if p[10] else ""
        pop = int(p[14] or 0)
        tz = p[17]
        if len(cc) != 2 or not tz:
            continue
        cities.append((lat, lon, name, a1, cc, tz, pop))

    print(f"{len(cities)} cities")

    tz_ids = sorted({c[5] for c in cities})
    tz_idx = {t: i for i, t in enumerate(tz_ids)}
    ccs = sorted({c[4] for c in cities})
    cc_idx = {c: i for i, c in enumerate(ccs)}

    def cell(lat, lon):
        y = min(179, max(0, int(lat + 90)))
        x = min(359, max(0, int(lon + 180)))
        return y * 360 + x

    cities.sort(key=lambda c: (cell(c[0], c[1]), -c[6]))

    # String pool: dedupe strings, u8 length-prefixed UTF-8.
    pool = bytearray()
    offsets = {}

    def intern(s):
        if s in offsets:
            return offsets[s]
        b = s.encode("utf-8")[:255]
        off = len(pool)
        pool.append(len(b))
        pool.extend(b)
        offsets[s] = off
        return off

    recs = []
    for lat, lon, name, a1, cc, tz, pop in cities:
        recs.append(
            (lat, lon, intern(name), intern(a1), cc_idx[cc], tz_idx[tz], min(pop, 2**32 - 1))
        )

    # CSR cell index.
    n_cells = 360 * 180
    first = [0] * (n_cells + 1)
    for lat, lon, *_ in cities:
        first[cell(lat, lon) + 1] += 1
    for i in range(1, n_cells + 1):
        first[i] += first[i - 1]

    tz_offsets = [intern(t) for t in tz_ids]

    out = os.path.join(OUTDIR, "cities.bin")
    with open(out, "wb") as f:
        f.write(b"WTC2")
        f.write(struct.pack("<II", len(recs), len(pool)))
        f.write(struct.pack("<HH", len(tz_ids), len(ccs)))
        for lat, lon, no, ao, ci, ti, pop in recs:
            f.write(struct.pack("<ffIIHHI", lat, lon, no, ao, ci, ti, pop))
        f.write(struct.pack(f"<{n_cells + 1}I", *first))
        f.write(bytes(pool))
        f.write(struct.pack(f"<{len(tz_offsets)}I", *tz_offsets))
        for c in ccs:
            f.write(struct.pack("<2s", c.encode("ascii")))

    print(f"wrote {out}: {os.path.getsize(out)/1e6:.2f} MB")


if __name__ == "__main__":
    main()
