# On-device verification, milestone by milestone

Each milestone ends with things you can check on your own iPhone.
Tick them off before moving on.

## M0 — It builds

- [ ] `WorldTracker.xcodeproj` opens in Xcode with no red errors
- [ ] App installs and launches on your iPhone (README steps 4–5)
- [ ] You see the dark night-sky app with the animated aurora on **Home**
- [ ] Five tabs are present: Home, Calendar, Map, Places, Settings
- [ ] The app icon (night globe with amber arc) appears on your home screen

## M1 — Offline geocoder

- [ ] Turn ON airplane mode
- [ ] Settings tab → Developer → **Geo lookup tester**
- [ ] "Countries: 237" appears (the atlas loaded)
- [ ] London → GB 🇬🇧 Europe/London; Paris → FR; Barcelona → ES;
      Marrakech → MA; Tokyo → JP; Mid-Atlantic → 🌊 none
- [ ] Enter your own home coordinates under "Custom coordinate" — the right
      country, city and timezone come back with airplane mode still on

## M2 — Tracking

- [ ] Fresh install shows the Welcome flow; "Enable location" raises the iOS
      While-Using prompt — allow it
- [ ] Settings → Tracking health: "Location access" shows amber "While Using";
      tap "Upgrade to Always access" and choose **Change to Always Allow**
- [ ] All three requirement rows go green (Always ✓ / Precise ✓ / Background
      App Refresh ✓)
- [ ] Open the app somewhere — Settings → Developer → Ingest log shows a
      `foreground` sample with your city and flag
- [ ] Walk/drive a few km with the app closed; reopen later — new `slc`
      (significant location change) samples appear
- [ ] Leave the app alone overnight — next day a `visit` sample exists for
      home; "Last event" in Tracking health stays recent without you ever
      opening the app
- [ ] Toggle Smart tracking off and on — no crashes, log keeps working

## M3 — Day ledger + Calendar

- [ ] Home now shows "YOU'RE IN" with your flag and country once at least one
      location sample exists (open the app once outdoors if it's empty)
- [ ] "Day N of this stay · N days here this year" appears under the country
- [ ] Calendar tab: month grids appear, today has an amber ring, today's cell
      shows your flag
- [ ] Tap today's cell — the day sheet opens with your country and a GPS
      provenance stamp
- [ ] Future days are dimmed dots; days before you installed are empty circles
- [ ] Settings → Smart tracking off/on and reopening doesn't lose the calendar

## M4 — Photo Time Machine

- [ ] Settings → Photos → **Time Machine** (or the onboarding offer on a
      fresh install) → "Rebuild my history"
- [ ] iOS asks for photo access — choose **Allow Full Access** (Limited works
      but only sees selected photos)
- [ ] The progress ring runs; found flags stream in as your history is read;
      a 50k-photo library takes on the order of a minute
- [ ] Completion shows "Reconstructed N travel days from M photos"
- [ ] Calendar now shows YEARS of history — your real past trips with the
      right flags on the right dates (spot-check a trip you remember)
- [ ] Home's "days here this year" now reflects photo history too
- [ ] Change "Days with no photos" between the three modes — the calendar
      re-renders instantly (dashed cells appear/disappear); no re-scan needed
- [ ] Run "Re-sync from photos" again — the numbers stay consistent

## M5 — Stats & trips

- [ ] Home is now "Overview": period chips (This year / Last 365 / Last year /
      All time) re-scope the three stat tiles and the ranked "Your top" list
      with animated number transitions
- [ ] Tap a country in "Your top" — the country detail opens: big flag,
      "N TRIPS · N TOTAL DAYS", trips grouped by year, "NOW" on the current stay
- [ ] Calendar tab: the segmented control at the top switches to **Trips** —
      every stay as a row (newest first, "NOW" for the ongoing one); tapping
      opens the country detail
- [ ] Numbers sanity-check against your own memory of the year

## M6 — Editing

- [ ] Tap any past day in the calendar — the editor opens with the verdict,
      the evidence list (facts × source, photo places, location events), and
      a note field
- [ ] "Set country for this day" → picker (search, Popular, Recent) → the
      calendar updates instantly with an amber MANUAL border on that day
- [ ] Run Settings → Time Machine → Re-sync — the manual day SURVIVES
- [ ] "Revert to automatic" brings the old evidence-based verdict back
- [ ] "Mark as no data" empties the day and gap-fill doesn't cross it
- [ ] Calendar → Trips → "+" adds a manual trip over a date range; it appears
      in the calendar and the trip list
- [ ] Add a note to a day — the amber dot appears under the day cell

## M7 — Places

- [ ] After a photo Time Machine run, the Places tab fills with places built
      from photo clusters, grouped by country → city
- [ ] Re-open the app once or twice on Wi-Fi — pending places get real names
      ("naming…" disappears; museums/cafés get their POI names and emoji)
- [ ] Tap a place: mini-map, your photos taken there (local thumbnails),
      visit list with PHOTOS/VISIT provenance stamps
- [ ] Rename and delete work from the ⋯ menu
- [ ] Live test: spend 30+ min at a shop/café/park with the app installed —
      within a few hours a VISIT place appears (visit detection is batched
      by iOS; same-day is normal, instant is not)
- [ ] Category chips (Culture / Outdoors / Food…) filter the list

## M8 — Map

- [ ] Map tab opens on a realistic 3D globe centered on your home country
- [ ] Every visited country is shaded (home in amber, others in teal scaled
      by days spent); dashed flight arcs radiate from home to your countries
- [ ] Pinch/rotate the globe — it's fully interactive; zooming in transitions
      to satellite imagery
- [ ] The pill shows "N countries · N% of the world"
- [ ] Segmented → Countries: ranked list, tap-through to country detail

## M9 — iCloud, export, data management

- [ ] Settings → Profile: set your **Home base** (UK) — Home/top lists now
      show the HOME badge and travel days exclude home-only days
- [ ] "Days with no data" menu switches gap-fill policy from Settings too
- [ ] Export CSV / Export JSON → share sheet → AirDrop or Files; open the
      CSV — every day with countries and provenance is there
- [ ] Add the iCloud + Background Modes capabilities (README §7), flip
      Settings → iCloud backup ON, relaunch → delete the app → reinstall
      from Xcode → history comes back from your private iCloud
- [ ] "Erase auto-detected data" keeps manual days and notes
- [ ] "Delete all my data" leaves an empty app (then re-run the Time Machine)

## M10–M14 — Imports

- [ ] Settings → Import → Google Timeline: export from the Google Maps app
      (steps shown in-app), pick the JSON — progress runs, done card shows
      "Added N days across M countries"
- [ ] Calendar: imported days carry the violet TIMELINE stamp in the day
      editor; your GPS-tracked and manual days are untouched
- [ ] Re-import the same file — day counts stay stable (replace, not double)
- [ ] "Remove imported Timeline data" restores the pre-import calendar
- [ ] Settings → Import → Flights: import a Flighty CSV (or a 3-column CSV);
      an overnight long-haul credits the arrival day in the destination
- [ ] Unknown airport codes are listed on the done card rather than failing

## W1–W6 — Year in Travel (Wrapped) + celebrations

- [ ] Home shows "Your ⟨year⟩ in Travel" rows for every year with enough
      data (needs 10+ tracked days and either 2+ countries or 5+ travel
      days — the photo Time Machine or a Timeline import gets you there)
- [ ] Tap a year: the story opens full-screen — pages auto-advance with
      progress bars; tap right = next, tap left = back, long-press pauses,
      drag down dismisses
- [ ] Watch the choreography land: the year rolls in, flags pop, travel-day
      dots ignite across the calendar grid, podium bars rise (crown drops
      on #1 with a triple-tap haptic), the flight arc draws with the plane
      riding its tip, NEW STAMPS slam in one by one with a particle burst,
      the world map lights up country by country with comet arcs
- [ ] Photos page shows real thumbnails from your library (local-only) and
      each flips in
- [ ] Closer page: "Share your year" opens the share sheet with two PNGs —
      a 1080×1920 story card and a 1080×1080 square, both with the lit map
- [ ] Share icon in the top chrome works from any page (story pauses)
- [ ] Reduce Motion ON (Settings → Accessibility): every page renders its
      finished state immediately, no particles
- [ ] In January: an aurora "Your ⟨year⟩ is ready" card sits at the top of
      Home until opened once; a quiet notification arrives Jan 1 at 9:00
      (provisional — check Notification Center) and tapping it opens the
      story
- [ ] New-country celebration: Developer → Geo lookup won't fire it (live
      GPS only) — verify on a real border crossing or first run in a new
      country: full-screen stamp + "COUNTRY #N" + burst, exactly once;
      "See your world →" jumps to the Map tab
- [ ] Photo backfill and Timeline import never trigger celebrations

## W7 — Metal polish

- [ ] Calendar: tapping a day sends a soft water ripple through the month
      grid while the editor opens (Reduce Motion disables it)
- [ ] Wrapped closer: a shine band sweeps the summary card once, right
      after the rows finish cascading

## G1 — Widget foundation

- [ ] Project opens with TWO targets (WorldTracker + BeenThereWidgets) and
      builds with ▶ exactly as before
- [ ] Add the App Groups capability to both targets (README §8), run the
      app once
- [ ] Add the "You're In" small widget to your home screen — flag, country,
      Day N of stay, days-this-year line, Night Flight styling
- [ ] Change something in the app (e.g. set Home base) → within a minute
      the widget reflects the new data
- [ ] Without the App Group capability the widget shows the "open the app
      once" placeholder instead of breaking

## G2 — The widget family

- [ ] Widget gallery shows four Been There widgets: You're In (small),
      Countries (small), Your Top (medium), Your World (large)
- [ ] Your World paints the dot-map offline — land dim, your countries
      glowing teal by days spent, home amber; footer shows countries /
      travel days / % of the world
- [ ] Tap any widget → the app opens on the right tab (Your World → Map)
- [ ] Log a new day (or change gap-fill in Settings) → widgets re-color
      within a minute; they also roll over on their own at midnight

## G3 — Live Activity + Dynamic Island

- [ ] Simulate being abroad: set Home base to a country you're NOT in →
      within a minute a Live Activity appears on the lock screen (aurora
      flag ring, Day N, days-this-year, trip dots)
- [ ] On a Dynamic Island iPhone: compact shows flag + D-counter; press
      and hold expands to the full card; minimal shows the flag
- [ ] Tap the activity → the app opens
- [ ] Set Home base back to your actual country → the banner retires
- [ ] Lock screen widgets (iOS Customize → widgets area): circular flag +
      day, rectangular country + stay + year line
- [ ] After iOS's 8-hour activity limit, the banner returns on the next
      location wake or app open (restart-on-wake)

## V1–V3 — Home history + honest trips + trip detail

- [ ] Settings → Home base → set "Originally from" = United States, add a
      move to the United Kingdom on your actual moving date
- [ ] Home stat tiles recompute: days living in the US no longer count as
      travel days; a US visit AFTER the move still does
- [ ] Calendar → Trips: home stays are gone; the "Show home stays" chip
      brings them back with per-period HOME badges
- [ ] Wrapped for a pre-move year: the US is treated as that year's home
      (arc origin, "days away" dots)
- [ ] Tap a trip → detail screen: flag, dates, day count, cities line, and
      the photos taken on that trip
- [ ] Edit trip: change the country or dates → the calendar and list update;
      shrinking a trip leaves no orphaned days
- [ ] Delete trip: days become "no data"; a border day shared with a
      neighboring trip keeps the other country; any day is restorable via
      its day editor ("Revert to automatic")

## V4 — Photo lightbox

- [ ] Places → a place → tap a photo: it expands full-screen; swipe left/
      right pages through, pinch and double-tap zoom, drag down dismisses
- [ ] iCloud-optimized originals stream in (corner spinner) over the
      instant thumbnail
- [ ] Trip detail photos open the same viewer with city · date captions

## V5 — Cinematic globe

- [ ] Map tab: the globe flies in from space to your home (Reduce Motion
      skips straight there)
- [ ] Visited countries are unmissable — hot aurora fill + glowing
      borders, home amber with a pulsing beacon
- [ ] Flight arcs are layered (soft glow under a bright core), no dashes
- [ ] Tap a visited country → the camera flies over it and a stat card
      slides up (days overall/this year, trips, Open → country screen);
      tap the ocean or an unvisited country to fly back out
- [ ] Stats pill shows countries · % world and travel days · crossings

## X — Widget sync, Live Activity restore, new widgets (v3.1)

- [ ] Settings → Data → Widgets row: shows "App Group missing…" in amber
      until the capability is on both targets; after that, "Synced HH:MM"
      after tapping Refresh (or opening the app)
- [ ] Widgets show a precise empty state: "Finish widget setup (README §8)"
      without the App Group vs "Open Been There once" without data
- [ ] Trip banner: Settings → Tracking → toggle off ends the Live Activity
      immediately; on restarts it if you're abroad. Swipe the banner away →
      it returns on the next location update or app open (dismissed-state fix)
- [ ] On This Day (small/medium): your photo from this date years ago with
      "City, Country"; medium shows other anniversaries as flag chips;
      taps into Calendar
- [ ] Travel Graph (medium): the year's dot grid — travel days lit, the
      future faint; taps into Calendar
- [ ] Momentum (small): days since your last NEW country (amber past 180)
      + "N more to X% of the world"; taps into Map
