#!/usr/bin/env python3
"""Configure this SnipKey fork for a different Apple Developer account.

Example:
    python3 configure_fork.py \
        --team-id ABCDE12345 \
        --bundle-id com.example.clipboardkeyboard

The script intentionally changes signing identifiers only. It does not contact Apple,
create certificates, or alter source history.
"""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent

FILES = [
    ROOT / "SnipKey.xcodeproj" / "project.pbxproj",
    ROOT / "SnipKey" / "SnipKey.entitlements",
    ROOT / "SnipKeyboard" / "SnipKeyboard.entitlements",
    ROOT / "SnipKey" / "SnipKeyDataManager.swift",
    ROOT / "SnipKey" / "Features" / "Settings" / "Model" / "SettingsModel.swift",
]

OLD_TEAM_ID = "J7K9Z79S5F"
OLD_APP_BUNDLE_ID = "jrtv-projects.SnipKey"
OLD_KEYBOARD_BUNDLE_ID = "jrtv-projects.SnipKey.SnipKeyboard"
OLD_APP_GROUP = "group.snipkey"
OLD_ICLOUD_CONTAINER = "iCloud.SnipKeyCloud"


def replace_in_file(path: Path, replacements: list[tuple[str, str]]) -> bool:
    text = path.read_text(encoding="utf-8")
    updated = text
    for old, new in replacements:
        updated = updated.replace(old, new)

    if updated == text:
        return False

    path.write_text(updated, encoding="utf-8")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Configure bundle, App Group, iCloud and Team identifiers for this fork."
    )
    parser.add_argument(
        "--team-id",
        required=True,
        help="Apple Developer Team ID shown in Xcode / developer.apple.com",
    )
    parser.add_argument(
        "--bundle-id",
        required=True,
        help="Unique app bundle identifier, e.g. com.example.clipboardkeyboard",
    )
    args = parser.parse_args()

    team_id = args.team_id.strip()
    bundle_id = args.bundle_id.strip().strip(".")

    if not team_id or not bundle_id or "." not in bundle_id:
        parser.error("Provide a valid Team ID and reverse-DNS bundle identifier.")

    keyboard_bundle_id = f"{bundle_id}.keyboard"
    app_group = f"group.{bundle_id}"
    icloud_container = f"iCloud.{bundle_id}"

    # Replace the longer keyboard identifier first so the app identifier replacement
    # cannot partially consume it.
    replacements = [
        (OLD_KEYBOARD_BUNDLE_ID, keyboard_bundle_id),
        (OLD_APP_BUNDLE_ID, bundle_id),
        (OLD_APP_GROUP, app_group),
        (OLD_ICLOUD_CONTAINER, icloud_container),
        (OLD_TEAM_ID, team_id),
    ]

    changed: list[Path] = []
    for path in FILES:
        if not path.exists():
            raise SystemExit(f"Missing expected project file: {path.relative_to(ROOT)}")
        if replace_in_file(path, replacements):
            changed.append(path)

    print("\nConfigured identifiers:\n")
    print(f"  App bundle ID     : {bundle_id}")
    print(f"  Keyboard bundle ID: {keyboard_bundle_id}")
    print(f"  App Group         : {app_group}")
    print(f"  iCloud container  : {icloud_container}")
    print(f"  Team ID           : {team_id}")

    if changed:
        print("\nUpdated files:")
        for path in changed:
            print(f"  - {path.relative_to(ROOT)}")
    else:
        print("\nNo original identifiers were found. The project may already be configured.")

    print(
        "\nNext: open SnipKey.xcodeproj in Xcode, select your Team for both targets, "
        "then verify the App Groups and iCloud/CloudKit capabilities use the identifiers above."
    )


if __name__ == "__main__":
    main()
