import SwiftUI

// A field-shaped menu. Shows its placeholder, muted, until something has been
// chosen: a dropdown that opens on a real-looking value has answered the
// question on the client's behalf.
struct DropdownField: View {
    let selectedValue: String
    let options: [String]
    // Shown, muted, when nothing has been chosen yet, the same way the text
    // fields show theirs.
    var placeholder = ""
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack {
                Text(selectedValue.isBlank ? placeholder : selectedValue)
                    .font(.labelMedium)
                    .foregroundStyle(selectedValue.isBlank ? Color.textMuted : .slate800)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.horizontal, Spacing.medium)
            .frame(height: ComponentHeight.medium)
            .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.outlineGray, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
