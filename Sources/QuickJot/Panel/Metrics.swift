import Foundation

enum Metrics {
    static let panelSize = CGSize(width: 360, height: 300)
    static let cornerRadius: CGFloat = 10

    static let headerHeight: CGFloat = 30
    static let tabStripHeight: CGFloat = 28
    static let bottomBarHeight: CGFloat = 30

    /// While inactive, the panel fills the Dock's band at the bottom of the screen so its
    /// top lines up with the Dock's top (where maximized windows end). This is the least
    /// it shows when the Dock is hidden or on the side: the header plus a sliver of tabs.
    static let minimumCollapsedReveal: CGFloat = 38
    /// How much further it slides up while the pointer hovers the inactive panel.
    static let hoverLift: CGFloat = 34

    /// The pointer starts the hover slide-up anywhere within this distance of the inactive tab…
    static let peekTriggerSlop: CGFloat = 16
    /// …and keeps it up while within this distance of the raised tab. Keeping this
    /// larger than the trigger slop is what stops the panel from jittering at the edges.
    static let peekHoldSlop: CGFloat = 32
    /// Grace period after the pointer leaves before the tab slides back down.
    static let hoverCollapseDelay: TimeInterval = 0.18
}
