import SwiftUI

// A selection card with the option's symbol leading it. The frames export every
// option icon in the brand orange, whatever the card's state.
struct IconCard: View {
    let symbol: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                RadioDot(isSelected: isSelected)
                HStack(spacing: Spacing.tight) {
                    Image(systemName: symbol)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.orange500)
                        .frame(width: 35, height: 35)
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text(title)
                            .font(.body16)
                            .fontWeight(isSelected ? .bold : .medium)
                            .foregroundStyle(isSelected ? Color.white : .slate800)
                        Text(description)
                            .font(.body14)
                            .foregroundStyle(isSelected ? Color.white : .textMuted)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 5)
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
