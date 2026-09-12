import Foundation
import Observation

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
    private let store: TrainingStore
    private let planGenerator: any PlanGenerator

    // Only the kit the catalog actually has movements for reaches the setup
    // screen, so a chip can never lead to an empty week.
    let stockedEquipment: Set<Equipment>

    // One plan at a time; the model outlives the screen, so a rerun must not begin complete.
    private var isWorking = false
    // The request has no cancellation point of its own; a run nobody awaits must not write.
    private var run: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        planGenerator = dependencies.planGenerator
        stockedEquipment = Set(dependencies.catalog.all.map(\.equipment))
        if let stored = dependencies.attempt("currentUser", { try store.currentUser() }) {
            profile = stored
        }
    }

    // Blank before answering: the profile's defaults are real values, not choices anyone made.
    func filled(for step: OnboardingStep, editing: Bool) -> UserProfile? {
        editing || answeredSteps.contains(step) ? profile : nil
    }

    func updateBasicInfo(
        firstName: String, age: Int, gender: Gender, experience: ExperienceLevel
    ) {
        answeredSteps.insert(.basicInfo)
        profile.firstName = firstName
        profile.age = age
        profile.gender = gender
        profile.experienceLevel = experience
    }

    func updateBodyMetrics(height: Double, weight: Double, units: UnitSystem) {
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
                try store.saveUser(toSave)
                plan.userID = toSave.id
                try store.savePlan(plan)
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
