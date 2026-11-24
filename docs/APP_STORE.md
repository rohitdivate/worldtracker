# Shipping Been There to the App Store — the complete walkthrough

Everything code-side is already done (privacy manifests, accurate permission
strings, export-compliance key, icon, launch screen, version 1.0 build 1). What
remains is Apple-side paperwork and clicks. In order:

> **No Mac?** This page assumes you're building and uploading from Xcode.
> `docs/RELEASE.md` covers the CI alternative — archive, sign and upload to
> TestFlight from a hosted macOS runner instead. The Apple-side steps below
> (§1 enrolment, §3 app record, §4 metadata) are still required either way.

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
3. iCloud backup does not ship in 1.0. The toggle is hidden
   (`AppDatabase.cloudBackupAvailable` is `false`) and the project carries no
   iCloud or push entitlement. Do not add the iCloud capability for this
   release.

## 3. Create the app record in App Store Connect (10 min)

1. https://appstoreconnect.apple.com → My Apps → **+** → New App.
2. Platform iOS · Name: the value in `docs/LISTING.md` · Primary language English ·
   Bundle ID: pick the one from step 2 (register it at
   https://developer.apple.com/account/resources/identifiers first if the
   dropdown doesn't show it) · SKU: `beenthere-001`.

## 4. Fill in App Information

- **Category:** Travel (secondary: Lifestyle)
- **Age rating:** answer the questionnaire honestly → comes out 4+
- **Privacy Policy URL:** the policy lives at `docs/PRIVACY_POLICY.md` in
  this repo. It needs a PUBLIC URL. Fill in the `[Developer name]`,
  `[contact email]` and date placeholders first, then publish it (the gist
  linked from `docs/LISTING.md`, or any public page).

## 5. App Privacy questionnaire (the "nutrition label")

Apple asks what data the app **collects**, meaning data that leaves the
device and reaches you or your partners. The developer receives nothing.
The only off-device traffic goes to Apple's own services (Apple Maps place
naming and map tiles, the user's iCloud Photos), which Apple does not ask
developers to declare. So the answers are:

- "Do you or your third-party partners collect data from this app?" → **No**
- Result: the listing shows **"Data Not Collected"**.

(Using location and photos on the device does not count as collection. The
privacy manifests in the repo say the same thing in machine-readable form.
Do not describe the app as "nothing leaves the device": place naming sends
coordinates to Apple.)

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

## 8. App Store listing copy

All listing copy (name, subtitle, promotional text, keywords, description,
What's New, review notes) lives in `docs/LISTING.md`. Paste from there so the
two pages cannot drift. Support URL: any public page with a way to reach you.

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

1. On the version page: **App Review Information** → paste the review notes
   from `docs/LISTING.md`.
2. **Save** → **Add for Review** → **Submit**.
3. Typical wait: 24–48 hours. Location apps get an extra look, so keep the
   purpose strings and the review notes accurate.

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
| Vague location purpose strings | Specific strings in `Config/Info.plist` that match the code ✓ |
| Privacy manifest missing | `PrivacyInfo.xcprivacy` in both targets ✓ |
| Privacy policy URL missing | `docs/PRIVACY_POLICY.md`: fill the placeholders and host it (step 4) |
| GeoNames attribution (CC BY 4.0) | Settings, Acknowledgements, plus `docs/GEODATA.md` ✓ |
| Background location abuse (2.5.4) | Not used — passive significant-change only ✓ |
| Account deletion rule | No accounts — N/A ✓ |
| Minimum functionality | Very much not a problem ✓ |
