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

*(Later milestones will append their checklists here.)*
