Fix native Fn switching remaining inactive after Quit.

This is the recommended release. It also includes the update button and verified DMG downloads from 0.2.1, the menu bar background mode from 0.2.2, immediate Fn-down switching with rollback for combinations, and the preserved-settings handoff introduced in 0.2.3.

Version 0.2.3 saved and verified the system Fn action but did not apply it to the live macOS session. The preference could read Change Input Source while Fn still did nothing.

- Apply the effective Fn action through HIToolbox after saving it, including when the target value is already stored.
- Use the same activation step during direct/system handoff, explicit-action Apply/Restore, and rollback.
- Block refresh/resume callbacks while quitting so they cannot restart Direct switching during the handoff.
- Preserve original global/per-Mac preferences and backups. If activation fails, report it and retain recovery data.

The activation function is private and resolved dynamically. Unsupported macOS versions fail with an actionable error. Restoring an absent original setting preserves its absence without guessing a factory action and can still require a new login session.

The project owner confirmed that this live activation restored Fn switching while the app was fully closed. All 33 unit tests passed, including activation ordering, already-saved values, failure rollback, and recovery.

The project owner also confirmed fast Direct switching after the corrected startup disabled the native handler in the live session. Sleep/wake and broader hardware coverage remain in the testing checklist.
