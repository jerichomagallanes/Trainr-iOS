import SwiftUI

// A note is worth leaving whatever happened, so the card stands on its own and
// the adjustment question joins it only when one is still unanswered. Drawn
// unconditionally: a view that renders nothing never runs the task that asks.
struct FeedbackOffer: View {

    @State private var model: FeedbackPromptModel
    private let onLeaveNote: () -> Void
    private let onOffer: (UUID) -> Void

    init(
        dependencies: AppDependencies,
        dayNumber: Int,
        weekNumber: Int?,
        onLeaveNote: @escaping () -> Void = {},
        onOffer: @escaping (UUID) -> Void = { _ in }
    ) {
        _model = State(
            initialValue: FeedbackPromptModel(
                dependencies: dependencies, dayNumber: dayNumber, weekNumber: weekNumber
            )
        )
        self.onLeaveNote = onLeaveNote
        self.onOffer = onOffer
    }

    var body: some View {
        card(model.pendingAdjustmentID)
            .task { model.load() }
    }

    private func card(_ adjustmentID: UUID?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.extraSmall) {
            Text(L10n.anythingToChangeTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.anythingToChangeBody)
                .font(.body14)
                .foregroundStyle(Color.onSurfaceMuted)
            if let adjustmentID {
                TextAction(title: L10n.tellUsHowItWent) { onOffer(adjustmentID) }
            }
            TextAction(title: L10n.leaveANote, action: onLeaveNote)
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
