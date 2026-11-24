# Been There — notes for Claude

A private, offline iOS travel tracker: it notices which country and city you're
in, reconstructs past travel from photo metadata, and shows it as a calendar of
flags, a lit globe, and the places you actually visited. No accounts, no
servers, no analytics — data stays on the device (optionally the user's own
iCloud). iOS 18+, Xcode 16+.

## Layout

| Path | What it is |
| --- | --- |
| `WorldTracker/` | App target: SwiftUI screens (`Features/`), services (`Services/`), SwiftData models (`Data/`), design tokens (`DesignSystem/`), Siri/Shortcuts (`Intents/`) |
| `WorldTrackerKit/` | Local Swift package holding **all pure logic** — day resolver, day limits, insights and badges, offline geocoding, epoch-day math, photo clustering, theme palettes. Tests run on Linux and macOS, no Xcode needed |
| `BeenThereWidgets/` | WidgetKit extension (`.appex`, embedded in the app's PlugIns): Home Screen, Lock Screen and StandBy widgets, the Live Activity, Control Center controls |
| `Config/` | Info.plists and entitlements for both targets |
| `Tools/` | `check.sh` (pre-commit gate), `validate_project.py` (invariants), geodata build scripts |
| `docs/` | `ARCHITECTURE.md`, `VERIFICATION.md` (on-device QA checklists), `SETUP_MAC.md`, `APP_STORE.md`, `RELEASE.md` |

## Commands

```bash
Tools/check.sh                                   # the pre-commit gate — prefer this
swift test --package-path WorldTrackerKit        # the real logic tests
python3 Tools/validate_project.py                # project / plist / asset invariants
Tools/deploy_to_phone.sh [--watch]               # build → network-paired iPhone, no cable (Mac only)

# Compile the app — same invocation as CI, and the authoritative check
xcodebuild -project WorldTracker.xcodeproj -scheme WorldTracker \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

`check.sh` runs the Kit tests, `swiftc -parse` over every app source (syntax
only, not a type check), the project invariants, and the geodata golden checks.
It skips any step whose toolchain is missing rather than failing. CI is the
backstop: `.github/workflows/kit-tests.yml` (Linux) and `ios-build.yml` (macOS).

Only the Kit compiles off a Mac. On Linux, `swift test --package-path
WorldTrackerKit` is the most verification available — the app target needs
`xcodebuild`.

There is no UI test target (the validator pins the project at two targets).
Screens are verified by running them: `Tools/make_screenshot_library.py`
builds a geotagged photo library that the app's own photo scan turns into
about two years of travel, which is the fixture every screen and widget is
checked against. `docs/VERIFICATION.md` section Z lists the pass.

## Releasing

`docs/APP_STORE.md` is the by-hand, sitting-at-a-Mac path. `docs/RELEASE.md`
covers the Mac-free one: `.github/workflows/testflight.yml` archives, signs and
uploads to TestFlight on a hosted macOS runner, using an App Store Connect API
key with `-allowProvisioningUpdates` instead of managed certificates.

**It has never produced a build** — it's blocked on Apple credentials, so don't
describe it as working. Signing is the untested part; the compile path is the
same one `ios-build.yml` exercises on every push.

This project is pure Swift with **no JavaScript, Expo, or React Native**. An EAS
Build scaffold was trialled as an alternative and removed; `docs/RELEASE.md`
records why. If you find yourself adding a `package.json` here, re-read that
section first.

## The model: facts in, verdicts computed

This is the thing to understand before changing anything about history, trips,
or stats.

The database stores **facts**, never conclusions:
`CountryDayFact(epochDay, countryCode, source, confidence, evidenceCount)` where
source is `gps | visit | photo | manual | timezoneHint | importedTimeline |
importedFlight`, plus `DayAnnotation(epochDay, isCleared, note)`.

`DayLedgerResolver` (in the Kit) turns those into per-day verdicts at query
time: highest-precedence tier wins — **manual > gps/visit > imported > photo >
timezoneHint** — then a gap-fill policy (`leaveEmpty`,
`assumePreviousLocation`, `fillShortGaps(maxDays:)`) fills days with no
evidence. A day with `isCleared` resolves to empty *and* hard-stops the
gap-fill chain across it; that is the "no data" mechanism, and it's what makes
automatic evidence hideable without erasing it.

Consequences worth internalising:

- **Trips are derived, not stored.** `DayLedgerResolver.segments(from:)` returns
  maximal runs of consecutive days per country; border days belong to both
  neighbouring runs. There is no trip row to edit.
- **Removing days from a trip takes more than deleting manual facts.** The
  day's automatic gps/photo facts would re-resolve to the same country, and
  gap-fill would re-fill emptied days from the neighbours. Use
  `TripEditPlanner` (Kit) to bucket the removed days — clear the solo ones, pin
  the surviving countries on border days — and apply it through `EditService`.
  This is a bug the codebase has already had; don't reintroduce it.
- **Day boundaries use the timezone of the place, never the device.** Always go
  through `EpochDay(date:timeZone:)`, or evening Tokyo photos land on
  yesterday.
- Changing a setting re-renders all history for free, and a photo re-scan can
  never clobber a manual edit.

`LedgerStore` (app side) caches resolution and bumps `changeToken` when
`.ledgerDidChange` posts; views read `store.changeToken` to refresh. Batch
writes so one user action produces one save and one notification.

## Tabs and routing

Five tabs: **Home, Calendar, World, Passport, Settings**. Places is no longer a
tab; it is the third face of World (Globe / Countries / Places), and that mode
lives on `AppRouter.worldMode` so links can land on it.

Everything that navigates goes through `AppRouter`: tab switches, Home's
`NavigationPath` (it pushes country codes, trip segments and `HomeRoute`s), and
the `beenthere://` scheme. Widgets, Control Center, notifications and Siri all
use the same hosts: `home`, `calendar`, `map`, `countries`, `places`,
`passport`, `limits[/<rule id>]`, `settings[/<route>]`. Add a destination there,
not as an ad-hoc `NavigationLink` from a widget URL.

## Wide layouts (iPhone Duo)

Screens key on `horizontalSizeClass == .regular`, which is what Duo's open
inner display reports. Home, Passport, Calendar, World and limit detail go
two-column; the single-column screens cap at a readable 640pt. Nothing checks
for a device.

This Mac cannot build against the Duo SDK yet (needs Xcode 27.1, which needs
macOS 26.6). Until it can, the stand-in is an iPad mini simulator, close to
Duo's inner display in points, built with a command-line family override that
is never committed:

```bash
xcodebuild -project WorldTracker.xcodeproj -scheme WorldTracker \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' \
  -derivedDataPath build/ipad TARGETED_DEVICE_FAMILY=1,2 build
xcrun simctl launch <UDID> <bundle id> -debugOpen beenthere://passport
```

`-debugOpen` (DEBUG builds only) lands on a screen without a tap;
`-debugBackupTo <path>` and `-debugRestoreFrom <path>` write or merge a backup
at a host path, which is how a ledger moves between simulators. Hinge and
posture handling (`onHingeChange`, reserved regions) is not written: it needs
the SDK to compile.

## Derived features: limits, passport, insights

Same rule as trips: **computed from resolved days, never stored**. All of it is
in the Kit with tests.

- **Day limits** (`Limits/DayLimits.swift`): a `DayLimitRule` is a scope
  (country / Schengen / days outside a country), a window (rolling N days,
  calendar year, year starting on a date) and a number. `DayLimitEvaluator`
  returns used / remaining / runway / the day days free up. Rules are settings,
  kept as one Codable blob in UserDefaults by `DayLimitStore`; no SwiftData.
  - Counting is any-presence, so a border day counts for a country and for
    Schengen. "Outside" is the inverse: only *whole* days away, which is how
    absence rules count.
  - A day with no verdict is never counted. It is reported as `unknownDays`
    and shown, because a silently low number is the dangerous failure here.
  - `runwayDays` for a rolling window is not `limit - used`: days roll out of
    the window during a stay. Don't "simplify" it to a subtraction.
- **Passport** (`Insights/`): stamps (`PassportBook`), continent rings
  (`ContinentTable`: the 195 sovereign states are the denominators, matching
  `MilestoneEngine.worldCountryCount`), badges (`AchievementEngine`), lifetime
  insights (`TravelInsightsEngine`), and the week-aligned `YearGrid` shared by
  the Home heatmap and the Travel Graph widget.
- `InsightsStore` (app) caches one `Summary` per ledger change. Distances need
  coordinates, which load async (`warm(store:)`); until then km reads zero and
  `revision` bumps when they arrive. The wishlist lives there too.

- **Limit analysis** (`Limits/DayLimitAnalysis.swift`): the layer a careful
  user leans on. `forecast` runs a rule forward over planned trips
  (`TripPlans.projectedDays` turns `PlannedTrip`s into future resolved days:
  travel days touch home, days between trips are at home); `peak` and
  `pastWindows` say how a rule stood historically; `stretches` are the line
  items behind a count (the CSV report); `DayAudit` finds days with no data or
  only assumed data. Plans are settings in `PlanStore`, never ledger facts.
- **Backup** (`Backup/BackupArchive.swift`, app `BackupService`): a
  full-fidelity archive of *facts*, annotations and settings. The CSV/JSON
  exports are resolved days for people; this is for the app to read back.
  Restore goes through `BackupMergePlan` and only ever adds. Bump
  `BackupArchive.currentVersion` on a breaking change; older builds refuse a
  newer archive rather than half-reading it.

Where these surface, on purpose in existing screens: forecasts and planned
trips on Day Limits (Home shows a forecast only when it breaks a limit),
history and the report in limit detail, gap review from limit detail and
Settings › Data, backup in Settings › Data, go-to-date in the Calendar menu.

Adding a country code to the atlas means adding it to `ContinentTable`;
`InsightsTests.testEveryAtlasCountryHasAContinent` fails otherwise.

## Widgets, Live Activity, controls, Siri

- The widget process only reads. `SharedSnapshotStore.write(from:)` puts one
  JSON in the App Group with everything pre-evaluated (limit statuses, stamps,
  continents, day tones). Widgets draw; they never recompute.
- Two intents files, on purpose. `OpenBeenThereIntent` /
  `BeenThereDestination` exist in **both** `WorldTracker/Intents/` and
  `BeenThereWidgets/WidgetIntents.swift`: controls are declared in the
  extension, but an open-the-app intent is performed by the app. The validator
  compares the two.
- A `WidgetBundle` body holds at most ten widgets, so the bundle is split into
  `GlanceWidgets` and `CollectionWidgets`. Add to one of those.
- Your Top's period pill is an interactive widget (`ToggleTopPeriodIntent`); it
  runs in the widget process and flips a key in the App Group defaults.
- The Day Limit widget is configurable (`SelectLimitIntent`). Unconfigured, it
  follows the most pressing rule (`pressingLimit`).
- Live Activity state carries optional limit fields. They must stay optional:
  an activity started by an older build has to keep decoding.

## Themes

Seven selectable skins in two families. A palette's `style` decides which:

- **Bold** (`.bold`): Paper (the default, light), Graphite, Hi-Vis, Poolside.
  Flat grounds, borderless flat cards, solid ink fills instead of gradients,
  compressed poster numerals, an expanded headline face, mono caps labels,
  caps screen titles, and the 3D globe hero on Home. The look is modelled on
  the Not Boring apps: one object, one number, one loud colour.
- **Classic** (`.aurora`): Night Flight, Tropical Spritz, Mercury Dark. The
  original aurora mesh, gradient fills and hairline cards, unchanged.

Colour, type and surface treatment only; no skin changes behaviour.

How the split is carried, so a screen never branches on a skin by name:

- `Theme.auroraGradient` is solid ink on bold skins. That one token is why
  buttons, chips, bars and big numerals go monochrome without edits.
- `nightCard()` and `AuroraBackground` flatten themselves on bold skins.
- Font roles: `display` (headline word), `poster` (the one huge number or
  title), `figure` (small counts, was hardcoded rounded), `label` (tracked
  caps), `numeric`, `body`, `footnote`. Use a role, never
  `.system(..., design: .rounded)`: a raw font ignores the skin.
- `Theme.title("Overview")` uppercases screen titles on bold skins;
  `ThemeChrome` sets the navigation bar faces through UIKit appearance.
- Lists and forms: `.themedList()` plus a `Group { … }.listRowBackground(Theme.card)`
  around the sections. Stock grey rows clash with every skin.
- Branch on `Theme.isBold` only where the *layout* differs (the Home hero).

Home's bold hero (`Features/Home/HeroGlobe.swift`) is SceneKit: a sphere
textured from the Kit's 110m outlines (visited countries inlaid in the ground
colour, the current one in the "now" colour) sitting on an extruded day
number. Two things that look like bugs and are not: the number is `SCNText`
in the regular black face squeezed horizontally, because `SCNText` ignores the
font's width axis and `SCNShape` produces no geometry from the compressed
glyph outlines; and the globe's yaw is simply minus the longitude, because
SceneKit puts the texture's centre at the front.

**Palette data lives in the Kit**
(`WorldTrackerKit/Sources/WorldTrackerKit/Design/ThemePalettes.swift`) as plain
RGBA numbers, because SwiftUI doesn't exist on Linux and this is the only part
of the design system that can be tested without a Mac. The app's `Theme` and
the widget's `WTheme` each map `ColorToken` → `Color`. That's what killed the
old hand-synced duplication between those two files — don't reintroduce it.

Things to know before touching this:

- **`Theme.x` tokens are computed, not constants.** That's deliberate: it let
  ~619 existing call sites keep working while the palette swaps underneath.
  Adding a token means adding it to `ThemePalette` (which forces all three
  palettes to supply it) and surfacing it on both `Theme` and `WTheme`.
  `validate_project.py` checks that.
- **SwiftUI can't observe a static**, so the root view is keyed on the
  selection — `.id(themeID)` in `WorldTrackerApp` is what makes a switch
  render. Removing it makes theme changes appear to do nothing until relaunch.
- **`ThemeStore.select(_:)` is the only place to change theme.** It persists,
  mirrors the id into the App Group for the widgets, swaps `Theme.palette`,
  and reloads widget timelines. Writing the default directly skips three of
  those four.
- **The light theme is where bugs hide.** A hardcoded `Color.white` looks fine
  in two themes and vanishes in Tropical Spritz. `Theme.gloss` exists for
  exactly that case.
- Accent colours are painted as *foreground ink* here, not as fills, so
  palettes are contrast-tested against every ground in `ThemePaletteTests` —
  Tropical's source pastels failed at 1.65:1 and are deliberately darkened
  from the design reference.
- Photo lightbox and Wrapped stay black in every theme, on purpose. Both say
  so in a comment.

## Repo gotchas

`Tools/validate_project.py` enforces all of these — run it after touching the
project file, plists, entitlements, or assets.

- **The `.xcodeproj` is hand-authored** at `objectVersion = 77` and uses
  `PBXFileSystemSynchronizedRootGroup`s. Adding a Swift file under a synced
  folder needs **no** project-file edit — just write the file. Avoid hand-editing
  the pbxproj unless there's no alternative.
- Exactly two native targets (app + widget extension); the app depends on the
  widget and embeds the `.appex` into PlugIns.
- Bundle IDs come from `$(APP_BUNDLE_ID)` and `$(APP_BUNDLE_ID).widgets`; both
  entitlements share the `group.$(APP_BUNDLE_ID)` App Group.
- **`WorldTracker/Services/Widgets/SharedSnapshot.swift` and
  `BeenThereWidgets/WidgetSnapshot.swift` must stay field-for-field in sync** —
  they're the two halves of one Codable contract, and the validator compares
  every field, nested structs included. New fields go at the end and are
  optional, so a snapshot written by an older app build still decodes.
- The shared scheme `WorldTracker.xcscheme` stays committed.
- SwiftData models stay CloudKit-compatible: defaults everywhere, optional
  relationships, no unique constraints.

## Conventions

- New pure logic goes in `WorldTrackerKit` with tests, so it's verifiable
  without a Mac. App-target code stays thin: views, services, persistence.
- Match the surrounding style — the codebase favours small focused view
  builders (SwiftUI type-checker cost is real) and comments that explain a
  constraint rather than narrate the code.
- On-device behaviour that can't be unit-tested belongs in a
  `docs/VERIFICATION.md` checklist item.

## Running the app in a simulator

On a Mac, ask for a build-and-run and the simulator opens next to the
conversation. Name a device to pick one ("run it on the iPhone SE simulator").
If no simulators are listed, install a runtime with `xcodebuild -downloadPlatform
iOS`. Simulated devices only — a physical iPhone has to be run from Xcode.
