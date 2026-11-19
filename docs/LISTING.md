# App Store listing: the exact fields to paste

Values for the first submission (version 1.0, build 1). `docs/APP_STORE.md` is the step-by-step
walkthrough; this page is the single source for the listing copy, so there's one place to change it.

The App Store name is still an open owner decision (see the submission pack).
The table below holds the value planned so far.

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

`schengen`, `visa`, `tax`, `183` and `limit` are in because 1.0 ships day
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

Public gist of `docs/PRIVACY_POLICY.md`. The gist still holds the old July 2026
text. Republish it from the current `docs/PRIVACY_POLICY.md` (after filling in
the `[Developer name]`, `[contact email]` and date placeholders) before
submitting, and update both together from then on.

## Promotional text (170 char limit)

```
Count your days in every country automatically. Rebuild past trips from your photos, watch Schengen 90/180 and 183-day limits, and keep your history on your iPhone.
```

## Description

```
Been There counts your days in every country, automatically.
It rebuilds years of past travel from the dates and locations in your photo library.
No account, no ads, no analytics. Your travel history is stored on your iPhone.

AUTOMATIC
• Logs the country and city you are in each day, using low-power location updates
• Never runs continuous GPS
• Borders and cities are matched with an atlas inside the app, so it works offline

REBUILD THE PAST
• Scan your photo library's dates and locations to fill in past trips
• Import a Google Timeline export
• Import flights from a Flighty export or a simple CSV file
• Edit any day or trip by hand. Your edits always win

KNOW YOUR DAYS
• Day limits for Schengen 90/180, 183 days in a country, days outside a country, or your own rule
• Days used, days left, and the date days free up
• Add planned trips and see a forecast before you book
• Export a CSV report for any limit
• Review days with no data, so a count is never silently low
Counts are a planning guide, not legal or tax advice.

SEE YOUR WORLD
• A calendar where each day shows its flag
• A globe that lights up the countries you have visited
• Countries ranked by days, and the places you actually went
• Passport stamps, continent rings and badges
• Your Year in Travel, with share cards you can send to anyone

ON YOUR HOME SCREEN
• Ten widgets, including You're In, Day Limit, Travel Graph and Passport
• Lock Screen widgets and a Live Activity while you are abroad
• Siri and Shortcuts: "Where am I", "Check my day limits"

PRIVATE
• No sign-up. No third-party services. The developer receives no data
• Export everything as CSV or JSON, or make a full backup file
• Delete your data at any time in Settings
Place names and maps come from Apple Maps.
City data from GeoNames (CC BY 4.0).
```

## What's New (version 1.0)

```
First release. Been There logs the country you are in each day, rebuilds past trips from your photos, counts your days against limits like Schengen 90/180, and shows it all as a calendar of flags, a globe and a passport of stamps.
```

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
No account or login is needed. The app is fully usable straight after install.

How to test without travelling:
1. Launch, tap Get started. Location is optional: "Maybe later" works.
2. Pick a home country, then either allow the photo scan or tap Skip.
3. To add data by hand: open the Calendar tab, tap any day and set a country, or add a trip.
4. To see day counting: Home > Day Limits > add "Schengen 90/180", then add a planned trip.
5. Widgets: add any "Been There" widget after opening the app once.

Permissions:
- Location (When In Use, later Always): used to log the country and city per day. The app uses significant-location-change and visit monitoring only. It never runs continuous GPS and declares no location background mode. Always access lets iOS wake the app when the user changes city or country.
- Photos (optional): the app reads photo dates and locations to rebuild past trips, and shows the user's own photos inside trips and the On This Day widget. Photos are never uploaded.
- Notifications (optional, local only): trip recaps and day limit reminders.

Data: there is no developer server and no analytics. The travel log is stored on the device. Place names and maps use Apple MapKit and Apple's geocoder.

Day limit counts are a planning guide. The app states on the Day Limits screen that they are not legal or tax advice.
```
