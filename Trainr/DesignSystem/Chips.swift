import SwiftUI

// A compact either-or choice. The frames keep the outline on selected chips too.
struct ToggleChip: View {
    let text: String
    let isSelected: Bool
    var height: CGFloat = ComponentHeight.chip
    var horizontalPadding: CGFloat = Spacing.large
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body16)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.white : .slate800)
                .lineLimit(1)
                // Phones narrower than the design frame get a smaller label,
                // never an ellipsis.
                .minimumScaleFactor(0.75)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.slate800 : .white,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// A full-width option row with the radio dot at its trailing edge.
struct RadioChip: View {
    let text: String
    let isSelected: Bool
    var height: CGFloat = ComponentHeight.option
    var mutedWhenUnselected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.body16)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: Spacing.small)
                RadioDot(isSelected: isSelected)
            }
            .padding(.leading, Spacing.card)
            .padding(.trailing, Spacing.tight)
            .frame(height: height)
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.slate800 : .white,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var labelColor: Color {
        if isSelected { .white } else if mutedWhenUnselected { .textMuted } else { .slate800 }
    }
}

// A full-width row that can be on together with its neighbours.
struct CheckboxChip: View {
    let text: String
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack {
                Text(text)
                    .font(.body16)
                    .fontWeight(.medium)
                    .foregroundStyle(isChecked ? Color.white : .slate800)
                Spacer(minLength: Spacing.small)
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isChecked ? Color.white : .outlineGray)
            }
            .padding(Spacing.card)
        }
        .buttonStyle(.plain)
        .background(
            isChecked ? Color.slate800 : .white,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
