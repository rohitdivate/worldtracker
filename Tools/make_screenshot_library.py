#!/usr/bin/env python3
"""Build a synthetic geotagged photo library for App Store screenshots.

    python3 Tools/make_screenshot_library.py /tmp/shots
    find /tmp/shots -name '*.jpg' -print0 | xargs -0 -n 40 xcrun simctl addmedia <UDID>

    # Top up a simulator that already has an older library: only photos
    # dated on or after the given day are written.
    python3 Tools/make_screenshot_library.py /tmp/shots --since 2026-08-23

Then in the app: Settings > Time Machine > Re-sync from photos.

Timestamps are deliberately mid-day. Day boundaries use the timezone of the
place, so an evening photo can resolve to the previous day. Needs Pillow.
"""

from PIL import Image, ImageDraw
from datetime import date, timedelta
import colorsys, sys, os

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else "screenshot-photos"
SINCE = date.min
if "--since" in sys.argv:
    SINCE = date.fromisoformat(sys.argv[sys.argv.index("--since") + 1])
    ARGS = [a for a in ARGS if a != SINCE.isoformat()]
    OUT = ARGS[0] if ARGS else "screenshot-photos"
os.makedirs(OUT, exist_ok=True)

CITY = {
 "London":(51.5074,-0.1278), "Paris":(48.8566,2.3522), "Lisbon":(38.7223,-9.1393),
 "Barcelona":(41.3851,2.1734), "Madrid":(40.4168,-3.7038), "Berlin":(52.5200,13.4050),
 "Munich":(48.1351,11.5820), "Rome":(41.9028,12.4964), "Florence":(43.7696,11.2558),
 "Venice":(45.4408,12.3155), "Amsterdam":(52.3676,4.9041), "Tokyo":(35.6762,139.6503),
 "Kyoto":(35.0116,135.7681), "Dublin":(53.3498,-6.2603), "Mumbai":(19.0760,72.8777),
 "Goa":(15.4909,73.8278), "Zurich":(47.3769,8.5417), "Zermatt":(46.0207,7.7491),
 "NewYork":(40.7128,-74.0060), "Athens":(37.9838,23.7275), "Santorini":(36.4167,25.4333),
 "Oslo":(59.9139,10.7522), "Bergen":(60.3913,5.3221), "Split":(43.5081,16.4402),
 "Dubrovnik":(42.6507,18.0944), "SanFrancisco":(37.7749,-122.4194),
 "Fremont":(37.5485,-121.9886), "Copenhagen":(55.6761,12.5683), "Stockholm":(59.3293,18.0686),
}

# (start, end, [(city, from_day_offset)]) — inclusive dates, 2 photos/day
TRIPS = [
 ("2025-01-10","2025-01-14",["Paris"]),
 ("2025-02-20","2025-02-27",["SanFrancisco","Fremont"]),
 ("2025-03-15","2025-03-22",["Lisbon"]),
 ("2025-05-02","2025-05-09",["Barcelona","Madrid"]),
 ("2025-06-12","2025-06-19",["Berlin","Munich"]),
 ("2025-07-20","2025-08-03",["Rome","Florence","Venice"]),
 ("2025-09-05","2025-09-12",["Amsterdam"]),
 ("2025-10-10","2025-10-20",["Tokyo","Kyoto"]),
 ("2025-11-14","2025-11-18",["Dublin"]),
 ("2025-12-20","2025-12-31",["Mumbai","Goa"]),
 ("2026-01-15","2026-01-22",["Zurich","Zermatt"]),
 ("2026-02-10","2026-02-17",["NewYork"]),
 ("2026-03-12","2026-03-19",["Paris"]),
 ("2026-04-08","2026-04-15",["Athens","Santorini"]),
 ("2026-05-20","2026-05-27",["Oslo","Bergen"]),
 ("2026-06-10","2026-06-17",["Split","Dubrovnik"]),
 ("2026-07-15","2026-07-25",["SanFrancisco","Fremont"]),
 ("2026-08-05","2026-08-12",["Copenhagen","Stockholm"]),
 ("2026-09-11","2026-09-20",["Lisbon"]),
 ("2026-10-16","2026-10-27",["Rome","Florence"]),
]

def dms(v):
    v = abs(v); d = int(v); m = int((v-d)*60); s = round((v-d-m/60)*3600, 2)
    return (float(d), float(m), float(s))

def make(path, lat, lon, when, hue):
    w, h = 1400, 1050
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        r, g, b = colorsys.hsv_to_rgb((hue + t*0.08) % 1.0, 0.45 - t*0.2, 0.35 + t*0.5)
        d.line([(0, y), (w, y)], fill=(int(r*255), int(g*255), int(b*255)))
    e = Image.Exif()
    e[0x010F] = "Apple"; e[0x0110] = "iPhone 16 Pro"
    e.get_ifd(0x8769)[0x9003] = when
    g_ = e.get_ifd(0x8825)
    g_[1] = "N" if lat >= 0 else "S"; g_[2] = dms(lat)
    g_[3] = "E" if lon >= 0 else "W"; g_[4] = dms(lon)
    img.save(path, exif=e, quality=86)

def days(a, b):
    a = date.fromisoformat(a); b = date.fromisoformat(b)
    while a <= b:
        yield a; a += timedelta(days=1)

n = 0
hue_i = 0
covered = set()
for start, end, cities in TRIPS:
    hue_i += 1
    dl = list(days(start, end))
    for i, day in enumerate(dl):
        city = cities[min(i * len(cities) // len(dl), len(cities)-1)]
        lat, lon = CITY[city]
        covered.add(day)
        if day < SINCE:
            continue
        for k, hour in enumerate((11, 15)):
            make(f"{OUT}/{day.isoformat()}_{city}_{k}.jpg", lat, lon,
                 day.strftime(f"%Y:%m:%d {hour:02d}:2{k}:00"), (hue_i*0.13) % 1.0)
            n += 1

# London life between trips: one photo every 3rd non-travel day
# Runs to yesterday, so the library always reaches the present and the Home
# heatmap has no dead months at the end.
cur = date(2025, 1, 1); last = date.today() - timedelta(days=1); i = 0
lat, lon = CITY["London"]
while cur <= last:
    if cur not in covered and i % 3 == 0 and cur >= SINCE:
        make(f"{OUT}/{cur.isoformat()}_London.jpg", lat, lon,
             cur.strftime("%Y:%m:%d 13:05:00"), 0.58)
        n += 1
    cur += timedelta(days=1); i += 1

print("generated", n, "photos")
