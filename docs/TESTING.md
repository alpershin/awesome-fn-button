# Testing

## Automated checks

```sh
swift test --scratch-path build/swift
bash scripts/build.sh
```

Tests use memory and temporary files. They cover explicit Fn shortcut detection, preservation of ordinary shortcuts, read-only scanning, absent original values, ByHost overrides, partial write failure, stale previews, insufficient input sources, backup retention, and external changes.

Direct mode tests cover target `0` apply/restore, preserving external changes, immediate Fn-down switching, no second switch on release, rapid repeated taps, duplicate Fn events, one undo per Fn chord, implicit navigation flags, other modifiers, reset during a press, and typing after release. They do not create a real event tap or change the active input source.

Update tests use fixture releases and a mocked URLSession transport. They cover numeric version comparison, matching architecture, ignoring drafts/prereleases and downgrades, URL/checksum validation, size/hash mismatch, offline errors, and GitHub rate limits.

Handoff tests cover Quit returning both Fn scopes to system action `1`, direct-mode resume, preserving originals and disabled conflicts, originally absent/disabled Fn values, repeated transitions, partial failure rollback, external changes, interrupted handoff recovery, and invalid journals. All preference writes in these tests use memory and temporary backups.

Live-activation tests inject the session activation callback. They verify activation after both preference scopes are saved, activation even when the target is already stored, rollback/reactivation after failure, and backup retention when Restore cannot activate the session. Unit tests do not call the private system function.

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
- [ ] Verify Fn-down changes language before release. Fn+arrows, Fn+F-keys, Fn+Delete, Fn+Q and Fn+modifiers restore the previous language; a brief indicator change is expected.
- [ ] Close the window and verify direct switching continues. Normal Quit stops the app and Fn switches languages through macOS; reopen to resume Direct.
- [ ] Check direct mode after sleep, unlock, Accessibility revocation/regrant, and input source list changes.
- [ ] Direct-mode Restore stops the event tap and restores original Fn values. Reopen with a legacy backup and confirm no direct monitor starts.
- [ ] Check for Updates shows the installed version and reports that no newer release is available when up to date.
- [ ] A newer matching release offers Download Update; a cancelled save panel makes no changes.
- [ ] A download verifies successfully and opens its DMG. Quit, replace the app in Applications, reopen, and regrant Accessibility if necessary.
- [ ] An offline check or failed download displays an error, allows retry, and leaves Fn switching and any existing destination file intact.
- [ ] Run in Background and the window close button leave the menu bar globe active without a Dock icon.
- [ ] The Dock icon returns when settings reopen and disappears again when they close.
- [ ] Open Settings from the globe repeatedly; there is one settings window and one Fn monitor.
- [ ] Check Fn in TextEdit and a browser while settings are closed and another app is active.
- [ ] Verify wake/unlock recovery with the settings window closed, and confirm normal idle system sleep still works.
- [ ] Check for Updates from the globe reopens settings and shows the result. Quit from the globe stops the process.
- [ ] After Quit, confirm the system Fn action is Change Input Source and ordinary Fn switching works with no app process.
- [ ] Check the native Fn action immediately after Quit without signing out, including when the saved value was already `1` but runtime behavior had not updated.
- [ ] Reopen without Accessibility permission after an update: system switching stays enabled until permission is granted and Direct can start.
- [ ] Verify Restore still recovers the pre-apply values after several Quit/relaunch cycles.

These checks require the actual keyboard and user session. Record results per OS/hardware combination.
