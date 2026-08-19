# Personal fork setup

This branch turns SnipKey into a clipboard-first keyboard for iPhone and iPad. The source code is ready to use, but Apple signing identifiers from the upstream project must be replaced with identifiers owned by your Apple Developer account before installing on a device.

## 1. Clone this fork and switch to the development branch

```bash
git clone https://github.com/tues8557-source/SnipKey.git
cd SnipKey
git switch dev/clipboard-keyboard
```

## 2. Find your Apple Developer Team ID

Open Xcode → Settings → Accounts → select your Apple Account and team. Use the Team ID shown there (or the Team ID shown in your Apple Developer membership details).

## 3. Configure the fork identifiers

Choose a unique reverse-DNS bundle identifier. Example:

```bash
python3 configure_fork.py \
  --team-id ABCDE12345 \
  --bundle-id com.example.clipboardkeyboard
```

The script updates all of these together so the app and keyboard continue to share one SwiftData store:

- App bundle ID: `com.example.clipboardkeyboard`
- Keyboard bundle ID: `com.example.clipboardkeyboard.keyboard`
- App Group: `group.com.example.clipboardkeyboard`
- iCloud container: `iCloud.com.example.clipboardkeyboard`
- Xcode Team ID

Do not give the app and keyboard different App Group or iCloud container identifiers.

## 4. Verify Signing & Capabilities in Xcode

Open `SnipKey.xcodeproj`.

For the **SnipKey** target:

- Signing & Capabilities → Team: your team
- Automatically manage signing: on
- App Groups: the `group.<bundle-id>` generated above
- iCloud: the `iCloud.<bundle-id>` generated above
- iCloud service: CloudKit

For the **SnipKeyboard** target, select the same Team and the same App Group and iCloud container.

If Xcode offers to register the App Group or iCloud container, allow it. The identifiers must belong to your developer team; the upstream identifiers cannot be reused by another team.

## 5. Install on iPhone or iPad

Select your physical device in Xcode and run the **SnipKey** app target.

Then on the device open:

Settings → General → Keyboard → Keyboards → Add New Keyboard

Select the SnipKey/Shortcuts keyboard extension and enable **Allow Full Access**. Full Access is needed for the extension to use the shared App Group data and for the user-initiated **Save Clipboard** button.

## 6. Use the keyboard

The custom keyboard is intentionally not a Korean or English typing engine. Keep Apple's normal keyboard for typing and switch with the globe key only when you want clipboard snippets.

The keyboard provides:

- Recent snippets
- Favorites filter
- Save current text clipboard
- Exact duplicate detection
- Tap a snippet to insert it into the current text field
- Favorite/unfavorite directly from the keyboard
- Cursor left/right
- Space, delete and return
- Globe key to switch back to another keyboard

Secure, image and file snippets remain manageable in the main app but are intentionally excluded from the quick-insert keyboard.

## 7. iCloud behavior

The app uses one SwiftData store backed by the shared App Group and CloudKit. Install the same build on an iPhone and iPad signed into the same iCloud account and the saved snippet library should synchronize through the private CloudKit database.

CloudKit synchronization is asynchronous, so changes can take a short time to appear on another device. The main app remains the place to edit titles/content and search the complete library.

## Development note

The upstream QWERTY implementation is still present in the repository for reference and easy rollback, but the keyboard extension controller on this branch no longer loads it. This keeps the personal fork much smaller at runtime without making the upstream code difficult to recover.
