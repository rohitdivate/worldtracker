# Releasing without a Mac

`README.md` and `docs/APP_STORE.md` both assume you're sitting at a Mac with
Xcode. This page is the alternative: get a build to TestFlight from CI, with no
Mac in the loop.

Two pipelines are wired up so they can be compared head-to-head. **Both are
unproven until someone with an Apple Developer account runs them** — see
[Status](#status) at the bottom. Once one wins, delete the other; two
half-maintained release pipelines are worse than either alone.

---

## What you need first (both routes)

Nothing below works without these. They're all Apple-side, and none of them can
be automated away.

1. **Apple Developer Program membership**, $99/yr. `docs/APP_STORE.md` §1 walks
   through enrolment. A free Personal Team can install on your own phone but
   cannot ship to TestFlight.
2. **A real bundle identifier.** The repo ships the placeholder
   `com.example.worldtracker` and will keep shipping it — see
   [Bundle identifier](#bundle-identifier) for how each route overrides it.
3. **An App Store Connect API key.** App Store Connect → Users and Access →
   Integrations → App Store Connect API → generate a key with the **App
   Manager** role. You get a one-time `.p8` download plus a **Key ID** and an
   **Issuer ID**. The `.p8` cannot be re-downloaded.
4. **An app record** in App Store Connect (`docs/APP_STORE.md` §3), and the App
   Group `group.<your-bundle-id>` enabled on both the app and the
   `.widgets` App IDs.

> **Never commit the `.p8`, Key ID, Issuer ID, or Team ID.** This repository is
> public. They belong in GitHub Actions secrets or EAS secrets only.

### Bundle identifier

Been There derives every identifier from one build setting, `APP_BUNDLE_ID`
(`WorldTracker.xcodeproj/project.pbxproj`). The widget becomes
`$(APP_BUNDLE_ID).widgets` and both entitlements interpolate
`group.$(APP_BUNDLE_ID)`, so there is exactly one value to change.

- **Route A** reads it from the repository *variable* `APP_BUNDLE_ID` and
  passes it to `xcodebuild` on the command line. Nothing to commit.
- **Route B** needs it committed in `app.json` (`expo.ios.bundleIdentifier`)
  for EAS credential management to work, and it must match `APP_BUNDLE_ID` in
  the pbxproj. That's a real point against Route B: the value has to live in
  two places and be committed to a public repo.

---

## Route A — GitHub Actions

Extends what already exists: `.github/workflows/ios-build.yml` has been
compiling this project on a `macos-15` runner all along. The new
`.github/workflows/testflight.yml` adds signing and upload.

**Why this is simpler than most iOS CI guides:** since Xcode 13, `xcodebuild`
accepts an App Store Connect API key directly. Passing `-allowProvisioningUpdates`
alongside `-authenticationKeyPath` / `-authenticationKeyID` /
`-authenticationKeyIssuerID` lets Xcode create the distribution certificate and
**both** provisioning profiles on the runner. No fastlane match, no `.p12`, no
keychain import, no certificate rotation chore.

### Setup

Repository → Settings → Secrets and variables → Actions:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `ASC_PRIVATE_KEY` | Full contents of the `.p8`, including the BEGIN/END lines |
| Secret | `ASC_KEY_ID` | Key ID from App Store Connect |
| Secret | `ASC_ISSUER_ID` | Issuer ID from App Store Connect |
| Secret | `APPLE_TEAM_ID` | 10-character Team ID from developer.apple.com |
| Variable | `APP_BUNDLE_ID` | e.g. `com.rohitdivate.beenthere` |

### Running

Actions → **testflight** → Run workflow. Untick *submit* for a dry run that
archives and exports but uploads nothing — worth doing first. Pushing a `v*`
tag also triggers a full release.

The build number comes from `github.run_number`, injected as
`CURRENT_PROJECT_VERSION`. It is never committed, so the pbxproj stays clean
and TestFlight never sees a duplicate. `MARKETING_VERSION` stays hand-bumped in
the project file.

**Cost: nothing.** This repo is public, so GitHub-hosted macOS runners are
free.

---

## Route B — EAS Build

Uses the EAS project `6b375751-24ae-4a1d-828c-b2bac2ff718d`. Expo's docs state
that [EAS Build is designed to work for any native project, whether or not you
use Expo and React Native](https://docs.expo.dev/build/introduction/), via
[custom builds](https://docs.expo.dev/custom-builds/get-started/).

Files added: `package.json` and `app.json` (shims — nothing ships in the app),
`eas.json`, and `.eas/build/{smoke,ios}.yml`.

Two things make a native-only project work:

- **`package.json` is mandatory** even with no JavaScript, and the `expo`
  package must be installed for the build functions to resolve project context.
- **EAS looks for the Xcode project under `./ios`.** Been There keeps
  `WorldTracker.xcodeproj` at the repo root, so both build configs run
  `ln -sf . ios` to present the root as a prebuilt iOS project. Nothing moves;
  the hand-authored pbxproj is untouched.

### Smoke test first

The genuinely uncertain part of this route is whether EAS runs a zero-JavaScript
native repo at all. `.eas/build/smoke.yml` tests exactly that, with
`withoutCredentials` so it cannot touch your Apple account:

```bash
npx eas-cli@latest build -p ios -e smoke
```

It checks out, symlinks `ios`, compiles unsigned, and runs
`Tools/validate_project.py`. **If this fails, stop — Route B is dead** and
Route A is the answer.

### Full build

```bash
npx eas-cli@latest build -p ios -e production
npx eas-cli@latest submit -p ios
```

Before submitting, replace the `ascAppId` placeholder in `eas.json` with the
app record's numeric Apple ID from App Store Connect.

Credentials are EAS-managed: it detects the `BeenThereWidgets` app extension
from the Xcode project and [generates credentials for each
target](https://docs.expo.dev/build-reference/app-extensions/), covering the
widget's separate bundle id. That automatic handling of the second target is
the one place Route B may genuinely beat Route A.

Check EAS's current free-tier build allowance before committing to this route —
it's a recurring cost Route A doesn't have.

### The dependency cost — read this before choosing Route B

`expo` is pinned to `57.0.8` (never `latest` — an unpinned dependency in a
committed manifest is its own supply-chain risk). That single direct dependency
resolves to **481 npm packages**, including `@react-native/debugger-frontend`,
`node-forge`, `fast-xml-parser` and `yargs`. Socket Security flags several as
"likely obfuscated" — that's its heuristic firing on minified bundles rather
than evidence of anything malicious, and the checks pass at warn level.

None of it ships inside the app. Been There stays pure Swift, and no JavaScript
reaches the device. But it does mean a repo whose entire pitch is *no accounts,
no servers, no analytics* would carry a React Native dependency tree in its
build path, reviewed on every PR, and a new class of supply-chain exposure that
Route A simply doesn't have.

That's a judgement call, not a blocker — it's recorded here so it's made
deliberately.

---

## Status

Neither route has produced a TestFlight build yet. Both are blocked on the
Apple Developer account and API key above. Fill this in as they run:

| | Route A (GitHub Actions) | Route B (EAS) |
| --- | --- | --- |
| Smoke test passes | n/a | ☐ |
| Archive + export succeeds | ☐ | ☐ |
| Build reaches TestFlight | ☐ | ☐ |
| Wall-clock per build | ☐ | ☐ |
| Recurring cost | free (public repo) | ☐ check EAS tier |
| Non-Swift files added | 2 | 5 + `node_modules` |
| npm dependency tree | none | **481 packages** |
| Bundle id committed? | no | yes |
| Widget target signing | ☐ auto via `-allowProvisioningUpdates`? | ☐ auto via EAS? |

### Known risk

The likeliest first failure on **either** route is App Group provisioning. If
signing fails on `group.<bundle-id>`, register the group manually at
developer.apple.com → Identifiers → App Groups, enable it on both App IDs, and
re-run.

### After deciding

Delete the losing route's files, and fold the winner into `docs/APP_STORE.md`
(which currently assumes a Mac throughout). A hybrid is also legitimate: build
in GitHub Actions, then upload with `eas submit --path`, which [accepts any
correctly-signed `.ipa`](https://docs.expo.dev/submit/ios/).
