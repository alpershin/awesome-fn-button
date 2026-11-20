# Technical notes

## Architecture

- `FnCore`: preference reads, planned changes, backup, apply, restore, and standalone Fn press tracking.
- `AwesomeFnButton`: a compact SwiftUI window with two actions: Apply changes and Restore original settings. Opening or activating it refreshes read-only diagnostics.
- `fn-diagnose`: a read-only command that prints JSON.
- `FnCoreTests`: tests using in-memory preferences and temporary files; real system preferences are not changed by tests.

Preferences are read and written with `CFPreferences` for the current user, separately for AnyHost and CurrentHost. Root privileges and a background service are not used. Optional direct switching requires Accessibility and a session event tap while the app runs. App Sandbox is not enabled because the app accesses system preference domains.

## Direct switching

Direct mode is opt-in. Its apply plan sets AppleFnUsageType to `0`, preventing the native picker from competing with `TISSelectInputSource`. Permission and event tap creation are checked before applying preferences. Existing version-1 backups, including the original target `1`, remain restorable. The selected mode is saved only after successful apply.

The event tap passes all keyboard events through unchanged. Only physical Fn flagsChanged records (key code 63) begin/end a tracked press. Fn-down cycles enabled input sources; a following keyboard event while Fn is held restores the previous input source. There is no timer, debounce, synthetic shortcut, or custom HUD. Text Input Source selection errors are reported in the window.

Timeout/disabled notifications, wake, and session reactivation reset press state and re-enable the monitor. Activation also checks the saved system action and Accessibility permission; if a conflicting system Fn action is detected, direct switching pauses rather than writing over an external change. No login item is installed. Quit leaves the saved Fn action at `0`; reopen to resume or Restore to recover the original settings. The separate macOS caret language indicator is not modified.

## Scope

| Domain | Key | Change |
|---|---|---|
| `com.apple.HIToolbox` | `AppleFnUsageType` | Set to `1` in system mode or `0` in direct mode; also update an existing ByHost override |
| `com.apple.symbolichotkeys` | `AppleSymbolicHotKeys` | Set `enabled = false` only on detected conflicting records |

The shortcut dictionary is reread before modifying a specific record, preserving other entries. The backup stores the affected record in full so restore can detect a later reassignment. The system dictionary has no atomic compare-and-swap operation; do not edit keyboard shortcuts in System Settings during apply.

Absent values are preserved as absent in the backup. When AppleFnUsageType is missing, diagnostics report that no explicit assignment is stored. An Fn flag on an F-key or navigation key is not sufficient evidence of a physical Fn press, so that layer is excluded from automatic disabling.

The keys and shortcut formats are internal settings rather than a stable public Fn configuration API. Compatibility must be verified per macOS version. A preference write verifies storage; macOS may need a new login session to activate the change.

## Backup and recovery

The backup is completely written before the first system change. Exclusive creation prevents replacement of an existing backup. New directories use permissions `0700`, and the backup file uses `0600`. If backup writing fails, apply never begins. Incomplete or corrupt backups block further applies.

Before each write, the app checks that the setting still matches the diagnostic preview. A failed apply attempts recovery. If the current value differs from both the original and applied values, restore leaves it alone and retains the backup. Unsupported backup versions, addresses, or structures are rejected before writing.

The app does not restart system processes, use the private activateSettings helper, restart the Mac, or modify third-party remapper configuration.

## Validation

System-mode Fn input switching was tested by the project owner on macOS 27.0 / Apple Silicon. Direct mode still requires physical-keyboard validation. Unit tests cover press tracking, recovery, and conflict handling; additional hardware and OS coverage belongs in the compatibility checklist.

## References

- [Apple: Keyboard settings and Fn assignments](https://support.apple.com/en-ie/guide/mac-help/kbdm162/27/mac/27).
- [Apple: Dictation shortcuts can change the Fn assignment](https://support.apple.com/en-ie/guide/mac-help/mh40584/27/mac/27).
- [Apple: exact CFPreferences synchronization domains](https://developer.apple.com/documentation/corefoundation/cfpreferencessynchronize(_:_:_:)).
- [Apple: Fn event flags](https://developer.apple.com/documentation/coregraphics/cgeventflags).
- [macOS defaults: observed AppleFnUsageType values](https://macos-defaults.com/keyboard/applefnusagetype.html). Community observations, not an Apple compatibility guarantee.
- [Apple: ad hoc signing on Apple Silicon](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-universal-apps-release-notes).
- [Apple: opening apps without notarization](https://support.apple.com/102445).

## Updates

The update button requests the public GitHub `repos/alpershin/awesome-fn-button/releases/latest` endpoint without authentication. There are no background checks. Numeric three-part versions are compared numerically; draft/prerelease responses and downgrades are not offered. The installer must match the running binary's architecture and the exact release asset name and repository download URL.

The download is asynchronous. Its size and SHA-256 digest from GitHub release metadata are verified before an atomic save to the user-selected destination. A failed check or download does not change keyboard settings, backups, or the installed application. The verified DMG opens through NSWorkspace; replacing the app remains the usual Finder drag-to-install operation. Ad hoc updates can require Accessibility to be granted again.

## Background and immediate Fn switching

See [the release notes](RELEASE-0.2.2.md). The menu bar app remains running with settings closed. Fn-down switches immediately; a following keyboard combination restores the previous source.
