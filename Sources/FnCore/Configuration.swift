import Foundation

private struct Backup: Codable {
    let version: Int
    let createdAt: Date
    let changes: [SettingChange]
    var pendingFnAction: Int? = nil
    var pendingFnAddresses: [PreferenceAddress]? = nil
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
        // Exclusive creation prevents two app instances from replacing each other's backup.
        try save(Backup(version: 1, createdAt: Date(), changes: changes), replacing: false)
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

    /// Changes only the app-owned Fn action, keeping the original values and shortcut backup.
    public func setFnAction(_ action: Int) throws {
        guard action == 0 || action == 1 else { throw FnError.message("Unsupported Fn action.") }
        let original = hasBackup ? try loadBackup() : nil
        let target = try PreferenceValue(action)
        var changes = original?.changes ?? []
        var writes: [SettingChange] = []
        for address in [PreferenceAddress.fn(), .fn(currentHost: true)] {
            let current = try store.read(address)
            let index = changes.firstIndex { $0.address == address }
            if address.currentHost, try current.object() == nil, index == nil { continue }
            if let index {
                let change = changes[index]
                let pending = try original?.pendingFnAddresses?.contains(address) == true
                    ? original?.pendingFnAction.map { try PreferenceValue($0) } : nil
                guard current == change.after || current == pending else {
                    if action == 1, current == target { continue }
                    throw FnError.message("The Fn action changed outside the app. It was left unchanged.")
                }
                changes[index] = SettingChange(address: address, title: change.title, before: change.before, after: target)
            } else {
                if current == target { continue }
                // An untracked native action must never be disabled automatically on launch.
                guard action == 1, current == (try PreferenceValue(0)) else {
                    throw FnError.message("The Fn action is not owned by the app. Restore and apply again to enable direct switching.")
                }
                changes.append(SettingChange(address: address, title: "Fn action", before: current, after: target))
            }
            if current != target {
                writes.append(SettingChange(address: address, title: "Fn action", before: current, after: target))
            }
        }
        guard !writes.isEmpty || original?.pendingFnAction != nil else { return }
        try validate(changes)
        // Journal both possible applied values so Restore can recover an interrupted handoff.
        let oldChanges = changes.map { change in
            let previous = original?.changes.first { $0.address == change.address }
            let current = writes.first { $0.address == change.address }?.before
            return SettingChange(address: change.address, title: change.title, before: change.before,
                                 after: current ?? previous?.after ?? change.after)
        }
        let journal = Backup(version: 1, createdAt: original?.createdAt ?? Date(), changes: oldChanges,
                             pendingFnAction: action, pendingFnAddresses: writes.map(\.address))
        try save(journal, replacing: original != nil)
        do {
            for change in writes {
                guard try store.read(change.address) == change.before else {
                    throw FnError.message("The Fn action changed during the handoff.")
                }
                try store.write(change.after, at: change.address)
                guard try store.read(change.address) == change.after else {
                    throw FnError.message("Could not verify the Fn action.")
                }
            }
            try save(Backup(version: 1, createdAt: journal.createdAt, changes: changes), replacing: true)
        } catch {
            let cause = error
            var recovered = true
            for change in writes.reversed() {
                do {
                    let current = try store.read(change.address)
                    if current == change.before { continue }
                    guard current == change.after else { recovered = false; continue }
                    try store.write(change.before, at: change.address)
                    if try store.read(change.address) != change.before { recovered = false }
                } catch { recovered = false }
            }
            if recovered {
                if let original { try save(original, replacing: true) }
                else { try FileManager.default.removeItem(at: backupURL) }
            }
            throw FnError.message("\(cause.localizedDescription)\(recovered ? "" : " The backup has been retained for recovery.")")
        }
    }

    /// Values changed elsewhere after applying are never overwritten.
    @discardableResult public func restore() throws -> [String] {
        let backup = try loadBackup()
        var unresolved: [String] = []
        for change in backup.changes.reversed() {
            let title = change.address.member.map { "Fn shortcut #" + $0 } ?? "Fn action"
            do {
                let current = try store.read(change.address)
                if current == change.before { continue }
                let pending = try backup.pendingFnAddresses?.contains(change.address) == true
                    ? backup.pendingFnAction.map { try PreferenceValue($0) } : nil
                guard current == change.after || current == pending else {
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

    private func loadBackup() throws -> Backup {
        let data = try Data(contentsOf: backupURL)
        guard data.count <= 1_000_000 else { throw FnError.message("The backup file has an invalid size.") }
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        guard backup.version == 1 else { throw FnError.message("Unsupported backup version.") }
        guard backup.pendingFnAction == nil || backup.pendingFnAction == 0 || backup.pendingFnAction == 1 else {
            throw FnError.message("Unsupported pending Fn action.")
        }
        try validate(backup.changes)
        if let addresses = backup.pendingFnAddresses {
            guard backup.pendingFnAction != nil, addresses.count <= 2, Set(addresses).count == addresses.count,
                  addresses.allSatisfy({ address in
                      address == .fn() || address == .fn(currentHost: true)
                  }), addresses.allSatisfy({ address in backup.changes.contains { $0.address == address } }) else {
                throw FnError.message("Unsupported pending Fn changes.")
            }
        } else if backup.pendingFnAction != nil {
            throw FnError.message("The pending Fn changes are missing.")
        }
        return backup
    }

    private func save(_ backup: Backup, replacing: Bool) throws {
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let data = try JSONEncoder().encode(backup)
        try data.write(to: backupURL, options: replacing ? .atomic : .withoutOverwriting)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backupURL.path)
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
