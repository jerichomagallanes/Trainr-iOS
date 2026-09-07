import SwiftUI

struct PillButton: View {
    let title: String
    let systemImage: String
    var filled = true
    let action: () -> Void

    private var content: Color { filled ? .white : .slate800 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.extraSmall) {
                Image(systemName: systemImage)
                    .font(.oneOff(14, .semibold))
                    .frame(width: 24, height: 24)
                Text(title)
                    .font(.labelLarge)
            }
            .foregroundStyle(content)
            .padding(.leading, 5)
            .padding(.trailing, Spacing.card)
            .frame(height: ComponentHeight.pill)
            .background(
                filled ? Color.orange500 : Color.white,
                in: .rect(cornerRadius: CornerRadius.medium)
            )
            .overlay {
                if !filled {
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .strokeBorder(Color.outlineGray, lineWidth: 1.5)
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
