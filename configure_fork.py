#!/usr/bin/env python3
"""Configure this SnipKey fork for personal-device testing.

Personal Team example (recommended on this branch):
    python3 configure_fork.py --bundle-id com.tues8557.clipboardkeyboard

Paid Developer Program example, if you later want to force a Team ID:
    python3 configure_fork.py \
        --bundle-id com.tues8557.clipboardkeyboard \
        --team-id ABCDE12345

The script does not contact Apple or create certificates. When --team-id is omitted,
it deliberately preserves whatever Team is currently selected in Xcode. This makes it
safe to select "<name> (Personal Team)" in Xcode first and run this script afterwards.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT_FILE = ROOT / "SnipKey.xcodeproj" / "project.pbxproj"
APP_ENTITLEMENTS = ROOT / "SnipKey" / "SnipKey.entitlements"
KEYBOARD_ENTITLEMENTS = ROOT / "SnipKeyboard" / "SnipKeyboard.entitlements"
DATA_MANAGER = ROOT / "SnipKey" / "SnipKeyDataManager.swift"
SETTINGS_MODEL = ROOT / "SnipKey" / "Features" / "Settings" / "Model" / "SettingsModel.swift"

FILES = [
    PROJECT_FILE,
    APP_ENTITLEMENTS,
    KEYBOARD_ENTITLEMENTS,
    DATA_MANAGER,
    SETTINGS_MODEL,
]

# Values used by the upstream project and by the first clipboard-fork iteration.
KNOWN_APP_BUNDLE_IDS = [
    "jrtv-projects.SnipKey",
    "com.tues8557.clipboardkeyboard",
]
KNOWN_KEYBOARD_BUNDLE_IDS = [
    "jrtv-projects.SnipKey.SnipKeyboard",
    "com.tues8557.clipboardkeyboard.keyboard",
]
KNOWN_APP_GROUPS = [
    "group.snipkey",
    "group.com.tues8557.clipboardkeyboard",
]
KNOWN_ICLOUD_CONTAINERS = [
    "iCloud.SnipKeyCloud",
    "iCloud.com.tues8557.clipboardkeyboard",
]


def replace_known_values(text: str, values: list[str], replacement: str) -> str:
    # Longest first avoids a shorter app bundle ID consuming the keyboard ID prefix.
    for value in sorted(set(values), key=len, reverse=True):
        text = text.replace(value, replacement)
    return text


def update_text_file(path: Path, transform) -> bool:
    original = path.read_text(encoding="utf-8")
    updated = transform(original)
    if updated == original:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Configure bundle/App Group identifiers for the SnipKey clipboard fork."
    )
    parser.add_argument(
        "--bundle-id",
        required=True,
        help="Unique reverse-DNS app bundle identifier, e.g. com.tues8557.clipboardkeyboard",
    )
    parser.add_argument(
        "--team-id",
        required=False,
        help=(
            "Optional Apple Developer Team ID. Omit this for a Personal Team after selecting "
            "the team in Xcode; the currently selected team will be preserved."
        ),
    )
    args = parser.parse_args()

    bundle_id = args.bundle_id.strip().strip(".")
    team_id = args.team_id.strip() if args.team_id else None

    if not bundle_id or "." not in bundle_id or " " in bundle_id:
        parser.error("Provide a valid reverse-DNS bundle identifier.")
    if team_id is not None and not re.fullmatch(r"[A-Z0-9]+", team_id):
        parser.error("Team ID should contain only uppercase letters and digits.")

    keyboard_bundle_id = f"{bundle_id}.keyboard"
    app_group = f"group.{bundle_id}"
    icloud_container = f"iCloud.{bundle_id}"

    def common_transform(text: str) -> str:
        # Replace the keyboard identifier first because it contains the app identifier.
        text = replace_known_values(text, KNOWN_KEYBOARD_BUNDLE_IDS, keyboard_bundle_id)
        text = replace_known_values(text, KNOWN_APP_BUNDLE_IDS, bundle_id)
        text = replace_known_values(text, KNOWN_APP_GROUPS, app_group)
        text = replace_known_values(text, KNOWN_ICLOUD_CONTAINERS, icloud_container)
        return text

    changed: list[Path] = []
    for path in FILES:
        if not path.exists():
            raise SystemExit(f"Missing expected project file: {path.relative_to(ROOT)}")
        if update_text_file(path, common_transform):
            changed.append(path)

    if team_id:
        def team_transform(text: str) -> str:
            # Change only explicit DEVELOPMENT_TEAM assignments. Project-level Team selection
            # remains untouched when --team-id is omitted.
            return re.sub(
                r"DEVELOPMENT_TEAM\s*=\s*[A-Z0-9]*;",
                f"DEVELOPMENT_TEAM = {team_id};",
                text,
            )

        if update_text_file(PROJECT_FILE, team_transform) and PROJECT_FILE not in changed:
            changed.append(PROJECT_FILE)

    print("\nConfigured identifiers:\n")
    print(f"  App bundle ID     : {bundle_id}")
    print(f"  Keyboard bundle ID: {keyboard_bundle_id}")
    print(f"  App Group         : {app_group}")
    print("  iCloud            : disabled on dev/personal-team-test")
    print(f"  Future iCloud ID  : {icloud_container}")
    if team_id:
        print(f"  Team ID           : {team_id}")
    else:
        print("  Team ID           : preserved from Xcode")

    if changed:
        print("\nUpdated files:")
        for path in changed:
            print(f"  - {path.relative_to(ROOT)}")
    else:
        print("\nNo identifier changes were needed.")

    print(
        "\nNext: open SnipKey.xcodeproj, select your Personal Team for BOTH SnipKey and "
        "SnipKeyboard, keep Automatically manage signing enabled, and verify both targets "
        f"show the App Group {app_group}. CloudKit is intentionally disabled on this branch."
    )


if __name__ == "__main__":
    main()
