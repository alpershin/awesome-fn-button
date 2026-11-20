import SwiftUI
import AppKit
import ApplicationServices
import FnCore

@MainActor
final class AppModel: ObservableObject {
    @Published var report: DiagnosticReport?
    @Published var message: String?
    @Published var isError = false
    @Published var hasBackup = false
    @Published var busy = false
    @Published var directSwitching = UserDefaults.standard.bool(forKey: "directSwitching")
    @Published private(set) var directEnabled = UserDefaults.standard.bool(forKey: "directSwitching")
    @Published private(set) var directRunning = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    private let store = SystemPreferences()
    private lazy var configuration = Configuration(store: store, backupURL: Configuration.defaultBackupURL)
    private let switcher = DirectInputSwitcher()

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        do {
            report = try Diagnostics.scan(store: store, sources: Diagnostics.inputSources(), directSwitching: directSwitching)
            if directEnabled {
                let fn = try store.read(.fn(currentHost: true)).object() ?? store.read(.fn()).object()
                guard fn as? NSNumber == NSNumber(value: 0) else {
                    throw FnError.message("The system Fn action changed outside the app. Direct switching is paused to prevent double switching. Restore, then apply again.")
                }
                switcher.onError = { [weak self] text in self?.show(text, error: true) }
                try switcher.start()
                directRunning = true
            }
        } catch {
            switcher.stop()
            directRunning = false
            show(error.localizedDescription, error: true)
        }
        hasBackup = configuration.hasBackup
    }

    func apply() {
        guard let report else { return }
        busy = true
        defer { busy = false; refresh() }
        do {
            if directSwitching { try switcher.start(requestPermission: true) }
            try configuration.apply(report.changes, inputSourceCount: Diagnostics.inputSources().count)
            directEnabled = directSwitching
            UserDefaults.standard.set(directEnabled, forKey: "directSwitching")
            show(directSwitching
                 ? "Direct switching enabled. Press Fn to switch immediately. A following Fn combination restores the previous language. You can close this window and keep using the menu bar globe."
                 : "Changes applied. If Fn has not updated yet, sign out and back in, then try switching languages.")
        } catch {
            switcher.stop()
            directRunning = false
            show(error.localizedDescription, error: true)
        }
    }

    func restore() {
        busy = true
        defer { busy = false; refresh() }
        switcher.stop()
        directRunning = false
        directEnabled = false
        UserDefaults.standard.set(false, forKey: "directSwitching")
        do {
            let unresolved = configuration.hasBackup ? try configuration.restore() : []
            if unresolved.isEmpty {
                show("Original settings restored. Sign out and back in if Fn has not updated yet.")
            } else {
                show("Some settings were left unchanged. Your backup has been retained.\n" + unresolved.joined(separator: "\n"), error: true)
            }
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    func resume() {
        switcher.resume()
        refresh()
    }

    func stop() {
        switcher.stop()
        directRunning = false
    }

    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func show(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }
}

@main
struct AwesomeFnButtonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Awesome Fn Button", id: "settings") {
            ContentView(model: appDelegate.model, updates: appDelegate.updates)
                .frame(width: 460)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    appDelegate.model.refresh()
                }
        }
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) {} }

        MenuBarExtra("Awesome Fn Button", systemImage: "globe") {
            BackgroundMenu(model: appDelegate.model, updates: appDelegate.updates)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct ContentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppModel
    @ObservedObject var updates: UpdateModel

    private var canApply: Bool {
        !model.busy && !model.hasBackup && model.report != nil
            && (model.report?.changes.isEmpty == false || (model.directSwitching && !model.directEnabled))
            && (model.report?.inputSources.count ?? 0) >= 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Group {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "globe").resizable().scaledToFit().padding(10)
                    }
                }
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Awesome Fn Button").font(.title3.bold())
                    Text("Fn → language switching").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Toggle("Direct switching — no system picker", isOn: $model.directSwitching)
                    .disabled(model.busy || model.hasBackup || model.directEnabled)
                    .onChange(of: model.directSwitching) { _ in model.refresh() }
                if !model.accessibilityGranted {
                    Button("Open Accessibility Settings", action: model.openAccessibilitySettings)
                        .disabled(model.busy)
                }
                if model.hasBackup {
                    Text("Restore original settings to change the switching mode.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(model.directRunning
                     ? "Direct switching is running in the background. Use the globe in the menu bar to reopen settings or quit."
                     : "Requires Accessibility permission. Fn switches on key-down; a following Fn combination restores the previous language. Its indicator may change briefly.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let report = model.report {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input sources: " + (report.inputSources.isEmpty ? "none found" : report.inputSources.joined(separator: ", ")))
                    Text("Current Fn action: " + report.fnAssignment).foregroundStyle(.secondary)
                }
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

                if model.hasBackup {
                    Label("Original settings are backed up. Restore them before applying again.", systemImage: "externaldrive.badge.checkmark")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !report.changes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Changes to apply").font(.subheadline.bold())
                        ScrollView {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(report.changes.enumerated()), id: \.offset) { _, change in
                                    Text("• " + change.title)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .font(.callout)
                        .frame(height: min(CGFloat(report.changes.count) * 30, 110))
                    }
                } else {
                    Text("Your checked settings are already configured.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if report.inputSources.count < 2 {
                    Text("Add at least two input sources in Keyboard settings.")
                        .font(.callout).foregroundStyle(.orange)
                }
            }

            if let message = model.message {
                Label {
                    Text(message).textSelection(.enabled)
                } icon: {
                    Image(systemName: model.isError ? "exclamationmark.triangle" : "info.circle")
                }
                .font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(model.isError ? Color.orange.opacity(0.1) : Color.blue.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.updatesFrequently)
            }

            HStack(spacing: 10) {
                Button("Restore original settings", action: model.restore)
                    .disabled(model.busy || (!model.hasBackup && !model.directEnabled))
                    .frame(maxWidth: .infinity)
                Button("Apply changes", action: model.apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button("Run in Background") { dismiss() }
                .help("Close this window and keep the app running in the menu bar.")
                .frame(maxWidth: .infinity, alignment: .trailing)

            Divider()
            UpdateView(model: updates)
        }
        .padding(20)
    }
}
