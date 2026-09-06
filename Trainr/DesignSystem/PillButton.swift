import SwiftUI

// A compact action that sits inside content rather than under it: the timer's
// controls, and anything else offered beside the thing it acts on.
struct PillButton: View {
    let title: String
    let systemImage: String
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.labelMedium)
                .foregroundStyle(filled ? Color.white : Color.slate800)
                .padding(.horizontal, Spacing.medium)
                .frame(height: ComponentHeight.chip)
                .background(filled ? Color.slate800 : Color.white, in: .capsule)
                .overlay {
                    if !filled {
                        Capsule().strokeBorder(Color.slate800, lineWidth: 1)
                    }
                }
                .contentShape(.capsule)
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
