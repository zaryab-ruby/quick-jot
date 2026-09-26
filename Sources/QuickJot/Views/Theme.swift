import AppKit
import SwiftUI

enum Theme {
    static let accentNS = NSColor(srgbRed: 0.24, green: 0.51, blue: 0.96, alpha: 1)
    static let accent = Color(nsColor: accentNS)
    static let danger = Color(red: 0.92, green: 0.3, blue: 0.3)
    static let success = Color(red: 0.35, green: 0.8, blue: 0.5)

    static let textNS = NSColor(white: 1, alpha: 0.92)
    static let text = Color(nsColor: textNS)
    static let secondary = Color.white.opacity(0.6)
    static let tertiary = Color.white.opacity(0.38)

    /// Lifts the HUD material to the lighter translucent gray of the design.
    static let tint = Color(white: 0.4, opacity: 0.42)
    static let hairline = Color.white.opacity(0.13)
    static let hover = Color.white.opacity(0.09)

    static let editorFont = NSFont.systemFont(ofSize: 12.5)
}
