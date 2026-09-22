import SwiftUI

struct OptionRow: View {
    let title: String
    var description: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.sectionTitle)
                        .foregroundStyle(Color.onSurface)
                    if let description {
                        Text(description)
                            .font(.body12)
                            .foregroundStyle(Color.onSurfaceMuted)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.oneOff(16, .semibold))
                    .foregroundStyle(Color.onSurfaceMuted)
            }
            .padding(.horizontal, Spacing.card)
            .padding(.vertical, 14)
            .frame(minHeight: ComponentHeight.large)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // strokeBorder draws inward, so the thicker selected edge costs no
        // layout and the label never shifts under the finger that chose it.
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(
                    isSelected ? Color.brandStrong : .outlineControl,
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: Spacing.tight) {
        OptionRow(title: "I have less time", description: "Keep the most relevant work.") {}
        OptionRow(
            title: "Equipment is unavailable",
            description: "Find a suitable alternative.",
            isSelected: true
        ) {}
        OptionRow(title: "Adjust today") {}
    }
    .padding(Spacing.medium)
}
