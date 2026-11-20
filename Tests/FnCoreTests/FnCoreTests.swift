import XCTest
import CoreGraphics
@testable import FnCore

private final class MemoryPreferences: PreferenceStore {
    var values: [PreferenceAddress: PreferenceValue] = [:]
    var failNextWriteAt: PreferenceAddress?
    var writes = 0

    func read(_ address: PreferenceAddress) throws -> PreferenceValue {
        if let value = values[address] { return value }
        if address.member == nil && address.key == "AppleSymbolicHotKeys" {
            var entries: [String: Any] = [:]
            for (key, value) in values where key.domain == address.domain && key.currentHost == address.currentHost {
                if let member = key.member { entries[member] = try value.object() }
            }
            return try PreferenceValue(entries)
        }
        return try PreferenceValue(nil)
    }

    func write(_ value: PreferenceValue, at address: PreferenceAddress) throws {
        if failNextWriteAt == address {
            failNextWriteAt = nil
            throw FnError.message("Simulated write failure")
        }
        values[address] = value
        writes += 1
    }
}

final class FnCoreTests: XCTestCase {
    private var directory: URL!
    private var backupURL: URL { directory.appendingPathComponent("backup.json") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func hotkey(_ parameters: [Int], enabled: Bool = true) throws -> PreferenceValue {
        try PreferenceValue(["enabled": enabled, "value": ["type": "standard", "parameters": parameters]])
    }

    func testDetectsExplicitFnAndDoubleTapButPreservesArrowsFunctionKeysAndControlSpace() {
        XCTAssertTrue(Diagnostics.isFnShortcut([113, 12, 8388608]))
        XCTAssertTrue(Diagnostics.isFnShortcut([8388608, -8388609, 0]))
        XCTAssertFalse(Diagnostics.isFnShortcut([32, 49, 262144]))
        XCTAssertFalse(Diagnostics.isFnShortcut([65535, 123, 8650752]))
        XCTAssertFalse(Diagnostics.isFnShortcut([65535, 103, 8388608]))
        XCTAssertFalse(Diagnostics.isFnShortcut([1048576, -1048577, 0]))
        XCTAssertFalse(Diagnostics.isFnShortcut([]))
    }

    func testScanIsReadOnlyAndOnlyPlansKnownConflicts() throws {
        let store = MemoryPreferences()
        store.values[.hotkeys(member: "190")] = try hotkey([113, 12, 8388608])
        store.values[.hotkeys(member: "60")] = try hotkey([32, 49, 262144])
        store.values[.hotkeys(member: "164")] = try hotkey([8388608, -8388609, 0], enabled: false)
        let report = try Diagnostics.scan(store: store, sources: ["ABC", "Russian"])
        XCTAssertEqual(report.changes.map(\.address), [.fn(), .hotkeys(member: "190")])
        XCTAssertEqual(store.writes, 0)
    }

    func testApplyRestorePreservesAbsentFnAndUnrelatedHotkey() throws {
        let store = MemoryPreferences()
        let fnHotkey = try hotkey([113, 12, 8388608])
        store.values[.hotkeys(member: "190")] = fnHotkey
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["ABC", "Russian"])
        try config.apply(report.changes, inputSourceCount: 2)
        XCTAssertTrue(config.hasBackup)
        XCTAssertEqual(try store.read(.fn()), try PreferenceValue(1))
        let unrelated = try hotkey([32, 49, 262144])
        store.values[.hotkeys(member: "60")] = unrelated
        XCTAssertTrue(try config.restore().isEmpty)
        XCTAssertNil(try store.read(.fn()).object())
        XCTAssertEqual(try store.read(.hotkeys(member: "190")), fnHotkey)
        XCTAssertEqual(try store.read(.hotkeys(member: "60")), unrelated)
        XCTAssertFalse(config.hasBackup)
    }

    func testPartialFailureRollsBackEarlierWrites() throws {
        let store = MemoryPreferences()
        store.values[.hotkeys(member: "190")] = try hotkey([113, 12, 8388608])
        store.failNextWriteAt = .hotkeys(member: "190")
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["ABC", "Russian"])
        XCTAssertThrowsError(try config.apply(report.changes, inputSourceCount: 2))
        XCTAssertNil(try store.read(.fn()).object())
        XCTAssertFalse(config.hasBackup)
    }

    func testRestoreDoesNotOverwriteExternalChangesOrDiscardBackup() throws {
        let store = MemoryPreferences()
        let config = Configuration(store: store, backupURL: backupURL)
        try config.apply(Diagnostics.scan(store: store, sources: ["A", "B"]).changes, inputSourceCount: 2)
        store.values[.fn()] = try PreferenceValue(2)
        XCTAssertEqual(try config.restore().count, 1)
        XCTAssertEqual(try store.read(.fn()), try PreferenceValue(2))
        XCTAssertTrue(config.hasBackup)
        XCTAssertThrowsError(try config.apply([], inputSourceCount: 2))
    }

    func testRejectsStalePlanAndTooFewInputSourcesBeforeWriting() throws {
        let store = MemoryPreferences()
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["A", "B"])
        XCTAssertThrowsError(try config.apply(report.changes, inputSourceCount: 1))
        store.values[.fn()] = try PreferenceValue(3)
        XCTAssertThrowsError(try config.apply(report.changes, inputSourceCount: 2))
        XCTAssertEqual(store.writes, 0)
        XCTAssertFalse(config.hasBackup)
    }

    func testExistingBackupIsNeverOverwritten() throws {
        let store = MemoryPreferences()
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["A", "B"])
        try config.apply(report.changes, inputSourceCount: 2)
        let originalBackup = try Data(contentsOf: backupURL)
        XCTAssertThrowsError(try config.apply(report.changes, inputSourceCount: 2))
        XCTAssertEqual(try Data(contentsOf: backupURL), originalBackup)
    }

    func testMalformedBackupBlocksRestoreAndStaysAvailable() throws {
        try Data("not a backup".utf8).write(to: backupURL)
        let store = MemoryPreferences()
        let config = Configuration(store: store, backupURL: backupURL)
        XCTAssertThrowsError(try config.restore())
        XCTAssertTrue(config.hasBackup)
        XCTAssertEqual(store.writes, 0)
    }

    func testHostSpecificOverrideIsPlannedAndRestored() throws {
        let store = MemoryPreferences()
        store.values[.fn(currentHost: true)] = try PreferenceValue(2)
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["A", "B"])
        XCTAssertEqual(report.changes.count, 2)
        try config.apply(report.changes, inputSourceCount: 2)
        XCTAssertTrue(try config.restore().isEmpty)
        XCTAssertEqual(try store.read(.fn(currentHost: true)), try PreferenceValue(2))
    }

    func testDirectModeDisablesNativePickerAndRestoresLegacyAssignment() throws {
        let store = MemoryPreferences()
        store.values[.fn()] = try PreferenceValue(1)
        store.values[.fn(currentHost: true)] = try PreferenceValue(1)
        let config = Configuration(store: store, backupURL: backupURL)
        let report = try Diagnostics.scan(store: store, sources: ["ABC", "Russian"], directSwitching: true)
        XCTAssertEqual(report.changes.count, 2)
        try config.apply(report.changes, inputSourceCount: 2)
        XCTAssertEqual(try store.read(.fn()), try PreferenceValue(0))
        XCTAssertEqual(try store.read(.fn(currentHost: true)), try PreferenceValue(0))
        XCTAssertTrue(try Diagnostics.scan(store: store, sources: ["ABC", "Russian"], directSwitching: true).changes.isEmpty)
        XCTAssertTrue(try config.restore().isEmpty)
        XCTAssertEqual(try store.read(.fn()), try PreferenceValue(1))
        XCTAssertEqual(try store.read(.fn(currentHost: true)), try PreferenceValue(1))
    }

    func testDirectModePreservesExternalFnChangesDuringRestore() throws {
        let store = MemoryPreferences()
        let config = Configuration(store: store, backupURL: backupURL)
        try config.apply(Diagnostics.scan(store: store, sources: ["A", "B"], directSwitching: true).changes, inputSourceCount: 2)
        store.values[.fn()] = try PreferenceValue(3)
        XCTAssertEqual(try config.restore().count, 1)
        XCTAssertEqual(try store.read(.fn()), try PreferenceValue(3))
        XCTAssertTrue(config.hasBackup)
    }

    func testFnSwitchesImmediatelyOnKeyDownAndNeverAgainOnRelease() {
        var press = FnPress()
        for _ in 0..<30 {
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .none)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .none)
        }
    }

    func testFnChordsUndoTheImmediateSwitchOnceAndIgnoreImplicitNavigationFlags() {
        for code: Int64 in [12, 96, 123, 117] {
            var press = FnPress()
            XCTAssertEqual(press.handle(type: .keyDown, keyCode: code, flags: .maskSecondaryFn), .none)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
            XCTAssertEqual(press.handle(type: .keyDown, keyCode: code, flags: .maskSecondaryFn), .restoreInputSource)
            XCTAssertEqual(press.handle(type: .keyDown, keyCode: code, flags: .maskSecondaryFn), .none)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
            XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
        }
    }

    func testHeldModifiersSuppressTheSwitchAndFollowingModifiersUndoIt() {
        var press = FnPress()
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: [.maskSecondaryFn, .maskShift]), .none)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 56, flags: [.maskSecondaryFn, .maskShift]), .restoreInputSource)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 56, flags: .maskSecondaryFn), .none)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
        press.reset()
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .none)
    }

    func testMissingFnReleaseDoesNotLeaveTheNextTapStuckAfterTyping() {
        var press = FnPress()
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
        XCTAssertEqual(press.handle(type: .keyDown, keyCode: 0, flags: []), .finish)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
    }

    func testTypingAfterFnReleaseKeepsTheNewLanguage() {
        var press = FnPress()
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: .maskSecondaryFn), .switchInputSource)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 63, flags: []), .finish)
        XCTAssertEqual(press.handle(type: .keyDown, keyCode: 0, flags: []), .none)
        XCTAssertEqual(press.handle(type: .flagsChanged, keyCode: 56, flags: .maskShift), .none)
    }
}
