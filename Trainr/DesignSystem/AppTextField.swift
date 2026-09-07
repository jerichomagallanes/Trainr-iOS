import SwiftUI

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            placeholder,
            text: $text,
            prompt: Text(placeholder).foregroundStyle(Color.textMuted.opacity(0.6))
        )
            .font(.body16)
            .foregroundStyle(Color.slate800)
            .keyboardType(keyboard)
            .focused($isFocused)
            .padding(.horizontal, Spacing.tight)
            .frame(height: ComponentHeight.field)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(isFocused ? Color.orange500 : .outlineGray, lineWidth: 1)
            }
            .tint(.orange500)
    }
}

#Preview {
    VStack(spacing: Spacing.small) {
        AppTextField(placeholder: "170", text: .constant(""))
        AppTextField(placeholder: "First name", text: .constant("Jericho"))
    }
    .padding(Spacing.medium)
}
