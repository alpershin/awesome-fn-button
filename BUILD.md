# Build Awesome Fn Button

Use a Mac with Xcode, Swift 5.9 or newer, and Python 3 for packaging. The deployment target is macOS 13; settings compatibility must be verified separately for each OS version. The app has no third-party runtime dependencies.

```sh
git clone https://github.com/alpershin/awesome-fn-button.git
cd awesome-fn-button
swift test --scratch-path build/swift
bash scripts/build.sh
```

The packaging script builds for the host architecture, creates the macOS icon sizes from `Resources/AppIcon.png`, signs the bundle ad hoc, verifies it, and produces:

- `build/packaging/Awesome Fn Button.app`
- `build/releases/awesome-fn-button-0.2.1-<arch>.dmg`
- the same app in a ZIP archive, plus a SHA-256 file

No Apple account, signing certificate, API key, or notarization is required. Ad hoc signing does not establish Developer ID trust; downloaded builds may require an app-specific Gatekeeper exception.

The first packaging run downloads the pinned `dmgbuild`, `ds-store`, and `mac-alias` build tools into an isolated environment at `build/dmg-tools`. They are not bundled with the app. The installer background is drawn at 1× and 2× resolution with AppKit, using `Resources/InstallerFist.png` as the direction cue. Finder metadata fixes the window size and icon positions without AppleScript or Finder automation.

The build mounts the finished DMG read-only and checks that only the app and Applications link are visible, verifies the saved Finder layout and background, and validates the packaged app signature.

The background is embedded in the app's resources before signing. Finder's background alias points into that bundle, so no loose background image or volume icon appears beside the two installation items.

## Read-only diagnostics

```sh
swift run --scratch-path build/swift fn-diagnose
```

The command prints the detected input sources, Fn assignment, planned changes, and limitations as JSON. It has no apply or restore options. Review the output before sharing it.

## Development

Open `Package.swift` in Xcode, or run:

```sh
swift run --scratch-path build/swift AwesomeFnButton
```

The custom icon is included in the packaged `.app`; launching the executable through SwiftPM uses a fallback symbol.

Tests use an in-memory preference store and temporary backup files. They do not change real system settings. Follow [the hardware checklist](docs/TESTING.md) before claiming compatibility with a Mac/OS combination.
