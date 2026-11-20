Check for and download updates directly from the app.

**Historical intermediate version. Use [0.2.4](https://github.com/alpershin/awesome-fn-button/releases/tag/v0.2.4) for the current fixes.** This version predates the menu bar background mode and safe handoff to native Fn switching on Quit. Quitting Direct mode leaves the native Fn action disabled.

The source commit for this version was reconstructed from the development steps and rebuilt before publication; no earlier commit or publication date is implied.

- **Check for Updates** checks the latest stable release on GitHub and shows whether a newer version is available.
- **Download Update…** downloads the DMG for the app's architecture to a location you choose.
- The installer size and SHA-256 digest are verified against GitHub release metadata before saving it or opening it.
- Offline, rate-limit, and download errors are shown in the app and allow retry.

The verified installer opens when the download finishes. Quit the running app, drag the new app into Applications, and reopen it. Ad hoc app updates may require Accessibility to be granted again. Keyboard settings and backups are preserved during update checks and downloads.

Updates are checked only when requested. No background updater or automatic replacement is installed.

The project owner has also confirmed that direct Fn switching works on their Mac running macOS 27.0 / Apple Silicon. Broader hardware and long-running tests remain in the compatibility checklist.
