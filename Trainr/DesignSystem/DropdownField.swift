import SwiftUI

struct DropdownField: View {
    let selectedValue: String
    let options: [String]
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
                    .foregroundStyle(selectedValue.isBlank ? Color.onSurfaceMuted : .onSurface)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.oneOff(12))
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            .padding(.horizontal, Spacing.medium)
            .frame(height: ComponentHeight.medium)
            .background(Color.surfaceCard, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.outlineControl, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}
