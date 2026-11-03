import SwiftUI

// One model spans every step, so the steps are drawn here rather than in
// RootView, which only owns the model and the stack it is pushed onto.
struct OnboardingFlowView: View {
    let step: Route
    let model: OnboardingModel
    // Editing one answer goes back to the review rather than on to the next
    // question, which is the caller's stack to decide.
    var onStep: (Bool, Route) -> Void = { _, _ in }
    var onEdit: (Route) -> Void = { _ in }
    // Writing a plan is what the gate asks about, so the answer is given where
    // the gate lives.
    var onConfirm: (Bool, Bool) -> Void = { _, _ in }
    var onGenerated: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        switch step {
        case .basicInfo(let editing): basicInfo(editing)
        case .bodyMetrics(let editing): bodyMetrics(editing)
        case .fitnessGoal(let editing): fitnessGoal(editing)
        case .workoutSetup(let editing): workoutSetup(editing)
        case .limitations(let editing): limitations(editing)
        case .review(let fromPlan, let profileOnly): review(fromPlan, profileOnly)
        case .generating: generating
        default: EmptyView()
        }
    }

    private func basicInfo(_ editing: Bool) -> some View {
        BasicInfoView(
            initial: model.filled(for: .basicInfo, editing: editing),
            isEditing: editing,
            onNext: { firstName, age, gender, experience in
                model.updateBasicInfo(
                    firstName: firstName, age: age, gender: gender, experience: experience)
                onStep(editing, .bodyMetrics(editing: false))
            },
            onBack: onBack
        )
    }

    private func bodyMetrics(_ editing: Bool) -> some View {
        BodyMetricsView(
            initial: model.filled(for: .bodyMetrics, editing: editing),
            age: model.profile.age,
            isEditing: editing,
            // Only while answering: editing a stored profile has a profile to
            // go back to, and a half-typed figure must not outlive the screen.
            inProgress: editing ? nil : model.bodyMetricsInProgress(),
            onEntryChanged: { if !editing { model.rememberBodyMetrics($0) } },
            onNext: { height, weight, units in
                model.updateBodyMetrics(height: height, weight: weight, units: units)
                onStep(editing, .fitnessGoal(editing: false))
            },
            onBack: onBack
        )
    }

    private func fitnessGoal(_ editing: Bool) -> some View {
        FitnessGoalView(
            initial: model.filled(for: .goals, editing: editing),
            isEditing: editing,
            onNext: { goal in
                model.updateFitnessGoal(goal)
                onStep(editing, .workoutSetup(editing: false))
            },
            onBack: onBack
        )
    }

    private func workoutSetup(_ editing: Bool) -> some View {
        WorkoutSetupView(
            stockedEquipment: model.stockedEquipment,
            initial: model.filled(for: .setup, editing: editing),
            isEditing: editing,
            bodyUnits: model.profile.bodyUnitSystem,
            longestSessionMinutes: { equipment, days, duration in
                await model.longestSessionMinutes(
                    equipment: equipment, daysPerWeek: days, duration: duration)
            },
            onNext: { equipment, liftingUnits, days, duration in
                model.updateWorkoutSetup(
                    equipment: equipment, liftingUnits: liftingUnits,
                    daysPerWeek: days, duration: duration)
                onStep(editing, .limitations(editing: false))
            },
            onBack: onBack
        )
    }

    private func limitations(_ editing: Bool) -> some View {
        LimitationsView(
            initial: model.filled(for: .limitations, editing: editing),
            isEditing: editing,
            onNext: { injuries in
                model.updateLimitations(injuries: injuries)
                onStep(editing, .review(fromPlan: false, profileOnly: false))
            },
            onBack: onBack
        )
    }

    private func review(_ fromPlan: Bool, _ profileOnly: Bool) -> some View {
        ReviewView(
            profile: model.profile,
            isRegenerating: fromPlan,
            isProfileUpdate: profileOnly,
            onConfirm: { onConfirm(fromPlan, profileOnly) },
            onBack: onBack,
            onEdit: onEdit
        )
    }

    private var generating: some View {
        GeneratingView(
            isReady: model.isCompleted,
            onStart: { model.saveUserProfile() },
            onDone: onGenerated,
            failure: model.generationFailure,
            failureCount: model.failureCount,
            onRetry: { model.saveUserProfile() },
            // Nothing was written yet, and cancelRun stops the abandoned run
            // from writing one.
            onGiveUp: {
                model.cancelRun()
                onBack()
            },
            giveUpLabel: L10n.backToProfile
        )
    }
}
