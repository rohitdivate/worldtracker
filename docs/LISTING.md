# App Store listing: the exact fields to paste

Decided values for the 1.0 submission. `docs/APP_STORE.md` is the step-by-step
walkthrough; this page is just the copy, so there's one place to change it.

## Identity

| Field | Value | Limit |
| --- | --- | --- |
| App name | `Days Abroad: Country Tracker` | 28 / 30 |
| Subtitle | `Been There: travel log & map` | 28 / 30 |
| Bundle ID | `com.rohitdivate.beenthere` | n/a |
| SKU | `beenthere-001` | n/a |
| Home-screen name | **Been There** (`CFBundleDisplayName`, unchanged) | n/a |

The listing name and the home-screen name are deliberately different. The
listing name is bought for search; the icon on the phone keeps the brand.

## Keywords (100 char limit, 96 used)

```
residency,expat,nomad,passport,trip,journal,globe,flag,border,stay,history,timeline,visited,city
```

No word here repeats one in the name or subtitle. Apple indexes name, subtitle,
keywords, developer name and IAP names, then combines words across those fields
into phrases, so a repeat is a wasted character. The description is not indexed
at all.

Deliberately **excluded**: `183`, `schengen`, `visa`, `tax`. The app records
days per country but computes no residency threshold, so those terms would draw
users expecting a feature that isn't there (and risk a 2.3.7 metadata
rejection). Add them the day a threshold feature ships.

## Positioning

Two clusters exist on the store and this app sits between them:

- **Countries-visited / travel map**: Visited (~13k ratings), Been, Skratch,
  Polarsteps. Unwinnable for a new app, and they're all manual pin-dropping.
- **Residency day counting**: TaxBird plus a wave of 2025-26 entrants. Weaker
  incumbents, higher intent, but they all make you log trips by hand.

The wedge is that this one is automatic and reconstructs the past from photo
metadata. Every competitor in both clusters requires manual entry.

## Privacy policy URL

<https://gist.github.com/rohitdivate/ad1396b06ae5b4e45e098526b233b737>

Public gist of `docs/PRIVACY_POLICY.md`. Update both together, or the listing
drifts from the repo.

## Category, rating, price

- Category: **Travel** (secondary: Lifestyle)
- Age rating: **4+**
- Price: **Free**, all territories
- App Privacy: answer **No** to data collection, so the listing shows
  **"Data Not Collected"**

## Screenshots

> The committed screenshots predate the 2.0 redesign (they show Night Flight
> and the old Home). Recapture all five on the Paper skin before submitting,
> and add the iPhone Duo sizes (1398 × 2034 outer, 2007 × 2853 inner) once
> Xcode 27.1 is available.


Two sets, five shots each, both at **1320 × 2868** (the 6.9-inch requirement),
captured on an iPhone 17 Pro Max simulator against a 464-photo synthetic
library that resolves to 305 travel days across 18 countries.

**Upload `docs/screenshots/framed/`.** Those are the composed panels: a caption
over the device shot on the app's own indigo ground. `docs/screenshots/` holds
the raw captures they're built from, kept because the compositor re-reads them.

| # | File | Caption | Shows |
| --- | --- | --- | --- |
| 1 | `01-overview.png` | Every day, logged automatically | Today's country, stat tiles, leaderboard |
| 2 | `02-calendar.png` | A year of flags | A month of days, each wearing its flag |
| 3 | `03-globe.png` | Your world, lit up | Lit countries, flight arcs, day chips |
| 4 | `04-trips.png` | Trips it built for you | Derived trips with dates and durations |
| 5 | `05-wrapped-days-away.png` | Days away from home | Year in Travel dot grid |

Shot 5 is the one that matches the listing name, so it's a good candidate to
promote if the order is ever reshuffled.

Why captioned rather than bare captures: search results show roughly three
screenshots inline, and most install decisions happen there without opening the
listing page. At that size 11pt UI text is illegible but a five-word headline
isn't. Guideline 2.3.3 wants screenshots to show the app in use, which real UI
inside a frame satisfies; pure marketing art would not.

Rebuild the panels after any recapture or caption change:

```bash
python3 Tools/make_screenshot_panels.py docs/screenshots docs/screenshots/framed
```

Captions live in `SHOTS` at the top of that script. Text in images means
redoing them per language, so they stay English-only until localisation is
actually on the table.

**Status bar is pinned to 9:41**, Apple's own marketing convention, which also
stops the clock drifting between shots taken minutes apart:

```bash
xcrun simctl status_bar <UDID> override --time "9:41" \
  --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
```

A sixth shot of the Countries leaderboard was cut: country names and trailing
metadata truncate there (see **Known cosmetic issue**), and visible clipping on
a listing reads as an unfinished app. Reinstate it once that's fixed. The Home
shot already carries a country leaderboard, so nothing is lost.

**Regenerating them:** `Tools/make_screenshot_library.py` writes 457 gradient
JPEGs carrying GPS EXIF and mid-day `DateTimeOriginal` timestamps. Load them
with `xcrun simctl addmedia`, then scan through Settings › Time Machine ›
Re-sync from photos. Mid-day timestamps are deliberate: day boundaries use the
timezone of the place, so an evening photo can land on the previous day.

```bash
python3 Tools/make_screenshot_library.py /tmp/shots
find /tmp/shots -name '*.jpg' -print0 | xargs -0 -n 40 xcrun simctl addmedia <UDID>
```

Avoid any screen that renders photo thumbnails (the Wrapped "Moments you kept"
page, trip detail). The synthetic images are flat gradients and read as fake.

## App Review notes

```
No account or login is required. Location is used passively
(significant-location-changes only, never continuous GPS) to log the country
per day, entirely on device. Photo access is optional and reads metadata only.
No data leaves the device.
```

## Known cosmetic issue

On the Countries list, long country names and trailing metadata truncate
("United Ki… · 19 trips · last AUG…") even on the largest iPhone. Visible in
`04-countries.png`. Not a blocker, worth a fix before a 1.1.
