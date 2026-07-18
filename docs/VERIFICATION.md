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

## M2 — Tracking (coming)

- [ ] Grant location permission via the in-app priming screen
- [ ] Walk/drive a few km; samples appear in Settings → Developer → Ingest log
- [ ] Leave the app closed overnight; next morning new samples exist

*(Later milestones will append their checklists here.)*
