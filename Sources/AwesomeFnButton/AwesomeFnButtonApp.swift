import SwiftUI
import AppKit
import FnCore

@MainActor
final class AppModel: ObservableObject {
    @Published var report: DiagnosticReport?
    @Published var message: String?
    @Published var isError = false
    @Published var hasBackup = false
    @Published var busy = false
    private let store = SystemPreferences()
    private lazy var configuration = Configuration(store: store, backupURL: Configuration.defaultBackupURL)

    func refresh() {
        do {
            report = try Diagnostics.scan(store: store, sources: Diagnostics.inputSources())
        } catch {
            report = nil
            show(error.localizedDescription, error: true)
        }
        hasBackup = configuration.hasBackup
    }

    func apply() {
        guard let report else { return }
        busy = true
        defer { busy = false; refresh() }
        do {
            try configuration.apply(report.changes, inputSourceCount: Diagnostics.inputSources().count)
            show("Changes applied. If Fn has not updated yet, sign out and back in, then try switching languages.")
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    func restore() {
        busy = true
        defer { busy = false; refresh() }
        do {
            let unresolved = try configuration.restore()
            if unresolved.isEmpty {
                show("Original settings restored. Sign out and back in if Fn has not updated yet.")
            } else {
                show("Some settings were left unchanged. Your backup has been retained.\n" + unresolved.joined(separator: "\n"), error: true)
            }
        } catch {
            show(error.localizedDescription, error: true)
        }
    }

    private func show(_ text: String, error: Bool = false) {
        message = text
        isError = error
    }
}

@main
struct AwesomeFnButtonApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Awesome Fn Button") {
            ContentView(model: model)
                .frame(width: 460)
                .fixedSize(horizontal: false, vertical: true)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    model.refresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    model.refresh()
                }
        }
        .windowResizability(.contentSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel

    private var canApply: Bool {
        !model.busy && !model.hasBackup && model.report != nil
            && model.report?.changes.isEmpty == false
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
                    .disabled(model.busy || !model.hasBackup)
                    .frame(maxWidth: .infinity)
                Button("Apply changes", action: model.apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canApply)
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(20)
    }
}
