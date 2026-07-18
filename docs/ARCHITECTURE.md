# Architecture

One iOS app target (`WorldTracker/`, SwiftUI, iOS 18+) plus one local Swift
package (`WorldTrackerKit/`) holding every piece of pure logic — offline
geocoding, day attribution, photo clustering — so it can be unit-tested on
Linux without Xcode.

## The core idea: store facts, compute verdicts

The database never stores "you were in France on March 3" as a final truth.
It stores **facts**: `CountryDayFact(epochDay, countryCode, source, confidence)`
where source is `gps | visit | photo | manual | timezoneHint`.

A pure resolver (`DayLedgerResolver`, in the Kit) turns facts into per-day
verdicts at query time with the precedence **manual > gps/visit >
importedTimeline/importedFlight > photo > timezoneHint**, plus a
configurable gap-fill policy (assume-stayed /
fill-short-gaps / leave-empty). Because verdicts are computed, changing a
setting instantly re-renders all history, and photo re-scans can never
clobber manual edits.

**Day boundaries use the timezone of the place the sample belongs to**, never
the device timezone (`EpochDay(date:timeZone:)`). This is what stops evening
Tokyo photos from landing on "yesterday".

## Location engine (M2)

- `startMonitoringSignificantLocationChanges()` — the backbone; near-zero
  battery, wakes/relaunches the app on cell-tower-scale movement
- `startMonitoringVisits()` — arrive/depart events that also feed Places
- One-shot `requestLocation()` on every foregrounding — the "landed and
  opened the app at baggage claim" detector
- Device-timezone change on wake — a border-crossing hint fact
- **Never** continuous GPS; no location background mode; the app is invisible
  to the battery screen

## Photo backfill (M4)

PhotoKit metadata-only enumeration (asset location + creationDate — nothing
downloads from iCloud), batched off the main thread with a resumable
checkpoint. Coordinates geocode through the **offline atlas** (bundled
Natural Earth polygons + GeoNames cities with timezones, ~5MB total) — no
network, no rate limits, works for 50k photos in about a minute.

## Places (M7)

`CLVisit` departures match-or-create `Place` records; naming is lazy and
low-volume via `MKLocalPointsOfInterestRequest` + `CLGeocoder` (serialized,
capped, retried). Photo clusters (≥3 photos within ~300m/90min) create
places from your past.

## Storage

SwiftData, CloudKit-compatible models from day one (all defaults, optional
relationships, no unique constraints) so M9 can flip on private-iCloud backup
with `ModelConfiguration(cloudKitDatabase: .automatic)`. Local-only config
holds the device-specific `LocationSample` audit trail and scan checkpoints.

## Design system

"Night Flight": deep indigo grounds, aurora teal→violet, amber for now/home.
`DesignSystem/` holds tokens (`Theme`), the animated `MeshGradient` aurora,
Metal shaders (from M3), and shared components (flag chips, split flags,
provenance stamps). Signature moments per screen are specified in the design
mockups (see the project artifacts).

## Bulk imports (M10–M14)

Google Timeline (all three export shapes — the post-2024 on-device export,
Takeout Records.json streamed in constant memory, and Semantic monthly
files) and flight CSVs (Flighty or `date,origin,destination`) become
`importedTimeline` / `importedFlight` facts. Each import REPLACES only its
own origin's rows and can be undone the same way; a bundled ~9k-airport
IATA database resolves flights, with arrival days bucketed in the arrival
airport's timezone.
