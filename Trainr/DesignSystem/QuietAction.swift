import SwiftUI

struct QuietAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.labelMedium)
                .foregroundStyle(Color.onSurfaceMuted)
                .frame(maxWidth: .infinity, minHeight: ComponentHeight.medium)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuietAction(title: "Keep today's plan") {}
        .padding(Spacing.medium)
}
