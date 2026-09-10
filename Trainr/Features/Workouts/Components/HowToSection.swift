import SwiftUI

// One place to learn the movement: the written steps the catalog owns, and the
// tutorial for it, behind a single disclosure. Two rows saying "how do I do
// this" read as two different answers when there is only one.
struct HowToSection<Video: View>: View {
    let steps: [String]
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var video: Video

    private static var numberColumn: CGFloat { 24 }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.card) {
            Button(action: onToggle) {
                HStack(spacing: 5) {
                    Text(isExpanded ? L10n.hideHowToPerform : L10n.showHowToPerform)
                        .font(.labelLarge)
                    Image(systemName: "chevron.up")
                        .font(.oneOff(14, .semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                }
                .foregroundStyle(Color.onSurface)
                .padding(.horizontal, Spacing.tight)
                .frame(height: 27)
                .background(Color.surfaceSunken, in: .rect(cornerRadius: CornerRadius.medium))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Numbered here rather than in the data: the catalog stores the
                // step, not its position, so reordering never leaves two threes.
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 0) {
                        Text("\(index + 1)")
                            .font(.body14)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.onSurfaceMuted)
                            .frame(width: Self.numberColumn, alignment: .leading)
                        Text(step)
                            .font(.body14)
                            .lineSpacing(4)
                            .foregroundStyle(Color.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, Spacing.extraSmall)
                }

                video
            }
        }
    }
}

extension HowToSection where Video == EmptyView {
    init(steps: [String], isExpanded: Bool, onToggle: @escaping () -> Void) {
        self.init(steps: steps, isExpanded: isExpanded, onToggle: onToggle) { EmptyView() }
    }
}
