#!/usr/bin/env python3
"""Sanity checks for the hand-authored Xcode project.

Not a full pbxproj parser — a fast smoke gate run before every commit.
The authoritative compile check is the macOS GitHub Actions job.
"""
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PBX = os.path.join(ROOT, "WorldTracker.xcodeproj", "project.pbxproj")

errors = []


def err(msg):
    errors.append(msg)


def check_pbxproj():
    with open(PBX, encoding="utf-8") as f:
        text = f.read()

    if not text.startswith("// !$*UTF8*$!"):
        err("pbxproj: missing UTF8 header")
    if "objectVersion = 77;" not in text:
        err("pbxproj: objectVersion must be 77 (Xcode 16 format)")
    if text.count("{") != text.count("}"):
        err(f"pbxproj: unbalanced braces {text.count('{')} vs {text.count('}')}")
    if text.count("(") != text.count(")"):
        err("pbxproj: unbalanced parens")

    n_targets = len(re.findall(r"isa = PBXNativeTarget;", text))
    if n_targets != 2:
        err(f"pbxproj: expected exactly 2 native targets (app + widgets), found {n_targets}")

    # --- Two-target invariants (app + widget extension) ---
    if 'productType = "com.apple.product-type.app-extension"' not in text:
        err("pbxproj: widget target must be product type app-extension")
    if "BeenThereWidgets.appex in Embed Foundation Extensions" not in text:
        err("pbxproj: appex not embedded in the app's Embed Foundation Extensions phase")
    if "dstSubfolderSpec = 13;" not in text:
        err("pbxproj: embed phase must copy into PlugIns (dstSubfolderSpec 13)")
    if len(re.findall(r"APP_BUNDLE_ID = ", text)) < 2:
        err("pbxproj: APP_BUNDLE_ID must be defined in both project-level configs")
    if text.count('PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID)";') != 2:
        err("pbxproj: app target must use $(APP_BUNDLE_ID) in both configs")
    if text.count('PRODUCT_BUNDLE_IDENTIFIER = "$(APP_BUNDLE_ID).widgets";') != 2:
        err("pbxproj: widget target must use $(APP_BUNDLE_ID).widgets in both configs")
    if "isa = PBXTargetDependency;" not in text:
        err("pbxproj: app target must depend on the widget target")

    root_match = re.search(r"rootObject = ([0-9A-F]{24})", text)
    if not root_match:
        err("pbxproj: no rootObject")
    elif root_match.group(1) not in text.replace(f"rootObject = {root_match.group(1)}", ""):
        err("pbxproj: rootObject id not defined")

    # Every synchronized folder must exist on disk.
    for m in re.finditer(
        r"isa = PBXFileSystemSynchronizedRootGroup;.*?path = ([A-Za-z0-9_./\"]+);",
        text,
        re.S,
    ):
        path = m.group(1).strip('"')
        if not os.path.isdir(os.path.join(ROOT, path)):
            err(f"pbxproj: synchronized group path missing on disk: {path}")

    # Build-setting file references must exist.
    for key in ("INFOPLIST_FILE", "CODE_SIGN_ENTITLEMENTS"):
        for m in re.finditer(rf"(?<![A-Z_]){key} = ([^;]+);", text):
            path = m.group(1).strip().strip('"')
            if not os.path.isfile(os.path.join(ROOT, path)):
                err(f"pbxproj: {key} points to missing file: {path}")

    # Local package reference must exist.
    for m in re.finditer(r"relativePath = ([^;]+);", text):
        path = m.group(1).strip().strip('"')
        if not os.path.isdir(os.path.join(ROOT, path)):
            err(f"pbxproj: local package path missing: {path}")

    # All object ids referenced in lists should be defined somewhere.
    defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", text, re.M))
    referenced = set(re.findall(r"([0-9A-F]{24})", text))
    undefined = referenced - defined
    if undefined:
        err(f"pbxproj: referenced-but-undefined object ids: {sorted(undefined)[:5]}")


def check_scheme():
    schemes = glob.glob(
        os.path.join(ROOT, "WorldTracker.xcodeproj", "xcshareddata", "xcschemes", "*.xcscheme")
    )
    if not schemes:
        err("no shared scheme committed")
    for s in schemes:
        try:
            ET.parse(s)
        except ET.ParseError as e:
            err(f"scheme {os.path.basename(s)} is not valid XML: {e}")


def check_plists():
    plist = os.path.join(ROOT, "Config", "Info.plist")
    if not os.path.isfile(plist):
        err("Config/Info.plist missing")
    else:
        try:
            ET.parse(plist)
        except ET.ParseError as e:
            err(f"Info.plist invalid XML: {e}")
        with open(plist, encoding="utf-8") as f:
            body = f.read()
        for key in (
            "NSLocationWhenInUseUsageDescription",
            "NSLocationAlwaysAndWhenInUseUsageDescription",
            "NSPhotoLibraryUsageDescription",
        ):
            if key not in body:
                err(f"Info.plist missing {key}")

    widget_plist = os.path.join(ROOT, "Config", "WidgetInfo.plist")
    if not os.path.isfile(widget_plist):
        err("Config/WidgetInfo.plist missing")
    else:
        try:
            ET.parse(widget_plist)
        except ET.ParseError as e:
            err(f"WidgetInfo.plist invalid XML: {e}")
        with open(widget_plist, encoding="utf-8") as f:
            if "com.apple.widgetkit-extension" not in f.read():
                err("WidgetInfo.plist missing widgetkit NSExtensionPointIdentifier")

    # Both entitlements must share the same App Group.
    for name in ("WorldTracker.entitlements", "BeenThereWidgets.entitlements"):
        path = os.path.join(ROOT, "Config", name)
        if not os.path.isfile(path):
            err(f"Config/{name} missing")
            continue
        with open(path, encoding="utf-8") as f:
            if "group.$(APP_BUNDLE_ID)" not in f.read():
                err(f"{name} missing the group.$(APP_BUNDLE_ID) App Group")

    # The two Codable snapshot shapes must stay field-for-field in sync.
    app_side = os.path.join(ROOT, "WorldTracker", "Services", "Widgets", "SharedSnapshot.swift")
    widget_side = os.path.join(ROOT, "BeenThereWidgets", "WidgetSnapshot.swift")
    if os.path.isfile(app_side) and os.path.isfile(widget_side):
        def snapshot_fields(path):
            with open(path, encoding="utf-8") as f:
                text = f.read()
            # Only the snapshot struct itself — the files also hold
            # readers/providers whose fields are not part of the contract.
            m = re.search(r"struct (?:Shared|Widget)Snapshot: Codable \{(.*?)\n\}", text, re.S)
            body = m.group(1) if m else ""
            return re.findall(r"^\s+(?:var|let) (\w+):", body, re.M)
        app_fields = snapshot_fields(app_side)[:20]
        widget_fields = snapshot_fields(widget_side)[:20]
        if app_fields != widget_fields:
            err(
                "SharedSnapshot/WidgetSnapshot field mismatch: "
                f"app={app_fields} widget={widget_fields}"
            )


def check_themes():
    """Themes span three files in two targets — keep them in step.

    The Kit owns the palette data; the app and widget each map it to SwiftUI
    colours. A token added to one target but not the other compiles fine and
    only shows up as an unthemed surface on device, so check it here.
    """
    palettes = os.path.join(
        ROOT, "WorldTrackerKit", "Sources", "WorldTrackerKit", "Design", "ThemePalettes.swift"
    )
    if not os.path.isfile(palettes):
        err("WorldTrackerKit Design/ThemePalettes.swift missing")
        return
    with open(palettes, encoding="utf-8") as f:
        kit = f.read()

    cases = re.findall(r"^\s{4}case (\w+)$", kit, re.M)
    if len(cases) < 2:
        err(f"ThemePalettes: expected at least 2 ThemeID cases, found {cases}")

    # Every case needs a `static let <case> = ThemePalette(` definition and a
    # branch in palette(for:) — a missing one is a crash or a silent fallback.
    for case in cases:
        if case in ("standard", "rounded", "serif", "monospaced"):
            continue  # FontDesignToken cases, not themes
        if f"static let {case} = ThemePalette(" not in kit:
            err(f"ThemePalettes: ThemeID.{case} has no palette definition")
        if f"case .{case}:" not in kit:
            err(f"ThemePalettes: ThemeID.{case} missing from palette(for:)")

    # Tokens declared on ThemePalette must be surfaced by both targets, or one
    # of them silently keeps a stale hardcoded value.
    struct = re.search(r"public struct ThemePalette: Sendable \{(.*?)\n\}", kit, re.S)
    tokens = set(re.findall(r"public let (\w+): ColorToken", struct.group(1) if struct else ""))
    if not tokens:
        err("ThemePalettes: no ColorToken properties found on ThemePalette")

    for target, path, prefix in (
        ("app", os.path.join(ROOT, "WorldTracker", "DesignSystem", "Theme.swift"), "Theme"),
        ("widget", os.path.join(ROOT, "BeenThereWidgets", "WidgetTheme.swift"), "WTheme"),
    ):
        if not os.path.isfile(path):
            err(f"{prefix}: {path} missing")
            continue
        with open(path, encoding="utf-8") as f:
            body = f.read()
        # Both must bridge Kit tokens rather than redeclaring raw colours.
        if "palette." not in body:
            err(f"{prefix} ({target}) does not read from the shared palette")
        if re.search(r"static let \w+ = Color\(red:", body):
            err(f"{prefix} ({target}) still declares hardcoded Color constants")

    # Wrapped renders a full-screen story that stays dark in every theme, so
    # its views must read Story.* (the always-dark story palette) rather than
    # Theme.*. Using Theme here is what made the light theme's Wrapped
    # unreadable: dark ink and cream cards on a story surface.
    # ShareCards.swift is deliberately excluded — it renders onto StaticAurora,
    # a themed ground, so Theme is correct there.
    story_views = ("WrappedView.swift", "WrappedPages.swift")
    for name in story_views:
        path = os.path.join(ROOT, "WorldTracker", "Features", "Wrapped", name)
        if not os.path.isfile(path):
            err(f"Wrapped: {name} missing")
            continue
        with open(path, encoding="utf-8") as f:
            body = f.read()
        stray = re.findall(r"\bTheme\.\w+", body)
        if stray:
            err(
                f"{name} uses {sorted(set(stray))} — story views must use Story.*, "
                "which stays dark on every theme"
            )

    story_theme = os.path.join(ROOT, "WorldTracker", "Features", "Wrapped", "StoryTheme.swift")
    if not os.path.isfile(story_theme):
        err("Wrapped: StoryTheme.swift missing (defines the Story tokens)")
    elif "storyPalette" not in open(story_theme, encoding="utf-8").read():
        err("StoryTheme: must resolve to the Kit's storyPalette")

    # The widget renders in its own process and can only learn the choice
    # through the App Group.
    widget_theme = os.path.join(ROOT, "BeenThereWidgets", "WidgetTheme.swift")
    if os.path.isfile(widget_theme):
        with open(widget_theme, encoding="utf-8") as f:
            if "appGroupID" not in f.read():
                err("WidgetTheme: must read the selected theme from the App Group")


def check_assets():
    for cj in glob.glob(os.path.join(ROOT, "WorldTracker", "Assets.xcassets", "**", "Contents.json"), recursive=True):
        try:
            with open(cj, encoding="utf-8") as f:
                json.load(f)
        except json.JSONDecodeError as e:
            err(f"invalid asset JSON {cj}: {e}")
    icon = os.path.join(
        ROOT, "WorldTracker", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png"
    )
    if not os.path.isfile(icon):
        err("AppIcon.png missing")


def main():
    check_pbxproj()
    check_scheme()
    check_plists()
    check_themes()
    check_assets()
    if errors:
        for e in errors:
            print(f"FAIL: {e}")
        sys.exit(1)
    print("validate_project: all checks passed")


if __name__ == "__main__":
    main()
