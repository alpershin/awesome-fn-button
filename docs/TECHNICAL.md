# Technical notes

## Architecture

- `FnCore`: preference reads, planned changes, backup, apply, and restore.
- `AwesomeFnButton`: a compact SwiftUI window with two actions: Apply changes and Restore original settings. Opening or activating it refreshes read-only diagnostics.
- `fn-diagnose`: a read-only command that prints JSON.
- `FnCoreTests`: tests using in-memory preferences and temporary files; real system preferences are not changed by tests.

Preferences are read and written with `CFPreferences` for the current user, separately for AnyHost and CurrentHost. Root privileges, keyboard interception, Accessibility, and a background service are not used. App Sandbox is not enabled because the app accesses system preference domains.

## Scope

| Domain | Key | Change |
|---|---|---|
| `com.apple.HIToolbox` | `AppleFnUsageType` | Set to `1`; also update an existing ByHost override |
| `com.apple.symbolichotkeys` | `AppleSymbolicHotKeys` | Set `enabled = false` only on detected conflicting records |

The shortcut dictionary is reread before modifying a specific record, preserving other entries. The backup stores the affected record in full so restore can detect a later reassignment. The system dictionary has no atomic compare-and-swap operation; do not edit keyboard shortcuts in System Settings during apply.

Absent values are preserved as absent in the backup. When AppleFnUsageType is missing, diagnostics report that no explicit assignment is stored. An Fn flag on an F-key or navigation key is not sufficient evidence of a physical Fn press, so that layer is excluded from automatic disabling.

The keys and shortcut formats are internal settings rather than a stable public Fn configuration API. Compatibility must be verified per macOS version. A preference write verifies storage; macOS may need a new login session to activate the change.

## Backup and recovery

The backup is completely written before the first system change. Exclusive creation prevents replacement of an existing backup. New directories use permissions `0700`, and the backup file uses `0600`. If backup writing fails, apply never begins. Incomplete or corrupt backups block further applies.

Before each write, the app checks that the setting still matches the diagnostic preview. A failed apply attempts recovery. If the current value differs from both the original and applied values, restore leaves it alone and retains the backup. Unsupported backup versions, addresses, or structures are rejected before writing.

The app does not restart system processes, use the private activateSettings helper, restart the Mac, or modify third-party remapper configuration.

## Validation

Fn input switching was verified by the project owner on macOS 27.0 / Apple Silicon. Unit tests cover recovery and conflict handling; additional hardware and OS coverage belongs in the compatibility checklist.

## References

- [Apple: Keyboard settings and Fn assignments](https://support.apple.com/en-ie/guide/mac-help/kbdm162/27/mac/27).
- [Apple: Dictation shortcuts can change the Fn assignment](https://support.apple.com/en-ie/guide/mac-help/mh40584/27/mac/27).
- [Apple: exact CFPreferences synchronization domains](https://developer.apple.com/documentation/corefoundation/cfpreferencessynchronize(_:_:_:)).
- [Apple: Fn event flags](https://developer.apple.com/documentation/coregraphics/cgeventflags).
- [macOS defaults: observed AppleFnUsageType values](https://macos-defaults.com/keyboard/applefnusagetype.html). Community observations, not an Apple compatibility guarantee.
- [Apple: ad hoc signing on Apple Silicon](https://developer.apple.com/documentation/macos-release-notes/macos-big-sur-11_0_1-universal-apps-release-notes).
- [Apple: opening apps without notarization](https://support.apple.com/102445).
