import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let updates = UpdateModel()
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.model.refresh() }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)
            .sink { notification in
                guard let window = notification.object as? NSWindow,
                      window.identifier?.rawValue == "settings" else { return }
                NSApp.setActivationPolicy(.accessory)
            }
            .store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { notification in
                guard let window = notification.object as? NSWindow,
                      window.identifier?.rawValue == "settings" else { return }
                NSApp.setActivationPolicy(.regular)
            }
            .store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.didWakeNotification)
            .merge(with: workspace.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification))
            .sink { [weak self] _ in self?.model.resume() }
            .store(in: &subscriptions)
        model.refresh()
        // LSUIElement startup can finish after SwiftUI first shows the window.
        DispatchQueue.main.async {
            if NSApp.windows.contains(where: { $0.identifier?.rawValue == "settings" && $0.isVisible }) {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        subscriptions.removeAll()
    }
}

struct BackgroundMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateModel

    var body: some View {
        Text(model.directRunning ? "Language switching active" : (model.directEnabled ? "Direct switching paused" : "System Fn mode"))
        Divider()
        Button("Open Settings…", action: showSettings)
        Button("Check for Updates…") {
            showSettings()
            updates.check()
        }
        .disabled(updates.busy)
        Divider()
        Button("Quit Awesome Fn Button") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showSettings() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }
}
