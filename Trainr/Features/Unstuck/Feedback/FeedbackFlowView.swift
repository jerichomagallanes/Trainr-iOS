import SwiftUI

// One model spans every step, so the steps are drawn here rather than in
// RootView, which only owns the model and the stack it is pushed onto.
struct FeedbackFlowView: View {
    let step: Route
    let model: AdjustmentFeedbackModel
    var onDetail: () -> Void = {}
    var onSaved: (FeedbackAnswer?) -> Void = { _ in }
    var onSaveForLater: () -> Void = {}
    var onOpenGuidance: (String) -> Void = { _ in }
    var onLeave: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        switch step {
        case .adjustmentFeedback: question
        case .feedbackDetail: detail
        case .feedbackOutcome: outcome
        case .feedbackPain: pain
        default: EmptyView()
        }
    }

    // Which question this is depends on the stored proposal, so nothing is
    // asked until it has been read.
    @ViewBuilder
    private var question: some View {
        if model.state.isLoaded {
            AdjustmentFeedbackView(
                state: model.state,
                onChoose: choose,
                onNotNow: model.dismiss,
                onBack: onBack
            )
            .onChange(of: model.pendingSavedEvent) { _, event in routeOnSave(event) }
            .onAppear(perform: leaveIfAnswered)
        }
    }

    private var detail: some View {
        FeedbackDetailView(
            onChoose: choose,
            // Nothing is written, so the offer stays pending on the screen that
            // made it rather than nagging from somewhere else.
            onSaveForLater: onSaveForLater,
            onBack: onBack
        )
        .onChange(of: model.pendingSavedEvent) { _, event in routeOnSave(event) }
        .onAppear(perform: leaveIfAnswered)
    }

    // The answer is recorded, so every way out of these two leads on rather
    // than back to a question that has already been answered.
    private var outcome: some View {
        FeedbackOutcomeView(
            state: model.state,
            onDone: onLeave,
            onOpenGuidance: {
                guard let key = model.state.guidanceKey else { return }
                onOpenGuidance(key)
            },
            onBack: onLeave
        )
    }

    private var pain: some View {
        AdjustPainView(canFinishEarly: false, onReturn: onLeave, onBack: onLeave)
    }

    // The interactive back-swipe pops without running the chevron's handler, so
    // an answered question is left here rather than re-drawn with every control
    // dead.
    private func leaveIfAnswered() {
        if model.isSaved { onLeave() }
    }

    private func choose(_ choice: FeedbackChoice) {
        switch choice {
        case .answer(let answer): model.answer(answer)
        case .askDetail: onDetail()
        }
    }

    private func routeOnSave(_ event: FeedbackSavedEvent?) {
        guard let event else { return }
        model.consumeSavedEvent()
        onSaved(event.answer)
    }
}
