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
    // A picture before the label, which also pulls the label to the start: a
    // thumbnail chip reads as a row, not a centred pill.
    var leading: Image?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.tight) {
                if let leading {
                    leading
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .frame(width: 52, height: 52)
                        .background(Color.surfaceSunken, in: Circle())
                        .overlay(Circle().strokeBorder(Color.outlineControl, lineWidth: 1.5))
                }
                Text(text)
                    .font(.body16)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                    .lineLimit(leading == nil ? 1 : 2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.leading)
                if leading != nil { Spacer(minLength: 0) }
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: fillsWidth || leading != nil ? .infinity : nil)
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
        // The reader has to hear whether the box is ticked, and a Toggle says it
        // in the platform's own words rather than a string of ours to translate.
        .accessibilityRepresentation { Toggle(text, isOn: $isChecked) }
    }
}

// One chip for every place equipment is chosen, so the thumbnail, the disc and
// the row height cannot drift between the setup screen and Unstuck. The disc is
// sunken, not white: in dark a white disc on a card reads as a hole punched
// through it. The artwork carries its own light and dark colours.
struct EquipmentChoiceChip: View {
    let equipment: Equipment
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        ToggleChip(
            text: label,
            isSelected: isSelected,
            height: 72,
            horizontalPadding: Spacing.tight,
            leading: equipment.icon,
            action: action
        )
    }
}

extension Equipment {
    // Decorative: the chip's label is its text, and the UI tests find it by that.
    var icon: Image { Image(decorative: iconName) }

    private var iconName: String {
        switch self {
        case .none: "EquipmentNone"
        case .barbell: "EquipmentBarbell"
        case .dumbbell: "EquipmentDumbbell"
        case .kettlebell: "EquipmentKettlebell"
        case .machine: "EquipmentMachine"
        case .plate: "EquipmentPlate"
        case .resistanceBand: "EquipmentResistanceBand"
        case .suspensionBand: "EquipmentSuspensionBand"
        case .other: "EquipmentOther"
        }
    }
}

// Two to a row, built eagerly. A lazy grid materialises its children on layout,
// so for a frame after the screen appears the chips are not in the accessibility
// tree at all, and a tap that lands in that frame finds nothing. Nine fixed
// choices have no need to be lazy.
struct EquipmentChoiceGrid: View {
    let options: [(Equipment, String)]
    let isSelected: (Equipment) -> Bool
    let onTap: (Equipment) -> Void

    var body: some View {
        VStack(spacing: Spacing.tight) {
            ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { start in
                HStack(spacing: Spacing.tight) {
                    ForEach(options[start..<min(start + 2, options.count)], id: \.0) { equipment, label in
                        EquipmentChoiceChip(
                            equipment: equipment,
                            label: label,
                            isSelected: isSelected(equipment)
                        ) {
                            onTap(equipment)
                        }
                    }
                    if start + 1 >= options.count {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
