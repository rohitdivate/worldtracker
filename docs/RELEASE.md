# Releasing without a Mac

`README.md` and `docs/APP_STORE.md` both assume you're sitting at a Mac with
Xcode. This page is the alternative: archive, sign and upload to TestFlight from
CI, with no Mac in the loop.

**Status: unproven.** The workflow is written and its configuration validated,
but it has never produced a build — it's blocked on the Apple-side
prerequisites below. Treat it as ready to try, not as known-good.

---

## What you need first

All Apple-side, none of it automatable.

1. **Apple Developer Program membership**, $99/yr. `docs/APP_STORE.md` §1 walks
   through enrolment. A free Personal Team can install on your own phone but
   cannot ship to TestFlight.
2. **A real bundle identifier.** The repo ships the placeholder
   `com.example.worldtracker` and keeps shipping it — see
   [Bundle identifier](#bundle-identifier).
3. **An App Store Connect API key.** App Store Connect → Users and Access →
   Integrations → App Store Connect API → generate a key with the **App
   Manager** role. You get a one-time `.p8` download plus a **Key ID** and an
   **Issuer ID**. The `.p8` cannot be re-downloaded.
4. **An app record** in App Store Connect (`docs/APP_STORE.md` §3), and the App
   Group `group.<your-bundle-id>` enabled on both the app and the `.widgets`
   App IDs.

> **Never commit the `.p8`, Key ID, Issuer ID, or Team ID.** This repository is
> public. They belong in GitHub Actions secrets only.

### Bundle identifier

Been There derives every identifier from one build setting, `APP_BUNDLE_ID`
(`WorldTracker.xcodeproj/project.pbxproj`). The widget becomes
`$(APP_BUNDLE_ID).widgets` and both entitlements interpolate
`group.$(APP_BUNDLE_ID)`, so there is exactly one value to change —
`Tools/validate_project.py` enforces that it stays that way.

The release workflow reads it from the repository *variable* `APP_BUNDLE_ID` and
passes it to `xcodebuild` on the command line, so the real identifier never has
to be committed to a public repo.

---

## The pipeline

`.github/workflows/testflight.yml`, running on `macos-15`. It sits alongside
`ios-build.yml`, which stays the fast unsigned PR gate and is left untouched.

**Why this is shorter than most iOS CI recipes:** since Xcode 13, `xcodebuild`
accepts an App Store Connect API key directly. Passing
`-allowProvisioningUpdates` alongside `-authenticationKeyPath` /
`-authenticationKeyID` / `-authenticationKeyIssuerID` lets Xcode create the
distribution certificate and **both** provisioning profiles — app and widget
extension — on the runner. No fastlane match, no `.p12`, no keychain import, no
certificate rotation chore.

### Setup

Repository → Settings → Secrets and variables → Actions:

| Kind | Name | Value |
| --- | --- | --- |
| Secret | `ASC_PRIVATE_KEY` | Full contents of the `.p8`, including the BEGIN/END lines |
| Secret | `ASC_KEY_ID` | Key ID from App Store Connect |
| Secret | `ASC_ISSUER_ID` | Issuer ID from App Store Connect |
| Secret | `APPLE_TEAM_ID` | 10-character Team ID from developer.apple.com |
| Variable | `APP_BUNDLE_ID` | e.g. `com.rohitdivate.beenthere` |

The workflow preflights all of these and fails with a named list rather than
dying deep inside `xcodebuild`.

### Running it

Actions → **testflight** → Run workflow. **Untick *submit* for the first run** —
that archives and exports but uploads nothing, which is the cheap way to shake
out signing problems. Pushing a `v*` tag runs a full release including upload.

The `.ipa` and `.xcarchive` are uploaded as workflow artifacts before the
submission step, so a rejected binary doesn't cost another archive.

### Versioning

The build number comes from `github.run_number`, injected as
`CURRENT_PROJECT_VERSION`. It's never committed: TestFlight rejects duplicate
build numbers, and this keeps the pbxproj clean while guaranteeing uniqueness.
`MARKETING_VERSION` stays committed and hand-bumped for real version changes.

### Cost

Nothing. This repo is public, so GitHub-hosted macOS runners are free.

---

## Getting a build onto your phone

Three routes, and it's worth being clear about what each can and can't do.
**Nothing installs an app on an iPhone from the cloud** — iOS has no remote
install path. Only TestFlight comes close, and it needs the paid programme.

### Over Wi-Fi from your Mac — works today, no paid account

`Tools/deploy_to_phone.sh` builds and installs to a network-paired iPhone with
no cable:

```bash
Tools/deploy_to_phone.sh            # build, install, launch
Tools/deploy_to_phone.sh --watch    # redeploy whenever the branch moves
```

One-time setup needs the cable exactly once: plug in, unlock, Trust, then
Xcode → Window → Devices and Simulators (⇧⌘2) → select the phone → tick
**Connect via network**. Once the globe icon appears, unplug — from then on
it's Wi-Fi, provided the Mac and phone share a network and the phone is awake
and unlocked.

Uses `xcrun devicectl` (Xcode 15+, iOS 17+). A free Personal Team works; the
app just stops launching after 7 days.

`--watch` polls the upstream branch and redeploys on every new commit, which is
the closest thing to "install on merge" that doesn't involve Apple — but it
needs this Mac awake. It cannot run in CI: installing to a physical device
requires a device paired to that machine, and a hosted runner has none.

### On merge, via TestFlight — needs the paid programme

`testflight.yml` fires on every push to the default branch, so a merged PR
becomes a TestFlight build with nobody pressing anything. Turn on **Automatic
Updates** in the TestFlight app on your phone and new builds install
themselves, roughly 10–15 minutes after the merge (Apple's processing time).

That is genuinely hands-off, and it's the only route that works with no Mac
involved at all.

Automatic runs are gated on the `APP_BUNDLE_ID` repository variable being set,
so merges don't turn the repo red before release is configured. A manual
**Run workflow** always runs and fails loudly in preflight if something's
missing — you asked for it explicitly, so silence would be worse.

### By cable from Xcode

The README path. Press ▶. Fine for one-offs, but there's no reason to keep
using it once wireless pairing is set up.

## Expected first failure

**App Group provisioning.** It's the classic headless-iOS-signing wall. If
signing fails on `group.<bundle-id>`, register the group manually at
developer.apple.com → Identifiers → App Groups, enable it on both App IDs, and
re-run. `-allowProvisioningUpdates` handles most capabilities unattended but is
less reliable for App Groups specifically.

Second most likely: `xcrun altool --upload-app` is soft-deprecated in favour of
`--upload-package`. It still works, and `--upload-package` needs the app
record's numeric Apple ID plus explicit bundle/version flags — switch once that
number exists if the deprecation ever turns into removal.

---

## Why not Expo / EAS

Worth recording, since the question started here and the EAS project
`6b375751-24ae-4a1d-828c-b2bac2ff718d` still exists.

EAS Build genuinely does support non-React-Native projects, and a working
scaffold for it was built and then removed. It lost on:

- **Dependency surface.** The one required `expo` dependency resolves to **481
  npm packages**, including a React Native debugger frontend. None of it ships
  in the app, but a project whose entire pitch is *no accounts, no servers, no
  analytics* would carry that tree in its build path and re-review it on every
  PR.
- **Scaffolding.** It needs `package.json`, `app.json`, `eas.json` and
  `.eas/build/*.yml` in a repo with no JavaScript, plus a `ln -sf . ios`
  symlink because EAS expects the Xcode project under `ios/`. The bundle id
  also has to be committed, in two places.
- **Cost.** Free for 15 iOS builds/month, then $19+/month. GitHub Actions is
  free at any volume here.
- **Fit.** Expo's own homepage lists "your app is exclusively native Swift or
  Kotlin with no cross-platform requirement" among the cases where alternatives
  make more sense.

The one thing EAS did better: it detects app extensions from the Xcode project
and generates credentials per target automatically. If
`-allowProvisioningUpdates` turns out to fight the widget's separate bundle id,
that's the reason to reconsider — `git log` has the removed scaffold.

A hybrid also remains available without any of the above: build in GitHub
Actions and upload with `eas submit --path`, which [accepts any correctly-signed
`.ipa`](https://docs.expo.dev/submit/ios/).
