import Foundation
import CoreFoundation
import Carbon
import Darwin

public struct PreferenceAddress: Codable, Hashable {
    public let domain: String
    public let key: String
    public let member: String?
    public let currentHost: Bool

    public init(domain: String, key: String, member: String? = nil, currentHost: Bool = false) {
        self.domain = domain
        self.key = key
        self.member = member
        self.currentHost = currentHost
    }

    public static func fn(currentHost: Bool = false) -> Self {
        Self(domain: "com.apple.HIToolbox", key: "AppleFnUsageType", currentHost: currentHost)
    }

    public static func hotkeys(currentHost: Bool = false, member: String? = nil) -> Self {
        Self(domain: "com.apple.symbolichotkeys", key: "AppleSymbolicHotKeys", member: member, currentHost: currentHost)
    }

    public var isWritable: Bool {
        if domain == "com.apple.HIToolbox", key == "AppleFnUsageType", member == nil { return true }
        return domain == "com.apple.symbolichotkeys" && key == "AppleSymbolicHotKeys"
            && member.map { !$0.isEmpty && $0.allSatisfy(\.isNumber) } == true
    }
}

/// A plist wrapped in a dictionary preserves both scalar values and an absent key.
public struct PreferenceValue: Codable, Equatable {
    private let data: Data?

    public init(_ object: Any?) throws {
        data = try object.map {
            try PropertyListSerialization.data(fromPropertyList: ["value": $0], format: .binary, options: 0)
        }
    }

    public func object() throws -> Any? {
        guard let data else { return nil }
        guard let wrapper = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let value = wrapper["value"] else { throw FnError.message("The backup contains an invalid value.") }
        return value
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.data != nil || rhs.data != nil else { return true }
        guard let left = try? lhs.object(), let right = try? rhs.object() else { return false }
        return NSDictionary(dictionary: ["value": left]).isEqual(to: ["value": right])
    }
}

public enum FnError: LocalizedError {
    case message(String)
    public var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

public protocol PreferenceStore {
    func read(_ address: PreferenceAddress) throws -> PreferenceValue
    func write(_ value: PreferenceValue, at address: PreferenceAddress) throws
}

public final class SystemPreferences: PreferenceStore {
    public init() {}

    /// CFPreferences alone does not update the Fn action used by the current session.
    public func activateFnAction() throws {
        let anyHost = try read(.fn())
        let currentHost = try read(.fn(currentHost: true))
        guard let number = try (currentHost.object() ?? anyHost.object()) as? NSNumber else {
            // An absent original preference has no explicit action to activate.
            return
        }
        guard (0...3).contains(number.intValue) else { throw FnError.message("Unsupported Fn action.") }
        guard !CFPreferencesAppValueIsForced("AppleFnUsageType" as CFString, "com.apple.HIToolbox" as CFString) else {
            throw FnError.message("The Fn action is managed by an organization profile.")
        }
        guard let handle = dlopen("/System/Library/Frameworks/Carbon.framework/Carbon", RTLD_LAZY | RTLD_LOCAL) else {
            throw FnError.message("Could not load the system Fn settings API. Change the Fn action in Keyboard settings.")
        }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "TISUpdateFnUsageType") else {
            throw FnError.message("This macOS version cannot activate the Fn action immediately. Change it in Keyboard settings.")
        }
        // Private API: resolve dynamically so unsupported macOS versions fail safely.
        let update = unsafeBitCast(symbol, to: (@convention(c) (Int32) -> Void).self)
        update(number.int32Value)
        // The setter also writes AnyHost; preserve distinct per-host/original values.
        if try read(.fn()) != anyHost { try write(anyHost, at: .fn()) }
        if try read(.fn(currentHost: true)) != currentHost { try write(currentHost, at: .fn(currentHost: true)) }
    }

    private func root(_ address: PreferenceAddress) throws -> Any? {
        guard CFPreferencesSynchronize(address.domain as CFString, kCFPreferencesCurrentUser,
                                       address.currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost) else {
            throw FnError.message("Could not read preferences for \(address.domain).")
        }
        return CFPreferencesCopyValue(address.key as CFString, address.domain as CFString,
                                      kCFPreferencesCurrentUser,
                                      address.currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost)
    }

    public func read(_ address: PreferenceAddress) throws -> PreferenceValue {
        let value = try root(address)
        guard let member = address.member else { return try PreferenceValue(value) }
        guard value == nil || value is [String: Any] else {
            throw FnError.message("Unsupported format for \(address.key); no changes were made.")
        }
        return try PreferenceValue((value as? [String: Any])?[member])
    }

    public func write(_ value: PreferenceValue, at address: PreferenceAddress) throws {
        guard address.isWritable else { throw FnError.message("Changing this preference is not allowed.") }
        guard !CFPreferencesAppValueIsForced(address.key as CFString, address.domain as CFString) else {
            throw FnError.message("The preference \(address.key) is managed by an organization profile.")
        }
        let newValue = try value.object()
        let rootValue: Any?
        if let member = address.member {
            let existing = try root(address)
            guard existing == nil || existing is [String: Any] else {
                throw FnError.message("Unsupported system shortcut format.")
            }
            var dictionary = existing as? [String: Any] ?? [:]
            dictionary[member] = newValue
            rootValue = dictionary
        } else {
            rootValue = newValue
        }
        CFPreferencesSetValue(address.key as CFString, rootValue as CFPropertyList?, address.domain as CFString,
                              kCFPreferencesCurrentUser,
                              address.currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(address.domain as CFString, kCFPreferencesCurrentUser,
                                       address.currentHost ? kCFPreferencesCurrentHost : kCFPreferencesAnyHost),
              try read(address) == value else {
            throw FnError.message("Could not save or verify \(address.key).")
        }
    }
}
