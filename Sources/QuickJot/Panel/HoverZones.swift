import AppKit

/// Screen regions that decide the inactive panel's hover state.
///
/// The pointer raises the tab anywhere in `trigger` (a little larger than the visible tab),
/// and keeps it raised anywhere in `hold` (larger still). Because `hold` contains `trigger`
/// with room to spare, the pointer has to move clearly away before the tab drops again,
/// so it can't flicker between states near an edge.
struct HoverZones: Equatable {
    var trigger: NSRect
    var hold: NSRect

    static let none = HoverZones(trigger: .zero, hold: .zero)

    init(trigger: NSRect, hold: NSRect) {
        self.trigger = trigger
        self.hold = hold
    }

    init(collapsedFrame: NSRect, peekingFrame: NSRect, screenFrame: NSRect) {
        trigger = collapsedFrame
            .insetBy(dx: -Metrics.peekTriggerSlop, dy: -Metrics.peekTriggerSlop)
            .intersection(screenFrame)
        hold = peekingFrame
            .insetBy(dx: -Metrics.peekHoldSlop, dy: -Metrics.peekHoldSlop)
            .intersection(screenFrame)
    }

    /// Whether the tab should be raised for this pointer position.
    func wantsPeek(pointer: NSPoint, isPeeking: Bool) -> Bool {
        (isPeeking ? hold : trigger).contains(pointer)
    }
}
