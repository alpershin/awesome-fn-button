<p align="center">
  <img src="Resources/AppIcon.png" width="160" alt="A cartoon fist slamming the fn key">
</p>

<h1 align="center">Awesome Fn Button</h1>
<p align="center"><strong>One key. One job. Switch languages.</strong></p>
<p align="center">A free, open-source macOS utility that configures Fn / Globe for input switching and removes detected conflicting assignments.</p>

<p align="center">
  <a href="https://github.com/alpershin/awesome-fn-button/actions/workflows/ci.yml"><img src="https://github.com/alpershin/awesome-fn-button/actions/workflows/ci.yml/badge.svg" alt="macOS build"></a>
  <a href="https://github.com/alpershin/awesome-fn-button/releases/tag/v0.1.0"><img src="https://img.shields.io/badge/release-0.1.0-E8BEA5" alt="0.1.0"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-D4C8E8" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/platform-macOS-E1EDF5" alt="macOS">
</p>

<p align="center">
  <a href="https://github.com/alpershin/awesome-fn-button/releases">Download for Apple Silicon</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="BUILD.md">Build from source</a>
</p>

> **Verified on macOS 27.0 / Apple Silicon.** Fn input switching has been tested by the project owner on their Mac.

## Why Awesome Fn Button?

Fn should be predictable when you use it to switch languages. This project brings the relevant settings into one place, shows exactly what it can change, and keeps a way back.

- **Focused:** configure input switching and disable detected conflicting Fn shortcuts.
- **Local:** preferences and backups stay on your Mac. No server, account, or telemetry.
- **Reversible:** keep the original values and restore them without overwriting later user changes.
- **Open:** native Swift / SwiftUI, MIT licensed, with no third-party dependencies.

## How it works

1. Open the app to inspect your available input sources and saved Fn assignment.
2. Review the proposed changes. Launching the app does not apply them.
3. Click **Apply changes** to save a backup, apply the settings, and verify the stored values.
4. Test Fn in another app. If macOS has not picked up the changes, sign out and back in; a restart may also be needed.
5. Use **Restore original settings** to restore the original values.

You can close the app after applying settings; it does not intercept keystrokes or run as a background service.

## Quick start

### Installation

1. Download the Apple Silicon **DMG** from [Releases](https://github.com/alpershin/awesome-fn-button/releases).
2. Drag **Awesome Fn Button.app** into **Applications**.
3. Open it and review the detected settings. At least two selectable input sources are required.

The app has a free **ad hoc** signature, with **no Developer ID or Apple notarization**. If macOS blocks the first launch, use **System Settings → Privacy & Security → Open Anyway** for this app. See [Apple's instructions](https://support.apple.com/102445).

ZIP downloads contain the same application. A SHA-256 file is included with each release for checking download integrity.

### Development setup

See [BUILD.md](BUILD.md) for requirements, testing, read-only diagnostics, and packaging. No paid Apple developer membership is needed.

## What it changes

| Setting | Behavior |
|---|---|
| Fn / Globe primary action | Set the saved assignment to input-source switching |
| Existing per-Mac Fn override | Update it when present |
| Explicit saved Fn shortcuts | Disable detected conflicts, including the known double-tap format |
| Other keyboard settings | Preserve unrelated shortcuts and the F-key / navigation layer |

[Technical notes](docs/TECHNICAL.md) describe the preference keys, detection rules, and recovery behavior.

## Recovery

The app saves a local backup before its first change:

```text
~/Library/Application Support/AwesomeFnButton/backup.json
```

A new apply cannot replace an existing backup. Restore only changes a value if it still matches what the app applied. Conflicting external changes are left alone, and the backup is retained until recovery completes.

## Known limitations

- The preference keys are internal macOS settings, not a stable public Fn configuration API.
- Hidden/default shortcuts, some Siri assignments, holding Fn, and third-party remappers may remain active.
- Fn flags on function and navigation keys do not necessarily indicate a physical Fn press; that layer is intentionally preserved.
- Fn input switching was verified by the project owner on macOS 27.0 / Apple Silicon. Other OS versions and keyboard models have not been validated.
- The compilation target is macOS 13+. That is a build requirement, not a tested compatibility promise.

See the [hardware test checklist](docs/TESTING.md) for the remaining checks.

## Contributing

Small fixes, bug reports, and verified compatibility results are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), or [report a bug](https://github.com/alpershin/awesome-fn-button/issues/new/choose).

## License

[MIT](LICENSE) © Aleksandr Pershin.
