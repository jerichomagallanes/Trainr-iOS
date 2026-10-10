import Foundation
import Observation

// What the measurements step currently has typed in it, in the units it is
// showing. Text rather than numbers: a part-typed "5" is not a height yet. The
// swaps carry the measurements behind that text, which the index is read from.
nonisolated struct BodyMetricsEntry: Equatable, Sendable {
    var height: String
    var weight: String
    var useMetric: Bool
    var heightSwap = BodyMetricsConverter.UnitSwap()
    var weightSwap = BodyMetricsConverter.UnitSwap()
}

enum OnboardingStep {
    case basicInfo
    case bodyMetrics
    case goals
    case setup
    case limitations
}

@Observable
final class OnboardingModel {

    private(set) var profile = UserProfile()
    private(set) var answeredSteps: Set<OnboardingStep> = []
    private(set) var isLoading = false
    private(set) var isCompleted = false
    private(set) var generationFailure: PlanGenerationResult?
    // A counter, not the failure alone: cleared and set again in one turn reads as unchanged.
    private(set) var failureCount = 0

    private let dependencies: AppDependencies
    private let charge: () -> Void
    private let store: TrainingStore
    private let planGenerator: any PlanGenerator

    // Only the kit the catalog actually has movements for reaches the setup
    // screen, so a chip can never lead to an empty week.
    let stockedEquipment: Set<Equipment>

    private let skeletons: PlanSkeletonBuilder

    // One plan at a time; the model outlives the screen, so a rerun must not begin complete.
    private var isWorking = false
    // The request has no cancellation point of its own; a run nobody awaits must not write.
    private var run: Task<Void, Never>?

    init(dependencies: AppDependencies, charge: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.charge = charge
        store = dependencies.store
        planGenerator = dependencies.planGenerator
        stockedEquipment = Set(dependencies.catalog.all.map(\.equipment))
        skeletons = PlanSkeletonBuilder(catalog: dependencies.catalog)
        if let stored = dependencies.attempt("currentUser", { try store.currentUser() }) {
            profile = stored
        }
    }

    // The longest session these answers can actually build, so a length no day
    // of the split can fill is said on the screen that asks for it rather than
    // quietly delivered two thirds of. The longest, because a recovery day is
    // meant to be short and is no sign the answer cannot be met.
    func longestSessionMinutes(equipment: [Equipment], daysPerWeek: Int, duration: Int) async -> Int {
        var answers = profile
        answers.availableEquipment = equipment
        answers.workoutDaysPerWeek = daysPerWeek
        answers.workoutDuration = duration
        let skeletons = skeletons
        let weekNumber = Self.firstWeek
        return await Task.detached {
            let week = skeletons.build(
                PlanRequest(user: answers, weekNumber: weekNumber, startDate: .distantPast)
            )
            return week.days.map(\.minutes).max() ?? duration
        }.value
    }

    // Blank before answering: the profile's defaults are real values, not choices anyone made.
    func filled(for step: OnboardingStep, editing: Bool) -> UserProfile? {
        editing || answeredSteps.contains(step) ? profile : nil
    }

    func updateBasicInfo(
        firstName: String, age: Int, gender: Gender, experience: ExperienceLevel
    ) {
        answeredSteps.insert(.basicInfo)
        // Stored trimmed, because every greeting in the app reads it back.
        profile.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.age = age
        profile.gender = gender
        profile.experienceLevel = experience
    }

    // Unobserved, so a keystroke does not redraw the flow: a step popped off the
    // stack loses its own state, and what was typed has to outlive it for the
    // rest of the flow.
    @ObservationIgnored private var metricsInProgress: BodyMetricsEntry?

    func rememberBodyMetrics(_ entry: BodyMetricsEntry) {
        metricsInProgress = entry
    }

    func bodyMetricsInProgress() -> BodyMetricsEntry? { metricsInProgress }

    func updateBodyMetrics(height: Double, weight: Double, units: UnitSystem) {
        metricsInProgress = nil
        answeredSteps.insert(.bodyMetrics)
        profile.height = height
        profile.weight = weight
        profile.bodyUnitSystem = units
    }

    func updateFitnessGoal(_ goal: FitnessGoal) {
        answeredSteps.insert(.goals)
        profile.fitnessGoal = goal
    }

    func updateWorkoutSetup(
        equipment: [Equipment],
        liftingUnits: UnitSystem?,
        daysPerWeek: Int,
        duration: Int,
    ) {
        answeredSteps.insert(.setup)
        profile.liftingUnitSystem = liftingUnits
        profile.availableEquipment = equipment
        profile.workoutDaysPerWeek = daysPerWeek
        profile.workoutDuration = duration
    }

    func updateLimitations(injuries: [Injury]) {
        answeredSteps.insert(.limitations)
        profile.injuries = injuries
    }

    func cancelRun() {
        run?.cancel()
        run = nil
    }

    func hasCompletedOnboarding() -> Bool {
        dependencies.attempt("hasUsers", { try store.hasUsers() }) ?? false
    }

    // Updated in place: saveUserProfile's replace would carry every stored week away.
    func updateProfileOnly(onSuccess: @escaping () -> Void) {
        Task {
            isLoading = true
            if let existing = dependencies.attempt("currentUser", { try store.currentUser() }) {
                var updated = profile
                updated.id = existing.id
                dependencies.attempt("updateUser", { try store.updateUser(updated) })
            }
            isLoading = false
            onSuccess()
        }
    }

    func saveUserProfile(onSuccess: @escaping () -> Void = {}) {
        guard !isWorking else { return }
        isWorking = true
        // Cleared before the work begins rather than inside it. This model
        // outlives every screen that uses it, and the wait reads isCompleted to
        // decide it is over: set from within the task, the previous run's
        // success is still showing when the wait first looks, and it leaves
        // before there is a plan to leave for.
        isLoading = true
        isCompleted = false
        generationFailure = nil

        run = Task {
            defer { isWorking = false }

            let existing = dependencies.attempt("currentUser", { try store.currentUser() })
            var toSave = profile
            if let existing { toSave.id = existing.id }
            // Today, not the Monday just gone: a new user must not open on sessions already missed.
            let start = WorkoutWeek.startOfDay()

            // Generate before saving: saving the user replaces, and replace drops the stored weeks.
            let result = await planGenerator.generate(
                PlanRequest(
                    user: toSave,
                    weekNumber: Self.firstWeek,
                    startDate: start
                )
            )

            guard case .generated(var plan) = result else {
                // Only for a first profile: saving replaces, dropping an existing client's weeks.
                if existing == nil {
                    dependencies.attempt("saveUser", { try store.saveUser(toSave) })
                }
                isLoading = false
                generationFailure = .failed
                failureCount += 1
                return
            }

            guard !Task.isCancelled else { return }
            do {
                plan.userID = toSave.id
                try store.saveUser(toSave, startingWith: plan)
                // Charged where the week lands rather than on the screen that
                // asked for it: the screen's own wait outlives the save, and
                // the process can end inside it.
                charge()
                isLoading = false
                isCompleted = true
                onSuccess()
            } catch {
                isLoading = false
                generationFailure = .failed
                failureCount += 1
            }
        }
    }

    private static let firstWeek = 1
}
