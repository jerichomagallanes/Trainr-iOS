import SwiftUI

// The design's 42pt field: a plain text field in a drawn border, orange when
// it holds the cursor.
struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            placeholder,
            text: $text,
            // The muted text colour at six tenths, as the frames draw a hint.
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
