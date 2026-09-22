import SwiftUI

// One model spans every step, so the steps are drawn here rather than in
// RootView, which only owns the model and the stack it is pushed onto.
struct AdjustFlowView: View {
    let step: Route
    let model: AdjustmentModel
    var onShowRecommendation: () -> Void = {}
    var onRouted: (UnstuckRoute) -> Void = { _ in }
    var onApplied: (String) -> Void = { _ in }
    var onLeave: (AdjustmentReturn) -> Void = { _ in }
    var onBack: () -> Void = {}

    var body: some View {
        switch step {
        case .adjustEntry: entry
        case .adjustTime: time
        case .adjustEquipment: equipment
        case .adjustContext: context
        case .adjustPain: pain
        case .adjustReview: review
        default: EmptyView()
        }
    }

    // The flow carries the reason, so its first screen is picked from that
    // rather than from four routes differing only in where they open.
    @ViewBuilder
    private var entry: some View {
        switch model.requestedReason {
        case .lessTime: time
        case .equipment: equipment
        case .pain: pain
        case .guidance, .other: context
        }
    }

    private var time: some View {
        AdjustTimeView(
            state: model.state,
            onSelectMinutes: model.selectMinutes,
            onTypeMinutes: model.typeMinutes,
            onShowRecommendation: onShowRecommendation,
            onKeepPlan: { onLeave(.reload) },
            onBack: onBack
        )
    }

    private var equipment: some View {
        AdjustEquipmentView(
            state: model.state,
            onSelectExercise: model.selectExercise,
            onToggleEquipment: model.toggleEquipment,
            onShowRecommendation: onShowRecommendation,
            onKeepPlan: { onLeave(.reload) },
            onBack: onBack
        )
    }

    private var context: some View {
        AdjustContextView(
            note: model.state.note,
            onTypeNote: model.typeNote,
            onChoose: { reason in
                Task { onRouted(await model.chooseFromContext(reason)) }
            },
            onBack: { onLeave(.reload) }
        )
    }

    private var pain: some View {
        AdjustPainView(
            onSaveAndFinishEarly: { onLeave(.finishEarly) },
            onReturn: { onLeave(.reload) },
            onBack: { onLeave(.reload) }
        )
    }

    // Nothing to show means the recommendation was never computed, and the step
    // behind asks again.
    @ViewBuilder
    private var review: some View {
        if let review = model.state.review {
            AdjustReviewView(
                review: review,
                applyError: model.state.applyError,
                onApply: model.apply,
                onKeepOriginal: { onLeave(.reload) },
                onFinishEarly: { onLeave(.finishEarly) },
                onBack: onBack
            )
            // Spent only once a change has actually landed, and before the flow
            // leaves, so a cancelled apply costs the included cycle nothing.
            .onChange(of: model.appliedProposalID) { _, proposalID in
                guard let proposalID else { return }
                model.consumeAppliedEvent()
                onApplied(proposalID)
            }
        }
    }
}
