import SwiftUI

struct LocationCard: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.small) {
                Image(systemName: symbol)
                    .font(.oneOff(26))
                    .foregroundStyle(isSelected ? Color.brandOnSelected : .brand)
                    .frame(width: 35, height: 35)
                Text(title)
                    .font(.body16)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundStyle(isSelected ? Color.onSurfaceSelected : .onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 124)
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
