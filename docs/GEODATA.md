# Geodata sources and attribution

The offline atlas in `WorldTrackerKit/Sources/WorldTrackerKit/GeoData/` is
built by the scripts in `Tools/geodata/` from three sources.

| Source | Used for | Licence |
| --- | --- | --- |
| GeoNames (geonames.org), `cities1000`, `admin1CodesASCII`, `timeZones` | City and region names, time zone to country hints | Creative Commons Attribution 4.0 (CC BY 4.0). Attribution required |
| Natural Earth (naturalearthdata.com), admin 0 countries at 1:50m and 1:110m | Country borders | Public domain |
| OurAirports (ourairports.com), `airports.csv` | Airport locations for flight imports | Public domain |

The bundled files are adapted and reduced copies of the originals.

Where the attribution appears:

- In the app: Settings, Privacy & About, Acknowledgements
  (`WorldTracker/Features/Settings/AcknowledgementsView.swift`).
- In the public policy: `docs/PRIVACY_POLICY.md`, "Map data credits".
