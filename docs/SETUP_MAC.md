# Mac setup — the long version

The README covers the happy path. This page adds detail for each step.

## Installing Xcode

App Store → search "Xcode" → Get. It's ~10GB; start it early. After install,
open Xcode once so it can install its extra components. If it asks which
platform to develop for, pick **iOS**.

## Apple ID / Developer account

Xcode → Settings (⌘,) → Accounts → "+" → Apple ID. Sign in with the same
Apple ID you'll use on your iPhone.

- **Free account:** you can build and run on your own device, but the app
  expires after 7 days and background features are less reliable. Fine for a
  first look.
- **Paid ($99/yr):** installs last ~1 year, iCloud backup (M9) works, and you
  can later use TestFlight. Join at developer.apple.com/programs — approval
  is usually same-day.

## Developer Mode on the iPhone

iOS hides development installs behind Developer Mode:
Settings → Privacy & Security → scroll to bottom → **Developer Mode** →
toggle on → phone restarts → confirm. If the menu item is missing, connect
the phone to Xcode once (plugged in, unlocked) and it appears.

## Running on the phone

The Xcode toolbar has: [▶] [■] then "WorldTracker ▸ ⟨device⟩".
Click the device part and pick your iPhone under "iOS Device". Press ▶.

First run does a lot: builds, signs, installs, launches. Watch the status
bar at the top of Xcode. Typical first-run hiccups are all in the README
troubleshooting table.

## Wireless debugging (optional, nice)

With the phone plugged in once: Window → Devices and Simulators → select
your iPhone → tick **Connect via network**. From then on you can deploy
over Wi-Fi.

## Keeping the app healthy

- Don't force-quit (swipe away) Been There — iOS then stops relaunching it
  for background location events. Just leave it; it uses no meaningful
  battery.
- Keep **Background App Refresh** on (Settings → General → Background App
  Refresh) — iOS disables all background location without it.
- The in-app **Tracking Health** screen (from M2) shows you at a glance if
  anything is misconfigured.
