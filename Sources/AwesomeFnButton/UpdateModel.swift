import AppKit
import SwiftUI
import UniformTypeIdentifiers
import FnCore

@MainActor
final class UpdateModel: ObservableObject {
    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    @Published private(set) var busy = false
    @Published private(set) var status: String?
    @Published private(set) var isError = false
    @Published private(set) var update: AppUpdate?
    @Published private(set) var downloadedURL: URL?

    func check() {
        guard !busy else { return }
        busy = true
        update = nil
        downloadedURL = nil
        isError = false
        status = "Checking GitHub…"
        Task {
            defer { busy = false }
            do {
                update = try await Updates.check(currentVersion: currentVersion)
                status = update.map { "Version \($0.version) is available." } ?? "No newer release is available."
            } catch {
                status = error.localizedDescription
                isError = true
            }
        }
    }

    func download() {
        guard !busy, let update else { return }
        let panel = NSSavePanel()
        panel.title = "Download Awesome Fn Button \(update.version)"
        panel.nameFieldStringValue = update.assetName
        panel.allowedContentTypes = [.diskImage]
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        busy = true
        isError = false
        status = "Downloading and verifying \(update.version)…"
        Task {
            defer { busy = false }
            do {
                try await Updates.download(update, to: destination)
                downloadedURL = destination
                status = "Download verified. Quit this app, then drag the new app into Applications and reopen it. You may need to grant Accessibility again."
                openInstaller()
            } catch {
                status = error.localizedDescription
                isError = true
            }
        }
    }

    func openInstaller() {
        guard let downloadedURL else { return }
        if !NSWorkspace.shared.open(downloadedURL) {
            status = "The installer was saved but could not be opened. Open it from Finder."
            isError = true
            NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
        }
    }
}

struct UpdateView: View {
    @ObservedObject var model: UpdateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Version \(model.currentVersion)").foregroundStyle(.secondary)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Check for Updates", action: model.check).disabled(model.busy)
            }
            if let status = model.status {
                Text(status)
                    .foregroundStyle(model.isError ? Color.orange : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if model.update != nil {
                if model.downloadedURL != nil {
                    Button("Open Installer", action: model.openInstaller).disabled(model.busy)
                } else {
                    Button("Download Update…", action: model.download).disabled(model.busy)
                }
            }
            Link("Releases on GitHub", destination: Updates.releasesURL)
        }
        .font(.callout)
    }
}
