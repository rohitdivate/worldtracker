#!/usr/bin/env python3
"""Reference reader for the committed geodata binaries.

Implements the same lookup rules as the Swift GeoLookup and validates both the
binary artifacts and the semantics against the shared golden fixtures, so the
data is proven correct on Linux before the app ever runs.

Fixture semantics:
  country: "GB" exact | null expect-none | "*" any non-null | "~GB|FR" nearest-land fallback set
  cityContains: substring | "" skip | null expect-none
  tz: exact | "" skip | null expect-none
"""
import json
import math
import os
import struct
import sys

HERE = os.path.dirname(__file__)
GEO = os.path.join(
    HERE, "..", "..", "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData"
)
FIXTURES = os.path.join(
    HERE, "..", "..", "WorldTrackerKit", "Tests", "WorldTrackerKitTests",
    "Fixtures", "golden_lookups.json",
)


class Countries:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.buf = f.read()
        assert self.buf[:4] == b"WTC1"
        nC, nP, nR, nPt = struct.unpack_from("<IIII", self.buf, 4)
        off = 20
        self.countries = []
        for _ in range(nC):
            code, fp, np_ = struct.unpack_from("<2sIH", self.buf, off)
            self.countries.append((code.decode(), fp, np_))
            off += 8
        self.polys = []
        for _ in range(nP):
            self.polys.append(struct.unpack_from("<IHffff", self.buf, off))
            off += 22
        self.rings = []
        for _ in range(nR):
            self.rings.append(struct.unpack_from("<IIffff", self.buf, off))
            off += 24
        self.pts_off = off
        off += nPt * 8
        self.grid = struct.unpack_from(f"<{360*180}h", self.buf, off)
        off += 360 * 180 * 2
        (nMixed,) = struct.unpack_from("<I", self.buf, off)
        off += 4
        self.mixed = {}
        for _ in range(nMixed):
            idx, n = struct.unpack_from("<IH", self.buf, off)
            off += 6
            self.mixed[idx] = struct.unpack_from(f"<{n}H", self.buf, off)
            off += n * 2
        # polygon -> country
        self.owner = {}
        for ci, (_, fp, np_) in enumerate(self.countries):
            for pi in range(fp, fp + np_):
                self.owner[pi] = ci

    def point(self, i):
        return struct.unpack_from("<ff", self.buf, self.pts_off + i * 8)

    def in_ring(self, lon, lat, ring):
        fp, n, mnlo, mnla, mxlo, mxla = ring
        if not (mnlo <= lon <= mxlo and mnla <= lat <= mxla):
            return False
        inside = False
        x1, y1 = self.point(fp + n - 1)
        for i in range(n):
            x2, y2 = self.point(fp + i)
            if (y2 > lat) != (y1 > lat):
                xint = (x1 - x2) * (lat - y2) / (y1 - y2) + x2
                if lon < xint:
                    inside = not inside
            x1, y1 = x2, y2
        return inside

    def in_poly(self, lon, lat, pi):
        fr, nr, mnlo, mnla, mxlo, mxla = self.polys[pi]
        if not (mnlo <= lon <= mxlo and mnla <= lat <= mxla):
            return False
        # even-odd across outer + holes
        cnt = 0
        for ri in range(fr, fr + nr):
            if self.in_ring(lon, lat, self.rings[ri]):
                cnt += 1
        return cnt % 2 == 1

    def country_code(self, lat, lon):
        x = min(359, max(0, int(lon + 180)))
        y = min(179, max(0, int(lat + 90)))
        v = self.grid[y * 360 + x]
        if v == -1:
            return None
        cands = [v] if v >= 0 else self.mixed[y * 360 + x]
        for pi in cands:
            if self.in_poly(lon, lat, pi):
                return self.countries[self.owner[pi]][0]
        return None


class Cities:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.buf = f.read()
        assert self.buf[:4] == b"WTC2"
        self.nCity, self.poolSize = struct.unpack_from("<II", self.buf, 4)
        self.nTz, self.nCc = struct.unpack_from("<HH", self.buf, 12)
        self.city_off = 16
        off = self.city_off + self.nCity * 24
        self.first = struct.unpack_from(f"<{360*180+1}I", self.buf, off)
        off += (360 * 180 + 1) * 4
        self.pool_off = off
        off += self.poolSize
        self.tz_offsets = struct.unpack_from(f"<{self.nTz}I", self.buf, off)
        off += self.nTz * 4
        self.ccs = [
            struct.unpack_from("<2s", self.buf, off + i * 2)[0].decode()
            for i in range(self.nCc)
        ]

    def string(self, off):
        n = self.buf[self.pool_off + off]
        s = self.buf[self.pool_off + off + 1 : self.pool_off + off + 1 + n]
        return s.decode("utf-8")

    def city(self, i):
        lat, lon, no, ao, ci, ti, pop = struct.unpack_from(
            "<ffIIHHI", self.buf, self.city_off + i * 24
        )
        return lat, lon, no, ao, ci, ti, pop

    def nearest(self, lat, lon, max_km):
        y0 = min(179, max(0, int(lat + 90)))
        x0 = min(359, max(0, int(lon + 180)))
        best = None
        best_d = max_km * 1000
        max_rings = int(max_km / 111) + 2
        for r in range(0, max_rings + 1):
            found_this_ring = False
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    y = y0 + dy
                    x = (x0 + dx) % 360
                    if not (0 <= y < 180):
                        continue
                    c = y * 360 + x
                    for i in range(self.first[c], self.first[c + 1]):
                        clat, clon, no, ao, ci, ti, pop = self.city(i)
                        d = haversine(lat, lon, clat, clon)
                        if d < best_d:
                            best_d = d
                            best = (i, d)
                            found_this_ring = True
            if best is not None and r > int(best_d / 111000) + 1:
                break
        if best is None:
            return None
        i, d = best
        # Promotion rule: a "New Town"/suburb should yield to the metropolis
        # next door — if a city with >= max(50k, 10x) population lies within
        # 15 km, name that one instead.
        _, _, _, _, _, _, near_pop = self.city(i)
        threshold = max(50_000, near_pop * 10)
        promo = None
        promo_pop = 0
        y0 = min(179, max(0, int(lat + 90)))
        x0 = min(359, max(0, int(lon + 180)))
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                y = y0 + dy
                x = (x0 + dx) % 360
                if not (0 <= y < 180):
                    continue
                c = y * 360 + x
                for j in range(self.first[c], self.first[c + 1]):
                    clat, clon, _, _, _, _, pop = self.city(j)
                    if pop >= threshold and pop > promo_pop:
                        dj = haversine(lat, lon, clat, clon)
                        if dj <= 15_000:
                            promo = (j, dj)
                            promo_pop = pop
        if promo is not None:
            i, d = promo
        clat, clon, no, ao, ci, ti, pop = self.city(i)
        return {
            "name": self.string(no),
            "admin1": self.string(ao),
            "country": self.ccs[ci],
            "tz": self.string(self.tz_offsets[ti]),
            "distance_m": d,
        }


def haversine(lat1, lon1, lat2, lon2):
    r = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1, math.sqrt(a)))


def resolve(countries, cities, lat, lon):
    code = countries.country_code(lat, lon)
    fallback = False
    hit = cities.nearest(lat, lon, 50)
    if code is None:
        near = cities.nearest(lat, lon, 25)
        if near is not None:
            code = near["country"]
            fallback = True
    city = hit["name"] if hit else None
    tz = hit["tz"] if hit else None
    return code, city, tz, fallback


def main():
    countries = Countries(os.path.join(GEO, "countries50m.bin"))
    cities = Cities(os.path.join(GEO, "cities.bin"))
    with open(FIXTURES, encoding="utf-8") as f:
        fixtures = json.load(f)

    failures = []
    for fx in fixtures:
        code, city, tz, fallback = resolve(countries, cities, fx["lat"], fx["lon"])
        want = fx["country"]
        ok = True
        if want is None:
            ok = code is None
        elif want == "*":
            ok = code is not None
        elif isinstance(want, str) and want.startswith("~"):
            allowed = want[1:].split("|")
            ok = code in allowed
        elif isinstance(want, str) and "|" in want:
            ok = code in want.split("|")
        else:
            ok = code == want
        if not ok:
            failures.append(f"{fx['name']}: country={code!r} want {want!r}")
            continue
        cc = fx.get("cityContains")
        if cc is None and "cityContains" in fx and fx["cityContains"] is None:
            if city is not None:
                failures.append(f"{fx['name']}: city={city!r} want None")
        elif cc:
            if not city or cc.lower() not in city.lower():
                failures.append(f"{fx['name']}: city={city!r} want contains {cc!r}")
        wt = fx.get("tz")
        if wt:
            if tz != wt:
                failures.append(f"{fx['name']}: tz={tz!r} want {wt!r}")
        elif wt is None and "tz" in fx and fx["tz"] is None:
            if tz is not None:
                failures.append(f"{fx['name']}: tz={tz!r} want None")

    if failures:
        for f_ in failures:
            print(f"FAIL {f_}")
        sys.exit(1)
    print(f"golden_check: {len(fixtures)} fixtures passed")


if __name__ == "__main__":
    main()
