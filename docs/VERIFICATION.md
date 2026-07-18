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

*(Later milestones will append their checklists here.)*
