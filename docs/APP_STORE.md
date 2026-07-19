# Shipping Been There to the App Store — the complete walkthrough

Everything code-side is already done (privacy manifests, honest permission
strings, export-compliance key, icon, launch screen, version 1.0). What
remains is Apple-side paperwork and clicks. In order:

## 0. What you need

- The **Apple Developer Program** — $99/year. Your free Personal Team can
  install on your own phone but cannot ship to the App Store.
- A Mac with Xcode (you have this), ~1 hour of clicking, and 1–2 days of
  waiting (enrollment + review).

## 1. Enroll (Day 0)

1. Go to https://developer.apple.com/programs/enroll and enroll with the
   same Apple Account you use in Xcode. Pay the $99.
2. Approval is usually minutes-to-48h. You'll get an email.

## 2. Re-point Xcode at your new team (5 min, after approval)

1. Xcode → open the project → target **WorldTracker** → Signing &
   Capabilities → Team: pick your NEW team (it stops saying "Personal
   Team"). Repeat for the **BeenThereWidgets** target.
2. Keep the bundle id you set in `APP_BUNDLE_ID` (README §4). It must be
   globally unique — reverse-DNS like `com.yourname.beenthere` is ideal.
3. Optional now, fine later: re-add the iCloud capability for backup
   (README §7) — paid teams support it. The app works fully without it.

## 3. Create the app record in App Store Connect (10 min)

1. https://appstoreconnect.apple.com → My Apps → **+** → New App.
2. Platform iOS · Name **Been There** (if taken, fallback:
   **Been There — Travel Tracker**) · Primary language English ·
   Bundle ID: pick the one from step 2 (register it at
   https://developer.apple.com/account/resources/identifiers first if the
   dropdown doesn't show it) · SKU: `beenthere-001`.

## 4. Fill in App Information

- **Category:** Travel (secondary: Lifestyle)
- **Age rating:** answer the questionnaire honestly → comes out 4+
- **Privacy Policy URL:** the policy lives at `docs/PRIVACY_POLICY.md` in
  this repo. It needs a PUBLIC URL. Easiest: create a public GitHub gist,
  paste the policy in, use the gist URL. (Or make this repo public and use
  the GitHub file URL, or host it anywhere.)

## 5. App Privacy questionnaire (the "nutrition label")

Apple asks what data the app **collects** — meaning data that leaves the
device and reaches you or third parties. Been There sends nothing
anywhere, so the answers are:

- "Do you or your third-party partners collect data from this app?" → **No**
- Result: the listing shows **"Data Not Collected"** — a genuine selling
  point; almost no travel tracker can claim it.

(Using location/photos ON-device does not count as collection. The privacy
manifests in the repo say the same thing in machine-readable form.)

## 6. Pricing

Pricing and Availability → **Free** (0 USD), all territories.

## 7. Screenshots (15 min)

Required: one set for **6.9-inch** iPhones (Pro Max class). Two ways:

- **Simulator (exact sizes):** Xcode → run on an "iPhone 16 Pro Max"
  simulator → set it up (run a photo scan or add manual trips for demo
  data) → Cmd+S saves PNGs to the Desktop at the right resolution.
- **Your phone:** screenshots work if your iPhone is a Pro Max class
  model; otherwise use the simulator.

Suggested shots, in order: (1) Home with the today card + stat tiles,
(2) Calendar month of flags, (3) the globe with country day chips,
(4) zoomed globe with city chips, (5) a Wrapped page, (6) Places.
Upload under the version → App Previews and Screenshots.

## 8. App Store listing copy (paste-ready)

- **Subtitle (30 chars):** `Your travel map, on autopilot`
- **Promotional text:**
  `Every country, every day, logged automatically — and it all stays on your phone.`
- **Keywords (100 chars):**
  `travel,tracker,countries,visited,map,trip,log,journal,flags,globe,wrapped,passport,days,abroad`
- **Support URL:** your GitHub repo URL (or the gist)
- **Description:**

```
Been There quietly logs which country you're in, every day, using the
location work your iPhone already does — no battery drain, no check-ins,
no accounts.

REBUILD YEARS IN A MINUTE
Your photo library remembers where you've been. Been There reads only the
dates and locations of your photos — never the pictures — and rebuilds
years of travel history in about a minute. Google Timeline and flight
imports fill in the rest.

YOUR WORLD, BEAUTIFULLY
• A calendar where every day wears the flag of where you woke up
• A cinematic globe — countries you've visited glow, your cities appear
  as you zoom in
• Trips with your photos, cities, and every border crossing
• Places you actually went: the café, the museum, the beach
• Widgets and a Dynamic Island trip banner
• Your Year in Travel — a shareable Wrapped, every January

PRIVATE BY ARCHITECTURE
No accounts. No servers. No analytics. Your history lives on your device
(plus your own private iCloud, if you turn backup on). The App Store
label says "Data Not Collected" because there is nothing to collect.

HONEST NUMBERS
Days at home don't count as travel. Home moves are supported (lived in
two countries? tell it when you moved). Every day shows its evidence, and
everything is editable.

Been There — your world, quietly logged.
```

## 9. Upload the build (10 min)

1. In Xcode, select the **WorldTracker** scheme and destination
   **Any iOS Device (arm64)**.
2. Product → **Archive**. When the Organizer opens: **Distribute App** →
   **App Store Connect** → Upload → accept defaults → Upload.
3. Wait ~15 min for processing (email arrives). In App Store Connect →
   your app → the version page → Build section → select the build.
4. Export compliance is already answered in code
   (`ITSAppUsesNonExemptEncryption = false`) — no question should appear.

## 10. (Recommended) TestFlight first

TestFlight tab → add yourself (internal testing needs no review) → install
via the TestFlight app on your phone. Shake out anything odd for a day,
then submit. You can also invite friends — their reactions are your first
App Store reviews in waiting.

## 11. Submit for review

1. On the version page: **App Review Information** → add these notes:
   `No account or login is required. Location is used passively
   (significant-location-changes only — no continuous GPS) to log the
   country per day, entirely on device. Photo access is optional and reads
   metadata only. No data leaves the device.`
2. **Save** → **Add for Review** → **Submit**.
3. Typical wait: 24–48 hours. Location apps get an extra look; the honest
   purpose strings + the notes above are exactly what reviewers want.

## 12. After approval 🎉

1. Your listing URL is `https://apps.apple.com/app/id<NUMBER>` (shown in
   App Store Connect → App Information).
2. **Tell Claude the URL** — one constant (`AppLinks.appStoreShortURL`)
   gets filled in, and every share card the app produces starts carrying
   the link. That's the growth loop switching on.
3. Bump for future releases: `MARKETING_VERSION` (1.1, 1.2…) and
   `CURRENT_PROJECT_VERSION` (+1 per upload) in the project, then repeat
   step 9.

## Rejection risks (all pre-mitigated)

| Risk | Status |
|---|---|
| Vague location purpose strings | Honest, specific strings in `Config/Info.plist` ✓ |
| Privacy manifest missing | `PrivacyInfo.xcprivacy` in both targets ✓ |
| Privacy policy URL missing | `docs/PRIVACY_POLICY.md` — host it (step 4) |
| Background location abuse (2.5.4) | Not used — passive significant-change only ✓ |
| Account deletion rule | No accounts — N/A ✓ |
| Minimum functionality | Very much not a problem ✓ |
