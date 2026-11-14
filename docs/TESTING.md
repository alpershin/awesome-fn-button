# Testing

## Automated checks

```sh
swift test --scratch-path build/swift
bash scripts/build.sh
```

Tests use memory and temporary files. They cover explicit Fn shortcut detection, preservation of ordinary shortcuts, read-only scanning, absent original values, ByHost overrides, partial write failure, stale previews, insufficient input sources, backup retention, and external changes.

Packaging validates Info.plist and the ad hoc code signature. GitHub Actions repeats testing and packaging; it does not exercise a physical keyboard.

## Hardware checklist

Record the Mac model, keyboard model, macOS version, and any active keyboard remappers. Fn input switching has been verified by the project owner on macOS 27.0 / Apple Silicon; use this checklist when extending support or testing a new release.

- [ ] Downloaded DMG opens and the app copies into Applications.
- [ ] First launch can be approved for this app in Privacy & Security.
- [ ] Launching and activating the app leave preferences unchanged.
- [ ] The preview matches the expected assignments.
- [ ] Apply is unavailable with fewer than two selectable input sources.
- [ ] Backup values match the pre-apply state.
- [ ] System Settings shows the intended Fn action after applying; check sign-out/back-in if needed.
- [ ] Compare 30 single and rapid repeated Fn presses in TextEdit and a browser before and after.
- [ ] Check double-tap and hold behavior, Dictation, Emoji, and Siri. Record any remaining assignments.
- [ ] Ctrl+Space, F-keys, arrows, and unrelated shortcuts still work.
- [ ] Check app relaunch, sleep, wake, and a new login session.
- [ ] Restore returns the original Fn assignment and affected shortcuts.
- [ ] Restore preserves a shortcut changed manually after applying and retains the backup.

These checks require the actual keyboard and user session. Record results per OS/hardware combination.
