import SwiftUI

struct PillButton: View {
    let title: String
    let systemImage: String
    var filled = true
    let action: () -> Void

    // A point size that holds a glyph has to grow with the text, or the icon is
    // a blob beside a label twice its height.
    @ScaledMetric(relativeTo: .subheadline) private var iconSide: CGFloat = 24

    private var content: Color { filled ? .onBrand : .onSurface }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.extraSmall) {
                Image(systemName: systemImage)
                    .font(.oneOff(14, .semibold))
                    .frame(width: iconSide, height: iconSide)
                Text(title)
                    .font(.labelLarge)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(content)
            .padding(.leading, 5)
            .padding(.trailing, Spacing.card)
            .padding(.vertical, 2)
            // A floor rather than a height: the label grows with the text
            // setting and would otherwise be cut off top and bottom.
            .frame(minHeight: ComponentHeight.pill)
            .background(
                filled ? Color.brandStrong : Color.surfaceRaised,
                in: .rect(cornerRadius: CornerRadius.medium)
            )
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(Color.outlineControl, lineWidth: 1.5)
                }
            }
            .contentShape(.rect(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: Spacing.tight) {
        PillButton(title: "Pause", systemImage: "pause.fill", action: {})
        PillButton(title: "Reset", systemImage: "arrow.clockwise", filled: false, action: {})
    }
    .padding(Spacing.screen)
}
