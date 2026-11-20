Direct Fn switching can now stay active in the background with the settings window closed.

**Historical intermediate version. Use [0.2.4](https://github.com/alpershin/awesome-fn-button/releases/tag/v0.2.4) for the current fixes.** This version does not restore native Fn switching on Quit and does not activate Fn preference changes in the live macOS session.

The source commit for this version was reconstructed from the development steps and rebuilt before publication; no earlier commit or publication date is implied.

- **Run in Background** closes the settings window while the app remains in the menu bar.
- A **globe icon** shows switching status and provides **Open Settings**, **Check for Updates**, and **Quit**.
- Closing settings removes the Dock icon; reopening settings brings it back. Closing the last window does not quit the app.
- Activation and wake handling belong to the application lifetime, independently of the settings window.
- The Fn monitor keeps background key handling responsive under App Nap while allowing normal system sleep.
- Fn now switches immediately on key-down. If another key or modifier follows while Fn is held, the previous language is restored before passing that keyboard event through. A brief indicator change can occur during a combination.

The update checking and verified DMG downloads introduced in 0.2.1 are included.

Replace the installed app in Applications and reopen it. You may need to grant Accessibility again after updating the ad hoc signed app. No login item or separate service is installed. Quitting from the globe menu stops direct switching; reopen the app to resume or Restore original settings to recover the native Fn action.
