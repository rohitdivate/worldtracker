#!/usr/bin/env bash
# Downloads raw geodata sources into Tools/geodata/raw/ (gitignored).
# Licenses: Natural Earth = public domain; GeoNames = CC-BY 4.0 (attribution in docs/GEODATA.md).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p raw
cd raw

curl -sL -o ne_50m.geojson \
  "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson"
curl -sL -o ne_110m.geojson \
  "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
curl -sL -o cities1000.zip "https://download.geonames.org/export/dump/cities1000.zip"
curl -sL -o admin1.txt "https://download.geonames.org/export/dump/admin1CodesASCII.txt"
curl -sL -o timeZones.txt "https://download.geonames.org/export/dump/timeZones.txt"
curl -sL -o airports.csv "https://davidmegginson.github.io/ourairports-data/airports.csv"
ls -la
