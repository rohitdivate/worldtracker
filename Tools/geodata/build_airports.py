#!/usr/bin/env python3
"""Build airports.bin (format WTA1) from OurAirports (public domain).

Layout (little-endian):
  magic 'WTA1'
  u32 count
  count * ( 3s iata, f32 lat, f32 lon, 2s isoCountry )   [13 B/record]
  records sorted by IATA (ASCII) for binary search.

Kept: rows with a 3-letter iata_code and type in {large,medium,small}_airport.
On IATA collision prefer larger type, then scheduled_service == "yes".
"""
import csv
import os
import struct

HERE = os.path.dirname(__file__)
RAW = os.path.join(HERE, "raw", "airports.csv")
OUT = os.path.join(
    HERE, "..", "..", "WorldTrackerKit", "Sources", "WorldTrackerKit", "GeoData",
    "airports.bin",
)

TYPE_RANK = {"large_airport": 3, "medium_airport": 2, "small_airport": 1}


def main():
    best = {}
    with open(RAW, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            iata = (row.get("iata_code") or "").strip().upper()
            if len(iata) != 3 or not iata.isalpha():
                continue
            rank = TYPE_RANK.get(row.get("type", ""))
            if rank is None:
                continue
            country = (row.get("iso_country") or "").strip().upper()
            if len(country) != 2:
                continue
            try:
                lat = float(row["latitude_deg"])
                lon = float(row["longitude_deg"])
            except (KeyError, ValueError):
                continue
            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                continue
            scheduled = 1 if row.get("scheduled_service") == "yes" else 0
            key = iata
            score = (rank, scheduled)
            if key not in best or score > best[key][0]:
                best[key] = (score, lat, lon, country)

    records = sorted((iata, v[1], v[2], v[3]) for iata, v in best.items())

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "wb") as f:
        f.write(b"WTA1")
        f.write(struct.pack("<I", len(records)))
        for iata, lat, lon, country in records:
            f.write(struct.pack("<3sff2s", iata.encode("ascii"), lat, lon, country.encode("ascii")))

    print(f"wrote {OUT}: {len(records)} airports, {os.path.getsize(OUT)/1024:.0f} KB")


if __name__ == "__main__":
    main()
