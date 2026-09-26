import SwiftUI

/// Small borderless icon button used across the panel chrome.
struct IconButton: View {
    let systemName: String
    let label: String
    var tint: Color? = nil
    var rotation: Angle = .zero
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .semibold))
                .rotationEffect(rotation)
                .foregroundStyle(tint ?? Color.white.opacity(isHovering ? 0.9 : 0.5))
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isHovering ? Theme.hover : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

/// Compact text button for the inline delete confirmation.
struct PillButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isDestructive ? Color.white : Theme.text)
            .padding(.horizontal, 9)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isDestructive ? Theme.danger : Color.white.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
