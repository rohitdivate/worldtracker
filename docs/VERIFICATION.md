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

## X2 — On-device feedback round 2 (v3.2)

- [ ] Places: summary strip (places/cities/countries), search bar finds by
      name/city/country, sort menu (most visited / recent / A-Z), countries
      collapse under tappable headers with counts (searching auto-expands);
      expansion state survives relaunch
- [ ] Calendar: newest month at the top — double-tapping the Calendar tab
      jumps to TODAY, never to an EXIF-glitch month decades back
- [ ] Trip detail + Wrapped photos: photos crop into their squares — never
      stretched
- [ ] Country picker: "Yours" chip row (home + most-visited) sits on top
      for one-tap picking

## X3 — Constellation map (replaces the globe)

- [ ] Map tab: dot-matrix world in Night Flight tones — no satellite
      imagery; visited countries glow teal by days, home amber with halo
- [ ] Day-count ledger under the map: flag, aurora bar, big day number,
      "N trips · last ⟨date⟩" (home shows "Living here since ⟨move date⟩")
- [ ] Tap a card → country detail; summary line shows countries · % world
      · travel days · crossings
- [ ] Your World widget renders the identical dot world (shared painter)

## X4 — The globe returns, upgraded

- [ ] Map tab → Globe: DARK VECTOR earth (no satellite, no green overlay);
      visited countries in aurora with glowing borders, home amber
- [ ] Day-count chips sit ON the globe for your top 8 countries; tapping a
      chip (or the country itself) flies over and opens the stat card
- [ ] Fly-in from space on open; pulsing home beacon; layered arcs
- [ ] Countries mode = the day-count ledger (bars, trips, since-dates)

## Y1 — Truthful tracking & home (v4)

- [ ] Fresh install: onboarding asks "Where do you live?" with device-region
      and timezone-country chips + full picker; picking one makes a home-only
      day count 0 travel days on Home
- [ ] Permission step copy is honest ("logs while you use it — we'll offer
      background later"); no Always request during onboarding
- [ ] Next day (or after the first tracked sample), reopening the app offers
      the Always upgrade sheet — at most twice ever, ≥7 days apart, never on
      install day, never over a celebration/backfill/import
- [ ] "Tracking limited" pill under the Today card whenever auth is
      While-Using or tracking is off; tapping routes to the upgrade sheet or
      iOS Settings once the one-shot system prompt is spent
- [ ] Settings → Tracking health upgrade button uses the same spent-prompt
      routing

## Y2 — Crash-safe backfill + payoff (v4)

- [ ] Kill the app mid-scan → relaunch: no history lost, checkpoint shows
      "Scan interrupted … nothing was lost" with Resume; foregrounding
      auto-resumes and the flag stream re-seeds
- [ ] Old photo-derived days remain visible in Calendar/Map during a re-scan
      (generation swap — the wipe happens only at the end)
- [ ] Backgrounding mid-scan: scan continues briefly (background grace), then
      pauses cleanly; returning resumes without re-processing photos
- [ ] Done card: "N travel days · M countries" + flag cascade, in both
      Settings → Time Machine and onboarding
- [ ] Zero-geotag library: distinct copy + "Try Google Timeline import" CTA
      (Settings) / Settings-pointer copy (onboarding)
- [ ] Photo permission denied → "Open iOS Settings" button in both surfaces
- [ ] Scan finishing while app is backgrounded posts a local notification
      ("backfill-done", deep-links to Map); store migrates V2→V3 in place
      with all existing data intact (manual device check)

## Y3 — Guided value: router, checklist, teaching empty states (v4)

- [ ] Home shows a "Finish setting up" card until location (Always or
      While-Using), home country, and photo history are settled and Timeline
      is imported or skipped; each row deep-links to its fix; X dismisses
      forever; the Y1 tracking pill and waiting card stay hidden while the
      checklist is up
- [ ] beenthere://settings/timeline|flights|photos|health deep-links land on
      the right Settings screen (test from Notes with the URL)
- [ ] Empty calendar shows "Your calendar is waiting" with working Rebuild
      from photos / Import Google Timeline buttons; empty Map (globe +
      countries) and empty Trips show the same CTAs; Trips adds "Add a trip
      manually"
- [ ] Release builds hide the Developer section but keep the version footer
      (check on device with a Release scheme if curious — Debug shows both)

## Y4 — Share everywhere (v4)

- [ ] COUNTRY #N celebration: "Share this moment" appears with the buttons
      and produces the stamp card (flag, COUNTRY #N, date, BEEN THERE · FOR
      iPHONE wordmark)
- [ ] Calendar: share icon on each month with data → preview sheet → month
      grid card with flags + travel-day count
- [ ] Map toolbar share → dot-map world card with countries · % of world ·
      travel days (disabled while empty)
- [ ] Trip detail toolbar share → postcard with flag, dates, cities, up to
      3 photos
- [ ] Wrapped story + square cards now carry the FOR iPHONE hook line
- [ ] Widgets: Your World + On This Day carry a small BEEN THERE mark; the
      Live Activity lock-screen card shows it under the day count

## Y5 — Milestones & retention (v4)

- [ ] Crossing a lifetime threshold live (5/10/15… countries, 50/100/250…
      travel days, 10/25/50% of the world, longest-trip-beaten) triggers the
      milestone celebration: big-number slam, flag cascade, working share
      button with a branded card
- [ ] First-ever evaluation after a big import/backfill fires NOTHING (seed
      rule); a later single crossing fires exactly once and never repeats
- [ ] A bulk crossing (e.g. import adds 8 countries at once) celebrates only
      the highest milestone
- [ ] Coming home after a ≥2-day trip → "Welcome home" recap ~2h later,
      deep-links to Calendar; fires once per trip
- [ ] Early-month foreground schedules last month's recap at 10:00 (skipped
      for no-travel months); December foreground schedules the Dec-26
      Wrapped teaser when the year has enough data
- [ ] Settings → Notifications: four toggles (trip recap, monthly recap,
      Year in Travel, scan finished), all defaulting on; switching one on
      asks for full notification permission

## X5 — Zoom-aware globe: city chips (v4.1)

- [ ] Pinch in past ~3,000 km: country day chips swap to visited-CITY chips
      (name + days); pinch out past 4,000 km: swap back; jiggling the pinch
      around the boundary doesn't flicker (hysteresis band)
- [ ] Tapping a small country (short flyover) auto-enters city mode; a large
      country (e.g. US) stays on country chips until you pinch in
- [ ] City chip tap flies down to that city with a haptic; background tap at
      city zoom clears the country card WITHOUT moving the camera
- [ ] Panning at city zoom refreshes the visible set on gesture end — max 12
      chips, ranked by days; the same city from photos and live visits shows
      as one merged chip ("Zürich"/"Zurich" merge, no double counting)
- [ ] Fresh install: no chips, no crash; after a photo scan finishes, city
      chips appear within ~1s

## X6 — Launch animation + checklist dismiss fix (v4.2)

- [ ] Cold-open the app (kill it first): night sky, the dot world ignites
      west→east with your countries in aurora and home flaring amber, the
      BEEN THERE wordmark stamps in with a tick, then the app fades up —
      about 1.6s total
- [ ] Tap anywhere during the animation: it skips straight into the app
- [ ] Backgrounding and reopening does NOT replay it (cold launch only);
      Reduce Motion shows one static frame briefly instead of the sweep
- [ ] "Finish setting up" card: tapping ✕ dismisses it IMMEDIATELY (no
      relaunch needed); the Timeline row's Skip also updates in place

## X7 — Selectable themes (v4.4)

Three themes, colour + typography only. No behaviour changes anywhere, so
anything that *acts* differently after a switch is a bug.

- [ ] Settings → Appearance lists three rows — Night Flight, Tropical Spritz,
      Mercury Dark — each with a swatch showing that theme's own ground and
      two accents, and a checkmark on the active one
- [ ] **Night Flight is unchanged.** Fresh install lands on it and every
      screen looks exactly as it did before themes existed — this is the
      regression that matters most, since it's what existing users see
- [ ] Switching applies immediately across Home, Calendar, Globe, Places and
      Settings — no relaunch, no half-themed screen
- [ ] **Tropical Spritz (light):** status bar flips to dark content; no
      white-on-cream text anywhere. Check specifically the flag chips (ring
      and the split-flag divider), the mini globe, empty states, and the
      setup checklist card
- [ ] **Mercury Dark:** near-black grounds, lime accents, mono numerals on
      counters and stats
- [ ] Fonts shift on headers and big numbers only — Tropical gets a serif
      display face, Mercury gets mono numerals. Body copy and controls are
      untouched
- [ ] Home-screen widgets follow within a few seconds of switching (all
      sizes), and so does the Live Activity if a trip is active. Requires the
      App Group — without it widgets stay Night Flight rather than crashing
- [ ] The choice survives a force-quit and relaunch
- [ ] Photo lightbox and Wrapped stay black in every theme — intentional, not
      a miss
- [ ] Share cards render in the active theme
- [ ] Switch themes with VoiceOver on: each row announces its name, selected
      state, and tagline

### X7a — Year in Travel on a non-default theme

Wrapped is a full-screen story and stays dark in every theme. The aurora
behind it is the visible ground, so it uses the story palette, not the app one.

- [ ] Open Year in Travel on **Tropical Spritz**: the story is dark (warm
      near-black), NOT cream. Progress bars, the ✕ and the share button are
      visible against it
- [ ] Its accents are the bright reference pastels — lagoon, hibiscus, mango,
      margarita — which only work on a dark ground and are deliberately
      brighter here than the same tokens elsewhere in the app
- [ ] Open it on **Mercury Dark**: near-black with lime accents; tertiary
      labels (dates, small captions) are readable, not ghosted
- [ ] Every page: opener, countries, travel days, podium, longest trip, first
      visits, map, photos, closer — no invisible text on any of them
- [ ] The Wrapped **share cards** are the exception and DO follow the app
      theme, because they render on their own themed ground rather than on the
      story surface. On Tropical they should be cream with dark text

## Z: 2.0 overhaul: limits, passport, widgets, system surfaces

Fixture: `python3 Tools/make_screenshot_library.py <dir>`, load with
`xcrun simctl addmedia`, then Settings › Time Machine › Re-sync. It produces
about two years of travel reaching yesterday, home = United Kingdom.

Automated: `Tools/check.sh` (Kit tests cover the limit maths, continents,
stamps, insights, badges and the year grid).

### Z1: Navigation

- [ ] Tab bar reads Home, Calendar, World, Passport, Settings
- [ ] World has three faces: Globe, Countries, Places. Places keeps its search
      field, category chips and sort button
- [ ] `beenthere://limits`, `beenthere://passport`, `beenthere://places`,
      `beenthere://countries` and `beenthere://settings/photos` each land on
      the right screen
- [ ] Countries rows show full names and subtitles ("United Kingdom",
      "22 trips · last NOV 9") with no truncation

### Z2: Home

- [ ] Hero shows country, "Here since", Day N, days this year, days all time
- [ ] With a ceiling that counts today, the hero carries its bar and
      "used/limit · N days left"; tapping it opens that limit
- [ ] Year heatmap: travel days lit, border days in the second accent, future
      days faint; tapping opens Calendar
- [ ] Day limits: up to three rows, or the "Count the days that matter" card
      when none exist
- [ ] Insights shelf scrolls sideways; each card opens Passport
- [ ] Setup checklist, tracking pill, Year in Travel rows and the waiting card
      still appear in their old conditions

### Z3: Day limits

- [ ] Presets add in one tap: Schengen 90/180, UK absences, UK tax year (home
      = GB), or a calendar-year 183 for any other home
- [ ] Detail: ring, headline, outlook sentence, window dates, "Days with no
      data" when there are any, the window day by day, where the days came
      from, and the trip planner
- [ ] Planner: move the arrival date later and the available days rise as old
      days roll out of a rolling window
- [ ] Custom limit: change country, period, goal and number; the sentence under
      the form reads correctly; Save creates it; Edit changes it; Delete
      removes only the rule
- [ ] Set a day to a Schengen country on the calendar: the Schengen count
      rises (by more than one if gap-fill extends the stay); Revert to
      automatic restores it
- [ ] A UK absence trip counts only the whole days away, not the travel days

### Z4: Passport

- [ ] Cover: country count, % of 195, continents, travel days, km, badges
- [ ] Continent rings: seven, with visited/total; Antarctica reads "bonus"
- [ ] Stamps: one per country, newest first by default; order menu switches
      to Most days and A to Z; tapping a stamp opens the country
- [ ] Badges: earned ones lit, locked ones show a progress ring and count;
      All/Fewer toggles the full shelf
- [ ] The long view: countries per year bars, distance, farthest, longest
      trip, typical trip, favourite month, home stretch, share away, extremes
- [ ] Wishlist: add a visited country and an unvisited one; the visited one
      shows a tick and its date, the other waits at the top; ✕ removes

### Z5: Widgets (needs the App Group)

- [ ] Gallery lists: You're In, Day Limit, On This Day, Travel Graph,
      Momentum, Countries, Your Top, Your World, Passport, Continents
- [ ] Day Limit small shows the real count; long-press › Edit Widget lets you
      pick a rule; unconfigured, it follows the most pressing one
- [ ] Your Top: tapping the pill flips between the year and all time without
      opening the app
- [ ] Travel Graph large is twelve small calendars; medium is the week strip
- [ ] Lock Screen: Day Limit circular, rectangular and inline; You're In
      inline carries the limit headline when one is counting
- [ ] Control Center › add a control › Been There offers Day Limits and
      Passport; each opens the app on that screen

### Z6: Live Activity

- [ ] Abroad with no rule counting: banner and island as before
- [ ] Abroad with a ceiling counting: Lock Screen banner gains the limit bar,
      compact island shows days left instead of the day number, expanded
      island shows the bar

### Z7: Siri and Shortcuts

- [ ] Shortcuts app lists Where Am I, Day Limits, Days in a Country and the
      open-a-screen shortcut under Been There
- [ ] **On a device**, each runs and speaks its answer. The iOS 26.5
      simulator cannot execute App Shortcuts at all (Apple FB23504349:
      "Unable to run App Shortcut"), so on the simulator check the wording at
      Settings › Developer › Siri answers instead
- [ ] Day limit reminders: with a ceiling counting and more than a week of
      runway, two notifications are pending (a week before and the day
      before); turning off "Day limit reminders" clears them

### Z8: Themes

- [ ] Home, Day limits, limit detail and Passport on Tropical Spritz: no
      white-on-cream text, rings and bars visible, stamps legible
- [ ] Same screens on Mercury Dark
- [ ] Widgets follow the theme a few seconds after switching

### Z9: Bold skins

- [ ] A fresh install opens in Paper: grey ground, white cards, black ink.
      An install that had picked a classic skin keeps it
- [ ] Settings › Skin: seven hex swatches (four bold, a rule, three classic).
      Tapping one re-skins the whole app at once and ticks a haptic
- [ ] Home hero: a 3D globe on an extruded day number. The country you are in
      faces you and is the "now" colour; visited countries are inlaid in the
      ground colour. Drag sideways to spin (haptic detents), double-tap to
      recentre. Vertical drags still scroll the page
- [ ] With Reduce Motion on, the globe stops breathing
- [ ] Screen titles are compressed caps; section labels and settings rows are
      mono caps; fills (chips, bars, buttons) are solid ink
- [ ] Graphite, Hi-Vis and Poolside: no unreadable text on any screen; the
      globe and number read against each ground
- [ ] The three classic skins look exactly as before, minus the dark wedge
      that used to sit behind Home and Passport
- [ ] Year in Travel on a light bold skin: dark story, skin-coloured accents
- [ ] Widgets follow the skin: flat card ground, poster numerals

### Z10: Wide layouts (iPhone Duo stand-in)

Build for an iPad mini simulator with `TARGETED_DEVICE_FAMILY=1,2` (see
CLAUDE.md), or on an open Duo once Xcode 27.1 is installed.

- [ ] Home: hero and limits on the left, year, stats, top countries and
      insights on the right
- [ ] Passport: cover, continents, badges and wishlist left; stamps and the
      long view right
- [ ] Calendar: two months abreast, tops aligned
- [ ] World: globe with the ranked country ledger alongside
- [ ] Limit detail: gauge and facts left; window, breakdown and planner right
- [ ] Day limits list and country detail stay one readable column
- [ ] On a real Duo: fold and unfold mid-screen keeps your place; half-folded
      nothing important sits under the hinge (not yet handled in code)
- [ ] World on a bold skin: the map is greyscale and tinted with the skin's
      ground (yellow on Hi-Vis, blue on Poolside, dark on Graphite); visited
      countries are ink washes, home is solid ink, chips are printed labels
      ("GB 479D") with home inverted. Classic skins keep the colour map and
      flag chips
- [ ] Settings rows are mono caps but their descriptions and section footers
      stay in sentence case
- [ ] App icon on the Home Screen: black globe on paper, one red country (regenerate with `python3 Tools/make_appicon.py`)
- [ ] Year in Travel opener on Paper: the globe is a light ball on the dark
      page, not a black one

### Z11: Power-user pass

- [ ] Day Limits › Planned trips: add a trip; rules it affects gain a "With
      plans" line; rules it doesn't touch stay quiet. Remove it and the lines go
- [ ] A plan that breaks a ceiling shows "over the limit from <date>" on Day
      Limits and on Home; a harmless plan never appears on Home
- [ ] Limit detail: "With your planned trips" card (peak, date, verdict)
- [ ] Limit detail, rolling rule: "Highest ever" row. Fixed rule: "Year by
      year" bars, newest first, empty early years trimmed, over-limit years red
- [ ] Limit detail › ⋯ › Export report: CSV with one line per counted stretch
- [ ] "Days with no data" row opens Review gaps scoped to that window
- [ ] Settings › Data › Review gaps: coverage bar; No data / Assumed tabs;
      "At home" or "Confirm" settles a run and the counts move; "Somewhere
      else" opens the country picker; "Confirm all" asks first
- [ ] Settings › Data › Back up everything shares a JSON; Restore from a
      backup merges it. Restoring the same file twice reports nothing new
- [ ] Restore a backup onto a fresh install: history, limits and home arrive
- [ ] Calendar › + › Go to a date opens that day's editor
