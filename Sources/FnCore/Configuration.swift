import Foundation

private struct Backup: Codable {
    let version: Int
    let createdAt: Date
    let changes: [SettingChange]
}

public final class Configuration {
    private let store: PreferenceStore
    public let backupURL: URL
    public var hasBackup: Bool { FileManager.default.fileExists(atPath: backupURL.path) }

    public init(store: PreferenceStore, backupURL: URL) {
        self.store = store
        self.backupURL = backupURL
    }

    public static var defaultBackupURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/AwesomeFnButton/backup.json")
    }

    public func apply(_ changes: [SettingChange], inputSourceCount: Int) throws {
        guard inputSourceCount >= 2 else { throw FnError.message("Add at least two input sources in Keyboard settings.") }
        guard !hasBackup else { throw FnError.message("Restore the previous changes first. Your backup has been retained.") }
        guard !changes.isEmpty else { return }
        try validate(changes)
        for change in changes {
            guard try store.read(change.address) == change.before else {
                throw FnError.message("Settings changed after the scan. Reopen the app to refresh the preview.")
            }
        }
        let directory = backupURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(Backup(version: 1, createdAt: Date(), changes: changes))
        // Exclusive creation prevents two app instances from replacing each other's backup.
        // A partial write blocks future applies and never precedes system changes.
        try data.write(to: backupURL, options: .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
        do {
            for change in changes {
                guard try store.read(change.address) == change.before else {
                    throw FnError.message("A setting changed during apply. The operation was stopped.")
                }
                try store.write(change.after, at: change.address)
                guard try store.read(change.address) == change.after else {
                    throw FnError.message("Could not verify the saved setting: \(change.title).")
                }
            }
        } catch {
            let cause = error.localizedDescription
            let unresolved: [String]
            do {
                unresolved = try restore()
            } catch {
                throw FnError.message("\(cause)\nCould not finish recovery: \(error.localizedDescription). Your backup has been retained.")
            }
            throw FnError.message("\(cause)\n\(unresolved.isEmpty ? "Original settings restored." : "Some settings could not be restored; your backup has been retained: " + unresolved.joined(separator: ", "))")
        }
    }

    /// Values changed elsewhere after applying are never overwritten.
    @discardableResult public func restore() throws -> [String] {
        let data = try Data(contentsOf: backupURL)
        guard data.count <= 1_000_000 else { throw FnError.message("The backup file has an invalid size.") }
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        guard backup.version == 1 else { throw FnError.message("Unsupported backup version.") }
        try validate(backup.changes)
        var unresolved: [String] = []
        for change in backup.changes.reversed() {
            let title = change.address.member.map { "Fn shortcut #" + $0 } ?? "Fn action"
            do {
                let current = try store.read(change.address)
                if current == change.before { continue }
                guard current == change.after else {
                    unresolved.append("\(title) — changed outside the app")
                    continue
                }
                try store.write(change.before, at: change.address)
                guard try store.read(change.address) == change.before else {
                    throw FnError.message("Could not verify the restored setting.")
                }
            } catch {
                unresolved.append("\(title) — \(error.localizedDescription)")
            }
        }
        if unresolved.isEmpty { try FileManager.default.removeItem(at: backupURL) }
        return unresolved
    }

    private func validate(_ changes: [SettingChange]) throws {
        guard !changes.isEmpty, changes.count <= 1000,
              Set(changes.map(\.address)).count == changes.count else {
            throw FnError.message("Invalid list of changes.")
        }
        for change in changes {
            guard change.address.isWritable else { throw FnError.message("The backup contains an unsupported preference address.") }
            let before = try change.before.object()
            let after = try change.after.object()
            if change.address.member == nil {
                guard after as? NSNumber == NSNumber(value: 0) || after as? NSNumber == NSNumber(value: 1),
                      before == nil || before is NSNumber else { throw FnError.message("Unsupported Fn assignment format.") }
            } else {
                guard let original = before as? [String: Any], let disabled = after as? [String: Any],
                      (disabled["enabled"] as? NSNumber)?.boolValue == false else {
                    throw FnError.message("Unsupported shortcut format in the backup.")
                }
                var expected = original
                expected["enabled"] = false
                guard try PreferenceValue(expected) == change.after else {
                    throw FnError.message("The backup contains unexpected shortcut changes.")
                }
            }
        }
    }
}
