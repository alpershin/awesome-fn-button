# Contributing

Bug reports, tested compatibility results, and small focused fixes are welcome.

## Report a problem

Include the app version, macOS version, Mac and keyboard model, what you expected, what happened, and steps to reproduce. For missed Fn presses, distinguish an incorrect saved assignment from missed presses after applying it and signing out/back in.

Mention third-party keyboard remappers or dictation tools if they are involved. Review diagnostic output before sharing it. Do not upload your entire Preferences folder, personal recordings, or backup files.

## Submit a change

1. Follow [BUILD.md](BUILD.md) to build locally.
2. Keep the change focused on the reported behavior.
3. Add a meaningful test for changes to preference detection, backup, or recovery.
4. Run `swift test --scratch-path build/swift` and `bash scripts/build.sh`.
5. State what you tested and which hardware checks remain unverified.

Preserve absent settings, unrelated shortcuts, and later user changes. Never add automatic system-process restarts or keyboard interception without explaining the need and permissions. A successful preference write is not proof that macOS activated the setting.

Contributions are provided under the project's [MIT license](LICENSE).
