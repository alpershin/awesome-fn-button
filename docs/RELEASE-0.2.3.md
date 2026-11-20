Normal Quit now returns Fn to system language switching.

**Historical intermediate version with a known activation bug. Use [0.2.4](https://github.com/alpershin/awesome-fn-button/releases/tag/v0.2.4).** This version saves the native Fn action on Quit but does not apply it to the live session. Fn may remain inactive after Quit, or the native handler may remain active alongside Direct after reopening.

The source commit for this version was reconstructed from the development steps and rebuilt before publication; no earlier commit or publication date is implied.

- Quitting through the globe menu or Cmd+Q stops Direct switching, enables the native Fn language action, and verifies the saved values before exiting.
- Closing the settings window still leaves Direct switching active in the background.
- On reopening, Direct resumes after checking Accessibility and starting the Fn monitor. Without permission, the native fallback remains enabled.
- Conflicting shortcuts remain disabled. Original settings are preserved for Restore across Quit/relaunch cycles.
- Failed handoffs roll back; if a handoff cannot be completed, the app cancels Quit and shows an error. An interrupted preference transition is recorded for recovery.

This handoff applies to normal Quit. Force Quit, a crash, or power loss cannot guarantee that cleanup runs.

All 30 unit tests passed, including system/direct handoffs, recovery, both preference scopes, and external-change preservation. Verify native Fn behavior after Quit on the actual Mac, because macOS preference activation depends on the system version.
