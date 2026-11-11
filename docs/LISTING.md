# App Store listing: the exact fields to paste

Decided values for the first submission (version 2.0). `docs/APP_STORE.md` is the step-by-step
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

## Keywords (100 char limit, 97 used)

```
schengen,visa,tax,183,residency,expat,nomad,limit,passport,trip,journal,globe,border,stay,visited
```

No word here repeats one in the name or subtitle. Apple indexes name, subtitle,
keywords, developer name and IAP names, then combines words across those fields
into phrases, so a repeat is a wasted character. The description is not indexed
at all.

`schengen`, `visa`, `tax`, `183` and `limit` went in with 2.0, which ships day
limits (Schengen 90/180, 183-day and tax-year rules, custom limits, forecasts
over planned trips). They were held back before that so the listing never
promised a feature the app lacked (guideline 2.3.7). The app states on the Day
Limits screen that counts are a planning guide and not legal or tax advice;
keep the description saying the same.

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

Six panels at **1320 x 2868** (the 6.9-inch requirement), captured on an
iPhone 17 Pro Max simulator on the Paper skin, against the synthetic photo
library from `Tools/make_screenshot_library.py` plus three day-limit rules and
two planned trips.

**Upload `docs/screenshots/framed/`.** Those are the composed panels: a mono
label and a poster caption over the device shot, on the Paper ground.
`docs/screenshots/` holds the raw captures they're built from, kept because
the compositor re-reads them.

| # | File | Caption | Shows |
| --- | --- | --- | --- |
| 1 | `01-overview.png` | Every day abroad, counted | Home: the globe, the day number, today's country |
| 2 | `02-limit.png` | Know your days left | Schengen 90/180 detail: gauge, forecast, window |
| 3 | `03-forecast.png` | See trouble before you book | Day Limits list with planned trips and warnings |
| 4 | `04-calendar.png` | A year of flags | Months of days, each wearing its flag |
| 5 | `05-passport.png` | Stamps for every country | Countries count, continent rings, stamps |
| 6 | `06-countries.png` | Every country, ranked by days | World, Countries face |

Shots 1 to 3 are the ones search results show inline, so they carry the
listing name's promise: days counted, days left, days planned.

Why captioned panels: most install decisions happen in search results without
opening the listing page. At that size 11pt UI text is illegible but a
four-word headline reads. Guideline 2.3.3 wants screenshots to show the app in
use, which real UI inside a frame satisfies; pure marketing art would not.

Rebuild the panels after any recapture or caption change:

```bash
python3 Tools/make_screenshot_panels.py docs/screenshots docs/screenshots/framed
```

Labels and captions live in `SHOTS` at the top of that script. Text in images
means redoing them per language, so they stay English-only until localisation
is on the table.

**Recapturing.** A DEBUG build lands on any screen from the command line, so no
tapping is needed. Pin the status bar to 9:41 first (Apple's own marketing
convention, and it stops the clock drifting between shots):

```bash
xcrun simctl status_bar <UDID> override --time "9:41" \
  --wifiBars 3 --cellularMode active --cellularBars 4 \
  --batteryState charged --batteryLevel 100
xcrun simctl launch <UDID> com.rohitdivate.beenthere \
  -themeID paper -debugOpen beenthere://limits
xcrun simctl io <UDID> screenshot docs/screenshots/03-forecast.png
```

The hosts are `home`, `limits`, `limits/<rule id>`, `calendar`, `passport` and
`countries`. The first launch after an install drops its arguments, so launch
once and throw that one away.

**Building the data.** `Tools/make_screenshot_library.py` writes gradient
JPEGs carrying GPS EXIF and mid-day `DateTimeOriginal` timestamps. Load them
with `xcrun simctl addmedia`, then scan through Settings, Time Machine,
Re-sync from photos. Mid-day timestamps are deliberate: day boundaries use the
timezone of the place, so an evening photo can land on the previous day.

```bash
python3 Tools/make_screenshot_library.py /tmp/shots
find /tmp/shots -name '*.jpg' -print0 | xargs -0 -n 40 xcrun simctl addmedia <UDID>
```

Avoid any screen that renders photo thumbnails (the Wrapped "Moments you kept"
page, trip detail). The synthetic images are flat gradients and read as fake.

**Still to add:** the iPhone Duo sizes (1398 x 2034 outer, 2007 x 2853 inner),
once Xcode 27.1 is installed.

## App Review notes

```
No account or login is required. Location is used passively
(significant-location-changes only, never continuous GPS) to log the country
per day, entirely on device. Photo access is optional and reads metadata only.
No data leaves the device.
```
