import SwiftUI

// Draws nothing until the stored day turns out to have an adjustment nobody has
// been asked about, so a saved session is never held up by the question.
struct FeedbackOffer: View {

    enum Style {
        case link
        case card
    }

    @State private var model: FeedbackPromptModel
    private let style: Style
    private let onOffer: (UUID) -> Void

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int?,
        style: Style = .link,
        onOffer: @escaping (UUID) -> Void = { _ in }
    ) {
        _model = State(
            initialValue: FeedbackPromptModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        self.style = style
        self.onOffer = onOffer
    }

    var body: some View {
        Group {
            if let adjustmentID = model.pendingAdjustmentID {
                switch style {
                case .link: action(adjustmentID)
                case .card: card(adjustmentID)
                }
            }
        }
        .task { model.load() }
    }

    private func action(_ adjustmentID: UUID) -> some View {
        TextAction(title: L10n.tellUsHowItWent) { onOffer(adjustmentID) }
            .padding(.top, Spacing.card)
    }

    private func card(_ adjustmentID: UUID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(L10n.anythingToChangeTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.anythingToChangeBody)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
            TextAction(title: L10n.tellUsHowItWent) { onOffer(adjustmentID) }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.top, Spacing.screen)
    }
}
