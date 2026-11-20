# Testing

## Automated checks

```sh
swift test --scratch-path build/swift
bash scripts/build.sh
```

Tests use memory and temporary files. They cover explicit Fn shortcut detection, preservation of ordinary shortcuts, read-only scanning, absent original values, ByHost overrides, partial write failure, stale previews, insufficient input sources, backup retention, and external changes.

Direct mode tests cover target `0` apply/restore, preserving external changes, rapid repeated standalone taps, duplicate Fn events, Fn chords, implicit navigation flags, other modifiers, and reset during a press. They do not create a real event tap or change the active input source.

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
- [ ] Restore an old system-mode backup, enable direct switching, and grant Accessibility. Without permission, Apply makes no preference changes.
- [ ] In direct mode, compare 30 rapid Fn taps in TextEdit and a browser; check language selection before immediately typing and confirm no system picker appears.
- [ ] Verify Fn+arrows, Fn+F-keys, Fn+Delete, Fn+Q and Fn+modifiers do not switch languages in direct mode.
- [ ] Close the window and verify direct switching continues. Quit and verify it stops; reopen to resume.
- [ ] Check direct mode after sleep, unlock, Accessibility revocation/regrant, and input source list changes.
- [ ] Direct-mode Restore stops the event tap and restores original Fn values. Reopen with a legacy backup and confirm no direct monitor starts.

These checks require the actual keyboard and user session. Record results per OS/hardware combination.


For this reconstructed intermediate source, run the unit tests and packaging checks described in BUILD.md. Hardware validation and known issues are recorded in RELEASE-0.2.3.md.
