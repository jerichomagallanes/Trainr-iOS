import SwiftUI

// The frames keep the outline on selected chips too.
struct ToggleChip: View {
    let text: String
    let isSelected: Bool
    var height: CGFloat = ComponentHeight.chip
    var horizontalPadding: CGFloat = Spacing.large
    // The LABEL fills, not the chip: a button hugs its label, so widening from
    // outside leaves the paint at label width with the text spilling past it.
    var fillsWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.body16)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(height: height)
                .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.surfaceSelected : .surfaceCard,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

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
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.surfaceSelected : .surfaceCard,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var labelColor: Color {
        if isSelected { .onSurfaceSelected } else if mutedWhenUnselected { .onSurfaceMuted } else { .onSurface }
    }
}

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
                    .foregroundStyle(isChecked ? Color.onSurfaceSelected : .onSurface)
                Spacer(minLength: Spacing.small)
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.oneOff(20))
                    .foregroundStyle(isChecked ? Color.onSurfaceSelected : .outlineControl)
            }
            .padding(Spacing.card)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .background(
            isChecked ? Color.surfaceSelected : .surfaceCard,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        // .isSelected rather than .isToggle: .isToggle reclassifies the element
        // as a switch, and every screen reaching a chip by name finds a button.
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
