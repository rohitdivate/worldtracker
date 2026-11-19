# Privacy

The public policy is `docs/PRIVACY_POLICY.md`. This page is the short
engineering summary, and it must stay true to the code.

- **No accounts.** Nothing to sign up for.
- **No developer server.** The developer receives no data. The app has no
  `URLSession` use, no analytics SDK and no third-party packages.
- **Apple services are used.** Place naming sends visit coordinates to
  Apple's geocoder and point-of-interest search
  (`WorldTracker/Services/Places/PlaceNamer.swift`), and the globe and place
  maps load from Apple Maps. Opening a photo full screen can download the
  original from the user's own iCloud Photos
  (`WorldTracker/DesignSystem/PhotoLightbox.swift`).
- **The travel log is stored on the device.** iCloud backup does not ship
  in 1.0: `AppDatabase.cloudBackupAvailable` is `false`, the Settings toggle
  is hidden and the store is always local.
- **Photos.** The scan reads each photo's date and location only. The app
  also shows the user's own photos (trip and place thumbnails, the
  full-screen viewer, Year in Travel) and writes one resized copy of a photo
  into the App Group container for the On This Day widget. Photos are never
  uploaded or edited.
- **Full export and deletion.** CSV and JSON export, a backup file, and
  "Delete all my data", which also clears settings in the standard and App
  Group defaults and the widget files.
