import SwiftUI

struct AppTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            placeholder,
            text: $text,
            prompt: Text(placeholder).foregroundStyle(Color.placeholder),
            axis: .vertical
        )
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .focused($isFocused)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(Color.surfaceCard, in: RoundedRectangle(cornerRadius: CornerRadius.small))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(isFocused ? Color.focus : .outlineControl, lineWidth: 1)
            }
            .tint(.focus)
    }
}

#Preview {
    VStack(spacing: Spacing.small) {
        AppTextArea(placeholder: "Add any context you want Trainr to consider.", text: .constant(""))
        AppTextArea(placeholder: "Add context", text: .constant("The squat rack is taken."))
    }
    .padding(Spacing.medium)
}
