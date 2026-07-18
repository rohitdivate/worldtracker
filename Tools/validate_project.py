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
    if n_targets != 1:
        err(f"pbxproj: expected exactly 1 native target, found {n_targets}")

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
    check_assets()
    if errors:
        for e in errors:
            print(f"FAIL: {e}")
        sys.exit(1)
    print("validate_project: all checks passed")


if __name__ == "__main__":
    main()
