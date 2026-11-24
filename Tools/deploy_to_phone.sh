#!/usr/bin/env bash
# Build and install Been There onto a network-paired iPhone — no cable.
#
#   Tools/deploy_to_phone.sh              # build + install + launch, once
#   Tools/deploy_to_phone.sh --watch      # same, every time the branch moves
#   Tools/deploy_to_phone.sh --device ID  # pick a specific device
#
# WORKS OVER CABLE TOO. devicectl doesn't care about the transport, so if
# wireless is being difficult just leave the phone plugged in — everything
# below still applies.
#
# ONE-TIME WIRELESS SETUP (needs the cable exactly once):
#   1. Plug the iPhone in, unlock, Trust, let Xcode finish "Preparing device".
#   2. Unplug, then check:  xcrun devicectl list devices
#      If the phone is still listed, wireless is working — you're done.
#
# Note step 2 does NOT mention ticking "Connect via network" in Xcode. Since
# iOS 17/Xcode 15 that checkbox is frequently greyed out while wireless works
# anyway; it's a known Apple bug, not a prerequisite. Trust the devicectl
# listing, not the checkbox.
#
# If the phone ISN'T listed after unplugging, iOS 17+ discovery is mDNS on TCP
# 49152 and link-local, so the usual culprits are: Mac and phone on different
# networks (Ethernet vs Wi-Fi counts), a VPN on either device, router client
# isolation or disabled Wi-Fi multicast, or the macOS firewall in stealth mode.
#
# Requires Xcode 15+ and iOS 17+ (this is the devicectl flow). A free Personal
# Team is fine — the app just expires after 7 days.
#
# This runs on YOUR Mac. It cannot run in CI: installing to a physical device
# needs a device paired to that machine, which a hosted runner has no way to
# be. For no-Mac-at-all delivery, that's TestFlight — see docs/RELEASE.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="WorldTracker"
PROJECT="WorldTracker.xcodeproj"
CONFIG="Debug"
BUILD_DIR="$ROOT/build/device"
DEVICE=""
WATCH=0
POLL_SECONDS="${POLL_SECONDS:-60}"

while [ $# -gt 0 ]; do
  case "$1" in
    --device) DEVICE="${2:-}"; shift 2 ;;
    --watch)  WATCH=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

command -v xcodebuild >/dev/null || die "xcodebuild not found — install Xcode."
xcrun devicectl --version >/dev/null 2>&1 \
  || die "xcrun devicectl unavailable — needs Xcode 15 or newer."

# Pick the device. With one paired phone this needs no argument; with several,
# pass --device (it accepts an identifier or the phone's name).
#
# Parsed from --json-output rather than the printed table: the table's columns
# shift between Xcode versions, and this is the step most likely to be run on a
# machine whose Xcode is newer than the one this was written against.
resolve_device() {
  [ -n "$DEVICE" ] && { echo "$DEVICE"; return; }

  local json found
  json="$(mktemp -t devicectl)"
  trap 'rm -f "$json"' RETURN
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || true

  if [ -s "$json" ]; then
    found=$(/usr/bin/python3 - "$json" <<'PY' 2>/dev/null || true
import json, sys

devices = json.load(open(sys.argv[1])).get("result", {}).get("devices", [])

def is_iphone(d):
    # MUST filter by platform. A paired Apple Watch often reports a healthier
    # connection state than a sleeping iPhone, so ranking on state alone can
    # hand you the watch — and then devicectl tries to install an iOS app on
    # watchOS.
    hw = d.get("hardwareProperties") or {}
    if hw.get("platform") == "iOS":
        return True
    return str(hw.get("productType", "")).startswith("iPhone")

def state(d):
    return ((d.get("connectionProperties") or {}).get("tunnelState") or "").lower()

phones = [d for d in devices if is_iphone(d)]
ready = [d for d in phones if state(d) == "connected"]
chosen = (ready or phones)
if chosen:
    d = chosen[0]
    props = d.get("deviceProperties") or {}
    # Three lines: identifier, name, state — the caller warns on a bad state.
    print(d.get("identifier", ""))
    print(props.get("name") or "device")
    print(state(d) or "unknown")
PY
    )
  fi

  [ -n "${found:-}" ] || die "no iPhone found.
  Check with: xcrun devicectl list devices

  If a Watch or iPad is listed but no iPhone, the phone has never been paired
  with this Mac — connect it once by cable and tap Trust."

  local udid name devstate
  udid=$(printf '%s\n' "$found" | sed -n 1p)
  name=$(printf '%s\n' "$found" | sed -n 2p)
  devstate=$(printf '%s\n' "$found" | sed -n 3p)

  if [ "$devstate" != "connected" ]; then
    # Not fatal: devicectl's own error is clearer than anything guessed here,
    # and the state vocabulary shifts between Xcode releases.
    echo "warning: '$name' is paired but reports state '$devstate'." >&2
    echo "         Plug it in, or unlock it and put both on the same Wi-Fi." >&2
  else
    echo "== using $name" >&2
  fi
  echo "$udid"
}

# Read the bundle id out of the build settings rather than hardcoding it —
# APP_BUNDLE_ID is a project setting the user is expected to change.
bundle_id() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ PRODUCT_BUNDLE_IDENTIFIER = /{print $2; exit}' \
    | tr -d '[:space:]'
}

deploy() {
  local udid="$1"
  echo "== building for $udid"
  # -allowProvisioningUpdates lets Xcode refresh the development profile
  # unattended, the same mechanism the TestFlight workflow uses.
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "id=$udid" \
    -derivedDataPath "$BUILD_DIR" \
    -allowProvisioningUpdates \
    build

  local app
  app="$BUILD_DIR/Build/Products/$CONFIG-iphoneos/$SCHEME.app"
  [ -d "$app" ] || die "built app not found at $app"

  echo "== installing over the network"
  xcrun devicectl device install app --device "$udid" "$app"

  local bid
  bid="$(bundle_id)"
  if [ -n "$bid" ]; then
    echo "== launching $bid"
    # Non-fatal: the install is the deliverable, and launch can fail simply
    # because the phone locked itself while building.
    xcrun devicectl device process launch \
      --terminate-existing --device "$udid" "$bid" \
      || echo "   (launch failed — the app is installed; open it by hand)"
  fi
  echo "== done"
}

UDID="$(resolve_device)"

if [ "$WATCH" -eq 0 ]; then
  deploy "$UDID"
  exit 0
fi

# Watch mode: poll the tracking branch and redeploy whenever it moves. This is
# what makes "every time I merge" work without a Mac in the cloud — it just
# needs this Mac awake and on the same network as the phone.
branch="$(git rev-parse --abbrev-ref HEAD)"
upstream="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
[ -n "$upstream" ] || die "branch '$branch' has no upstream; git push -u origin $branch first."

echo "== watching $upstream every ${POLL_SECONDS}s (ctrl-C to stop)"
last="$(git rev-parse HEAD)"
while true; do
  # Never let a flaky network kill the loop.
  git fetch --quiet origin "$branch" 2>/dev/null || true
  remote="$(git rev-parse "$upstream" 2>/dev/null || echo "$last")"
  if [ "$remote" != "$last" ]; then
    echo "== $upstream moved: ${last:0:7} → ${remote:0:7}"
    git merge --ff-only "$upstream" || die "cannot fast-forward — resolve by hand."
    deploy "$UDID" || echo "== deploy failed; still watching"
    last="$remote"
  fi
  sleep "$POLL_SECONDS"
done
