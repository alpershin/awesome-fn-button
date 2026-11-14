First release for **macOS / Apple Silicon**.

- Compact native app with exactly two actions: **Apply changes** and **Restore original settings**.
- Automatic read-only diagnostics and a preview of proposed changes.
- Configure the saved Fn / Globe assignment for input-source switching.
- Disable detected explicit Fn shortcut conflicts.
- Back up original values and restore them while preserving later external changes.
- Custom cartoon app icon, English documentation, and source-build instructions.

Download the **arm64 DMG**, open it, and drag the app into Applications. The ZIP contains the same app. Use the `.sha256` file to check download integrity.

The app uses a free ad hoc signature, **without Developer ID or notarization**. For a blocked first launch, use System Settings → Privacy & Security → Open Anyway for this app. No paid Apple developer membership is required.

**Verified:** Fn input switching was tested by the project owner on macOS 27.0 / Apple Silicon. Build, 9 unit tests, diagnostics, preference storage, app launch, and packaging also passed locally.

**Scope:** hidden shortcuts, some Siri assignments, holding Fn, and third-party remappers may remain active. Other OS versions and keyboards have not been validated. Sign out and back in if macOS does not pick up the setting immediately.
