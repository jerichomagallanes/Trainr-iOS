import SwiftUI

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
                        .font(.oneOff(26))
                        .foregroundStyle(isSelected ? Color.brandOnSelected : .brand)
                        .frame(width: 35, height: 35)
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text(title)
                            .font(.body16)
                            .fontWeight(isSelected ? .bold : .medium)
                            .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                        Text(description)
                            .font(.body14)
                            .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurfaceMuted)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Spacing.snug)
                .padding(.trailing, Spacing.extraLarge)
            }
            .padding(Spacing.tight)
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
