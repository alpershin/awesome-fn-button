import CoreGraphics

/// Only a standalone physical Fn press may switch languages; Fn chords pass through.
public struct FnPress {
    private var pressed = false
    private var usedWithAnotherKey = false

    public init() {}

    public mutating func reset() {
        pressed = false
        usedWithAnotherKey = false
    }

    public mutating func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Bool {
        if type == .keyDown {
            if !flags.contains(.maskSecondaryFn) { reset() }
            else if pressed { usedWithAnotherKey = true }
            return false
        }
        guard type == .flagsChanged else { return false }
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        if keyCode != 63 {
            if !flags.contains(.maskSecondaryFn) { reset() }
            else if pressed { usedWithAnotherKey = true }
            return false
        }
        if flags.contains(.maskSecondaryFn) {
            if !pressed {
                pressed = true
                usedWithAnotherKey = !flags.intersection(modifiers).isEmpty
            }
            return false
        }
        let shouldSwitch = pressed && !usedWithAnotherKey && flags.intersection(modifiers).isEmpty
        reset()
        return shouldSwitch
    }
}
