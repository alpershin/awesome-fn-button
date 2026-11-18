Fn can now switch input sources directly, bypassing the native system picker.

- Enable **Direct switching — no system picker** to switch on release of a standalone Fn tap, without an added timer or debounce.
- Fn combinations with other keys pass through without switching languages.
- The event monitor resets after sleep or session reactivation and re-enables itself if macOS disables it after a timeout.
- **Open Accessibility Settings** opens the permission panel when access is missing. Returning to the app refreshes permission status.
- Original settings remain backed up, and backups from earlier versions can still be restored. Later external changes are preserved.

## Upgrade and setup

1. Quit Awesome Fn Button and replace the installed app in **Applications** with this release. Launch that installed copy.
2. If an earlier apply has a backup, click **Restore original settings** once to unlock the mode selection.
3. Enable **Direct switching — no system picker**. Use **Open Accessibility Settings** to grant access, then return and click **Apply changes**.
4. If the permission is already enabled but Apply still asks for it, remove the old Awesome Fn Button entry with **−**, then add `/Applications/Awesome Fn Button.app` with **+** and enable it again. Different ad hoc builds have different signatures; an old grant may belong to a previous build or another copy.

Keep the app running in direct mode. Closing the window keeps switching active; quitting stops switching while the saved system Fn action remains **Do Nothing**. Reopen the app to resume, or use **Restore original settings** to restore the original system action. No login item is installed.

The default system mode remains available and does not need the app running after apply. The small macOS language indicator beside the text cursor is separate from the native picker and may still appear. If the native picker still appears in direct mode, sign out and back in once so macOS loads the new Fn action.

## Downloads and validation

Download the **arm64 DMG** for drag-to-install, or the ZIP containing the same app. SHA-256 checksums are included. The app is signed ad hoc, without Developer ID or notarization.

All 15 unit tests passed. The release app built successfully; packaging verified the app signature, DMG layout, Applications link, and installer background. The Accessibility Settings button was checked in the macOS UI.

Physical-keyboard verification of direct switching, long-running behavior, and sleep/wake recovery is still pending. This release does not claim to eliminate every source of missed Fn presses.
