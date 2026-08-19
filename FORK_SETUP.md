# Personal Team test setup

This branch is the device-test variant of the clipboard-first SnipKey fork. It keeps the shared App Group store used by the app and keyboard, but disables CloudKit so the first on-device test does not depend on iCloud provisioning.

## 1. Update your local checkout

If you already cloned the repository:

```bash
cd SnipKey
git fetch origin
git switch dev/personal-team-test
git pull
```

If Xcode has modified `SnipKey.xcodeproj/project.pbxproj` because you selected your Personal Team, keep that change. The setup script below deliberately preserves your current Team selection.

## 2. Configure unique identifiers

Run:

```bash
python3 configure_fork.py --bundle-id com.tues8557.clipboardkeyboard
```

You do **not** need to know your Team ID for this branch. The script changes the identifiers while preserving whichever Team you selected in Xcode.

It configures:

- App bundle ID: `com.tues8557.clipboardkeyboard`
- Keyboard bundle ID: `com.tues8557.clipboardkeyboard.keyboard`
- App Group: `group.com.tues8557.clipboardkeyboard`
- CloudKit: disabled for this test branch

If that bundle ID is unexpectedly unavailable, rerun the script with a more unique value, for example:

```bash
python3 configure_fork.py --bundle-id com.tues8557.jaeho.clipboardkeyboard
```

## 3. Xcode signing

Open `SnipKey.xcodeproj`.

For **both** targets on the left — `SnipKey` and `SnipKeyboard`:

1. Open **Signing & Capabilities**.
2. Enable **Automatically manage signing**.
3. Select your `Personal Team` in **Team**.
4. Confirm the bundle IDs match the values printed by the setup script.
5. Confirm both targets use the same App Group (`group.<bundle-id>`).

The local test branch intentionally has no iCloud/CloudKit entitlement. The upstream In-App Purchase/CloudKit functionality is not required for the clipboard keyboard test.

## 4. Build on a physical iPhone or iPad

Connect the device to the Mac, select it as the Xcode run destination, select the **SnipKey** scheme, then press Run.

After installation, enable the keyboard on the device:

**Settings → General → Keyboard → Keyboards → Add New Keyboard**

Choose the SnipKey/Shortcuts keyboard. Enable **Allow Full Access** for this personal build so the extension can access the shared App Group store and respond to the explicit **Save Clipboard** action.

## 5. What to test

In the main app:

- create a text snippet
- edit its title/content
- favorite/unfavorite it

Then switch to the custom keyboard in Notes or another normal text field and verify:

- the saved snippet appears
- tapping it inserts its text
- favorites filter works
- **Save Clipboard** stores copied text
- duplicate clipboard text is not added twice
- globe, left/right cursor, space, delete, and return work

Because CloudKit is disabled on this branch, this stage validates **one-device app ↔ keyboard sharing only**. iPhone ↔ iPad iCloud synchronization will be re-enabled on the paid/iCloud branch after the local keyboard behavior is confirmed.

## 6. Moving back to the iCloud build later

The original clipboard development branch remains available as:

```bash
git switch dev/clipboard-keyboard
```

That branch retains the CloudKit architecture. Do not merge `dev/personal-team-test` over it until device testing is complete; keeping the branches separate makes the Personal Team workaround easy to discard later.
