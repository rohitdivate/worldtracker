# Been There 🌍

A free, private travel tracker for iPhone. It quietly notices which country and
city you're in, reconstructs your past travels from your photo library's
location data, and shows your life as a calendar of flags, a lit-up globe, and
the places (museums, parks, cafés) you've actually visited.

**Privacy first:** no accounts, no servers, no analytics. Your data lives on
your phone (and optionally your own private iCloud).

> This repo is built to be opened by a first-time Xcode user. Follow the steps
> below top-to-bottom and you'll have the app on your iPhone in ~20 minutes
> (plus Xcode's download time).

---

## 1. What you need

- A Mac running macOS 15 or newer
- **Xcode 16 or newer** — install free from the Mac App Store (it's a big
  download, start it first)
- An iPhone running iOS 18 or newer + a USB cable (first install is easiest
  over cable)
- An [Apple Developer Program](https://developer.apple.com/programs/) account
  ($99/yr). A free Apple ID also works for trying it out, but apps installed
  with a free account stop launching after 7 days — bad for an always-on
  tracker.

## 2. Get the code

Open **Terminal** (press ⌘-Space, type "Terminal") and run:

```bash
cd ~/projects
git clone https://github.com/rohitdivate/worldtracker.git
```

(Or use GitHub Desktop and clone `rohitdivate/worldtracker`.)

## 3. Open the project

Double-click **`WorldTracker.xcodeproj`** in the `worldtracker` folder.
Xcode opens. Give it a minute the first time — it indexes the project and
resolves the built-in `WorldTrackerKit` package.

## 4. Signing — the only setup step

1. In the left sidebar, click the blue **WorldTracker** icon at the very top.
2. In the middle pane select the **WorldTracker** target, then the
   **Signing & Capabilities** tab.
3. Tick **Automatically manage signing** and pick your **Team** (your Apple ID
   — add it via Xcode → Settings → Accounts if the menu is empty). Do the
   same for the **BeenThereWidgets** target.
4. Set your bundle identifier **in one place**: select the blue project icon
   (not a target) → **Build Settings** tab → type `APP_BUNDLE_ID` in the
   search box → change `com.example.worldtracker` to something unique to
   you, e.g. `com.rohitdivate.beenthere`.
   Both targets follow automatically (the widget becomes
   `<yours>.widgets`) — don't edit the per-target Bundle Identifier fields,
   they're wired to this one setting.
   (Bundle IDs are globally unique across the App Store — the example one is a
   placeholder on purpose.)

## 5. Put it on your iPhone

1. Plug in your iPhone, unlock it, and tap **Trust** if asked.
2. On the iPhone, enable **Developer Mode**: Settings → Privacy & Security →
   Developer Mode → on → restart. (If you don't see it, Xcode will prompt you
   the first time you press Run.)
3. In Xcode's toolbar, click the device menu (next to the scheme name that
   says "WorldTracker") and select **your iPhone** (not a simulator).
4. Press the **▶ Run** button. The first build takes a few minutes.
5. If iOS refuses to open the app: Settings → General → VPN & Device
   Management → tap your developer certificate → **Trust**.

You should see the Been There night-sky app with five tabs. 🎉

## 6. Updating to the latest version

```bash
cd ~/projects/worldtracker
git pull
```

Then press ▶ in Xcode again. With a paid developer account the app stays
valid on your phone for ~1 year per install.

## 7. Enabling iCloud backup (optional)

> Requires the paid Apple Developer Program — free Personal Teams can't sign
> iCloud or push entitlements, which is why the project ships without them.
> Everything else works on a free team.

The in-app "iCloud backup" toggle needs two capabilities added once in Xcode:

1. Select the WorldTracker target → **Signing & Capabilities** → **+ Capability**
   → **iCloud** → tick **CloudKit**. Xcode creates the container
   (`iCloud.<your bundle id>`) automatically.
2. **+ Capability** → **Background Modes** → tick **Remote notifications**
   (already in the Info.plist; adding the capability makes signing aware).
3. Make sure your iPhone is signed into iCloud, run the app, flip
   Settings → iCloud backup ON, and relaunch the app once.

Everything syncs to your personal private CloudKit database — invisible to
everyone but your Apple account.

## 8. Enabling home-screen widgets (optional)

The widgets read a tiny snapshot the app shares through an **App Group** —
one capability, added to both targets:

1. Select the **WorldTracker** target → **Signing & Capabilities** →
   **+ Capability** → **App Groups** → **+** → it should offer
   `group.<your bundle id>` — accept it.
2. Select the **BeenThereWidgets** target and repeat — tick the **same**
   `group.<your bundle id>`.
3. Run the app once, then long-press your home screen → **Edit** → **Add
   Widget** → search "Been There".

Without the capability the app still works fine — the widget just shows its
"open the app once" placeholder.

## 9. Troubleshooting

| Problem | Fix |
| --- | --- |
| "Failed to register bundle identifier" | Step 4.4 — set your own APP_BUNDLE_ID |
| "Untrusted Developer" on iPhone | Step 5.5 — trust your certificate |
| "Developer Mode required" | Step 5.2 |
| "Could not launch — the device is locked" | Unlock the phone, run again |
| Red errors after `git pull` | Xcode menu: Product → Clean Build Folder, then ▶ |
| Device missing from device menu | Reconnect cable, unlock phone, wait 10s |

## Project layout

```
WorldTracker.xcodeproj    the Xcode project (open this)
WorldTracker/             app source (SwiftUI, iOS 18+)
BeenThereWidgets/         home-screen widget extension source
WorldTrackerKit/          pure-logic Swift package (geocoding, day math) + tests
Config/                   Info.plists & entitlements (both targets)
Tools/                    build/validation scripts (run Tools/check.sh)
docs/                     architecture, setup, per-milestone verification
```

## Docs

- [docs/SETUP_MAC.md](docs/SETUP_MAC.md) — long-form setup with more detail
- [docs/VERIFICATION.md](docs/VERIFICATION.md) — what to test on your iPhone
  after each milestone
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the app works inside
- [docs/PRIVACY.md](docs/PRIVACY.md) — the privacy promises, spelled out
