import AppKit
import SwiftUI

/// Borderless, always-on-top panel that hosts the scratchpad.
final class ScratchpadPanel: NSPanel {
    /// Called for every mouse-down before normal dispatch. Return `true` to swallow the event.
    var mouseDownInterceptor: ((NSEvent) -> Bool)?
    /// Escape pressed with nothing else handling it.
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            if mouseDownInterceptor?(event) == true { return }
        default:
            break
        }
        super.sendEvent(event)
    }

    /// The inactive panel hugs the very bottom of the screen; never let AppKit nudge it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// Window content view that reports pointer activity over the panel, whether or not
/// the app is active. It only signals "look at the pointer again"; the hover decision
/// itself is made from the pointer position (see `PanelController.evaluateHover`).
final class PointerTrackingView: NSView {
    var onPointerActivity: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // `.inVisibleRect` follows the view as the window resizes, so it's added once.
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseEntered(with event: NSEvent) { onPointerActivity?() }
    override func mouseExited(with event: NSEvent) { onPointerActivity?() }
    override func mouseMoved(with event: NSEvent) { onPointerActivity?() }
}

/// Lets the first click on the (possibly inactive) panel land on the control under the pointer.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSImage {
    /// A stretchable rounded-rect mask for `NSVisualEffectView.maskImage`.
    static func roundedRectMask(cornerRadius radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
