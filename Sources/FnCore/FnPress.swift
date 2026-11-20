import CoreGraphics

/// Switch on physical Fn-down, and undo that switch when the press becomes a chord.
public struct FnPress {
    public enum Action: Equatable {
        case none, switchInputSource, restoreInputSource, finish
    }

    private var pressed = false
    private var canUndo = false

    public init() {}

    public mutating func reset() {
        pressed = false
        canUndo = false
    }

    public mutating func handle(type: CGEventType, keyCode: Int64, flags: CGEventFlags) -> Action {
        guard type == .keyDown || type == .flagsChanged else { return .none }
        if type == .keyDown || keyCode != 63 {
            guard pressed else { return .none }
            if !flags.contains(.maskSecondaryFn) {
                reset()
                return .finish
            }
            guard canUndo else { return .none }
            canUndo = false
            return .restoreInputSource
        }
        if flags.contains(.maskSecondaryFn) {
            guard !pressed else { return .none }
            pressed = true
            let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
            canUndo = flags.intersection(modifiers).isEmpty
            return canUndo ? .switchInputSource : .none
        }
        guard pressed else { return .none }
        reset()
        return .finish
    }
}
