import Foundation
import Carbon
import CoreGraphics

public struct SettingChange: Codable {
    public let address: PreferenceAddress
    public let title: String
    public let before: PreferenceValue
    public let after: PreferenceValue

    public init(address: PreferenceAddress, title: String, before: PreferenceValue, after: PreferenceValue) {
        self.address = address
        self.title = title
        self.before = before
        self.after = after
    }
}

public struct DiagnosticReport: Codable {
    public let systemVersion: String
    public let inputSources: [String]
    public let fnAssignment: String
    public let changes: [SettingChange]
    public let notes: [String]
}

public enum Diagnostics {
    public static func inputSources() -> [String] {
        let filter = [kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!] as CFDictionary
        guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        return sources.compactMap { source in
            guard let capable = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable),
                  CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(capable).takeUnretainedValue()),
                  let name = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return nil }
            return Unmanaged<CFString>.fromOpaque(name).takeUnretainedValue() as String
        }
    }

    public static func scan(store: PreferenceStore, sources: [String], directSwitching: Bool = false) throws -> DiagnosticReport {
        var changes: [SettingChange] = []
        var notes = [
            "System preference compatibility depends on the macOS version.",
            "Some Siri, hold-Fn, and hidden system shortcuts may have no accessible preference records.",
            "Third-party remappings and the Fn function/navigation-key layer are preserved.",
            "If macOS does not pick up the changes immediately, sign out and back in or restart."
        ]
        let anyFn = try store.read(.fn())
        let hostFn = try store.read(.fn(currentHost: true))
        let effectiveFn = try hostFn.object() ?? anyFn.object()
        let assignment: String
        if let number = effectiveFn as? NSNumber {
            assignment = [0: "Do nothing", 1: "Switch input source", 2: "Emoji & Symbols", 3: "Dictation"][number.intValue]
                ?? "Unknown value: \(number)"
        } else {
            assignment = "No explicit assignment saved"
        }
        let target = try PreferenceValue(directSwitching ? 0 : 1)
        for (address, before) in [(PreferenceAddress.fn(), anyFn), (.fn(currentHost: true), hostFn)] {
            let existing = try before.object()
            if address.currentHost && existing == nil { continue }
            if before != target {
                let action = directSwitching ? "Disable the system Fn picker (app switches directly)" : "Fn → language switching"
                changes.append(SettingChange(address: address, title: "\(action)\(address.currentHost ? " (this Mac)" : "")",
                                             before: before, after: target))
            }
        }
        for host in [false, true] {
            let raw = try store.read(.hotkeys(currentHost: host)).object()
            guard raw == nil || raw is [String: Any] else { throw FnError.message("Unsupported AppleSymbolicHotKeys format.") }
            let hotkeys = raw as? [String: Any] ?? [:]
            for id in hotkeys.keys.sorted() {
                guard let entry = hotkeys[id] as? [String: Any],
                      (entry["enabled"] as? NSNumber)?.boolValue != false else { continue }
                guard (entry["enabled"] as? NSNumber)?.boolValue == true else {
                    notes.append("Shortcut #\(id): unknown state; left unchanged.")
                    continue
                }
                guard let value = entry["value"] as? [String: Any],
                      let parameters = value["parameters"] as? [NSNumber], parameters.count == 3 else {
                    notes.append("Shortcut #\(id)\(host ? " (this Mac)" : ""): incomplete assignment; left unchanged.")
                    continue
                }
                if isFnShortcut(parameters.map(\.int64Value)) {
                    var disabled = entry
                    disabled["enabled"] = false
                    changes.append(SettingChange(address: .hotkeys(currentHost: host, member: id),
                                                 title: "Disable Fn shortcut #\(id)\(host ? " (this Mac)" : "")",
                                                 before: try PreferenceValue(entry), after: try PreferenceValue(disabled)))
                }
            }
        }
        if sources.count < 2 { notes.insert("Language switching requires at least two selectable input sources.", at: 0) }
        return DiagnosticReport(systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                inputSources: sources, fnAssignment: assignment, changes: changes, notes: notes)
    }

    public static func isFnShortcut(_ parameters: [Int64]) -> Bool {
        guard parameters.count == 3 else { return false }
        let fn = Int64(CGEventFlags.maskSecondaryFn.rawValue)
        // Modifier-double-tap records encode a flag and its bitwise complement.
        if parameters[0] == fn && parameters[1] == ~fn { return true }
        let keyCode = parameters[1]
        // shortcut: Fn is implicit on arrows/navigation/F-keys too; leave that layer until hardware validation.
        let implicitFnCodes: Set<Int64> = [64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105,
                                         106, 107, 109, 111, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126]
        guard (0...127).contains(keyCode), !implicitFnCodes.contains(keyCode) else { return false }
        return parameters[2] & fn != 0 || keyCode == 63
    }
}
