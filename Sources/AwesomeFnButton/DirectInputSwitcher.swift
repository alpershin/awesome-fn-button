import AppKit
import ApplicationServices
import Carbon
import FnCore

final class DirectInputSwitcher {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var press = FnPress()
    private var workspaceObservers: [NSObjectProtocol] = []
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
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        workspaceObservers = [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification].map {
            NSWorkspace.shared.notificationCenter.addObserver(forName: $0, object: nil, queue: .main) { [weak self] _ in
                self?.resume()
            }
        }
    }

    func stop() {
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        workspaceObservers.removeAll()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        press.reset()
    }

    func resume() {
        press.reset()
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            resume()
            return
        }
        guard press.handle(type: type, keyCode: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags) else { return }
        do { try selectNextSource() }
        catch { onError?(error.localizedDescription) }
    }

    private func selectNextSource() throws {
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
    }

    deinit { stop() }
}
