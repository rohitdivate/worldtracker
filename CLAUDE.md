# Been There — notes for Claude

A private, offline iOS travel tracker: it notices which country and city you're
in, reconstructs past travel from photo metadata, and shows it as a calendar of
flags, a lit globe, and the places you actually visited. No accounts, no
servers, no analytics — data stays on the device (optionally the user's own
iCloud). iOS 18+, Xcode 16+.

## Layout

| Path | What it is |
| --- | --- |
| `WorldTracker/` | App target: SwiftUI screens (`Features/`), services (`Services/`), SwiftData models (`Data/`), design tokens (`DesignSystem/`) |
| `WorldTrackerKit/` | Local Swift package holding **all pure logic** — day resolver, offline geocoding, epoch-day math, photo clustering. Tests run on Linux, no Xcode needed |
| `BeenThereWidgets/` | WidgetKit extension (`.appex`, embedded in the app's PlugIns) |
| `Config/` | Info.plists and entitlements for both targets |
| `Tools/` | `check.sh` (pre-commit gate), `validate_project.py` (invariants), geodata build scripts |
| `docs/` | `ARCHITECTURE.md`, `VERIFICATION.md` (on-device QA checklists), `SETUP_MAC.md`, `APP_STORE.md` |

## Commands

```bash
Tools/check.sh                                   # the pre-commit gate — prefer this
swift test --package-path WorldTrackerKit        # the real logic tests
python3 Tools/validate_project.py                # project / plist / asset invariants

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
  them.
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
