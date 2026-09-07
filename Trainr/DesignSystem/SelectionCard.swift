import SwiftUI

// One choice in a stacked list: title, optional supporting line, and the radio
// dot pinned to the frame's corner. Selecting inverts the card.
struct SelectionCard: View {
    let title: String
    var description: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RadioDot(isSelected: isSelected)
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text(title)
                        .font(.body16)
                        .fontWeight(isSelected ? .bold : .medium)
                        .foregroundStyle(isSelected ? Color.white : .slate800)
                    if let description {
                        Text(description)
                            .font(.body14)
                            .foregroundStyle(isSelected ? Color.white : .textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5)
                .padding(.vertical, Spacing.snug)
                .padding(.trailing, Spacing.extraLarge)
            }
            .padding(Spacing.tight)
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
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

#Preview {
    VStack(spacing: Spacing.card) {
        SelectionCard(title: "Intermediate",
                      description: "Working out regularly for 6+ months.",
                      isSelected: true) {}
        SelectionCard(title: "Beginner",
                      description: "New to working out or getting back into it.",
                      isSelected: false) {}
    }
    .padding(Spacing.medium)
}
