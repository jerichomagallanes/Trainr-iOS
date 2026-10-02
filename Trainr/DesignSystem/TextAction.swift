import SwiftUI

struct TextAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.sectionTitle)
                .foregroundStyle(Color.brandStrong)
                .multilineTextAlignment(.leading)
                .frame(minHeight: ComponentHeight.medium, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TextAction(title: "View exercise guidance") {}
        .padding(Spacing.medium)
}
