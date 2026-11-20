import AppKit
import ApplicationServices
import Carbon
import FnCore

final class DirectInputSwitcher {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var press = FnPress()
    private var backgroundActivity: NSObjectProtocol?
    private var pendingSwitch: (original: TISInputSource, selected: TISInputSource)?
    var onError: ((String) -> Void)?

    func start(requestPermission: Bool = false) throws {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: requestPermission] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            stop()
            throw FnError.message("Allow Awesome Fn Button in System Settings → Privacy & Security → Accessibility, then return to the app.")
        }
        guard tap == nil else { return }
        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                         options: .defaultTap, eventsOfInterest: mask,
                                         callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let switcher = Unmanaged<DirectInputSwitcher>.fromOpaque(context).takeUnretainedValue()
            switcher.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw FnError.message("Could not monitor Fn. Check Accessibility permission, then reopen the app.")
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            throw FnError.message("Could not start the Fn monitor.")
        }
        self.tap = tap
        self.source = source
        press.reset()
        pendingSwitch = nil
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        // Keep key handling responsive with no windows, while still allowing system sleep.
        backgroundActivity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                                   reason: "Respond to Fn language-switching taps in the background")
    }

    func stop() {
        if let backgroundActivity { ProcessInfo.processInfo.endActivity(backgroundActivity) }
        backgroundActivity = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        press.reset()
        pendingSwitch = nil
    }

    func resume() {
        press.reset()
        pendingSwitch = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resume()
            return
        }
        let action = press.handle(type: type, keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags)
        do {
            switch action {
            case .none: break
            case .switchInputSource:
                pendingSwitch = nil
                pendingSwitch = try selectNextSource()
            case .restoreInputSource:
                let previous = pendingSwitch
                pendingSwitch = nil
                if let previous {
                    let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
                    // Do not overwrite an input source selected elsewhere during the press.
                    if CFEqual(current, previous.selected) {
                        let result = TISSelectInputSource(previous.original)
                        guard result == noErr else { throw FnError.message("Could not restore input source for the Fn combination (\(result)).") }
                    }
                }
            case .finish: pendingSwitch = nil
            }
        }
        catch { onError?(error.localizedDescription) }
    }

    private func selectNextSource() throws -> (original: TISInputSource, selected: TISInputSource) {
        let filter = [kTISPropertyInputSourceCategory!: kTISCategoryKeyboardInputSource!] as CFDictionary
        let sources = (TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []).filter {
            guard let capable = TISGetInputSourceProperty($0, kTISPropertyInputSourceIsSelectCapable) else { return false }
            return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(capable).takeUnretainedValue())
        }
        guard sources.count >= 2 else { throw FnError.message("Add at least two input sources in Keyboard settings.") }
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let index = sources.firstIndex { CFEqual($0, current) }
        let next = sources[index.map { ($0 + 1) % sources.count } ?? 0]
        let result = TISSelectInputSource(next)
        guard result == noErr else { throw FnError.message("Could not switch input source (\(result)).") }
        return (current, next)
    }

    deinit { stop() }
}
