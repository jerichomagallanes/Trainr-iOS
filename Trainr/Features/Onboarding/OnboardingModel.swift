import Foundation
import Observation

// Which questions the client has actually answered. It cannot be read off the
// profile: every enum field starts on a real value, so an untouched profile
// looks exactly like an answered one, and only the blank strings and zeroes
// give anything away.
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
    // A step reopened by going back is filled in from what was typed; before
    // it has been answered there is nothing to fill it with.
    private(set) var answeredSteps: Set<OnboardingStep> = []
    private(set) var isLoading = false
    private(set) var isCompleted = false
    // Set when a plan could not be written, so the screen can say why rather
    // than handing over a week nobody asked for.
    private(set) var generationFailure: PlanGenerationFailure?
    // Counts up on every failure, so a screen can tell a second failure from
    // the first even when both say the same thing. The failure value alone
    // cannot: cleared and set again within one turn, it reads as unchanged.
    private(set) var failureCount = 0

    private let dependencies: AppDependencies
    private let store: TrainingStore
    private let planGenerator: any PlanGenerator
    private let languageCode: String

    // One plan at a time, and completion starts false: this model outlives
    // the screen, so a regeneration would otherwise begin already "complete"
    // from the run before it and walk straight past the wait.
    private var isWorking = false
    // Held so a wait the client walked away from can be called off. The request
    // still finishes — it has no cancellation point of its own — but a run
    // nobody is waiting for must not write a profile or a plan.
    private var run: Task<Void, Never>?

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        store = dependencies.store
        planGenerator = dependencies.planGenerator
        languageCode = dependencies.languageCode
        // A returning user editing or regenerating starts from the profile
        // they saved, not from blank forms.
        if let stored = dependencies.attempt("currentUser", { try store.currentUser() }) {
            profile = stored
        }
    }

    // An onboarding step is seeded with what the client typed once they have
    // answered it, so stepping back to a screen shows their answers instead of
    // an empty form. Before that it stays blank: the profile's defaults are
    // real values and would read as choices nobody made.
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

    func updateFitnessGoal(_ goal: FitnessGoal, workoutType: WorkoutType) {
        answeredSteps.insert(.goals)
        profile.fitnessGoal = goal
        profile.workoutType = workoutType
    }

    func updateWorkoutSetup(
        location: WorkoutLocation,
        equipment: [Equipment],
        liftingUnits: UnitSystem?,
        daysPerWeek: Int,
        duration: Int,
        preferredTime: WorkoutTime
    ) {
        answeredSteps.insert(.setup)
        profile.workoutLocation = location
        profile.liftingUnitSystem = liftingUnits
        profile.availableEquipment = equipment
        profile.workoutDaysPerWeek = daysPerWeek
        profile.workoutDuration = duration
        profile.preferredWorkoutTime = preferredTime
    }

    func updateLimitations(injuries: [String]) {
        answeredSteps.insert(.limitations)
        profile.injuries = injuries
    }

    // Giving up on the wait: what has been asked for cannot be unasked, but its
    // answer stops being written.
    func cancelRun() {
        run?.cancel()
        run = nil
    }

    func hasCompletedOnboarding() -> Bool {
        dependencies.attempt("hasUsers", { try store.hasUsers() }) ?? false
    }

    // Editing the profile from the plan must leave training history alone, so
    // the stored user is updated in place: saveUserProfile's replace would
    // carry every stored week away. The change takes effect on the next week
    // generated, which reads the profile fresh.
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
        run = Task {
            defer { isWorking = false }
            isLoading = true
            isCompleted = false
            generationFailure = nil

            let existing = dependencies.attempt("currentUser", { try store.currentUser() })
            var toSave = profile
            if let existing { toSave.id = existing.id }
            // The plan starts today. Anchoring it to the Monday just gone
            // would hand a new user a week of sessions already missed.
            let start = WorkoutWeek.startOfDay()

            // Nothing is written until there is a plan to write. Saving the
            // user first would replace the stored one, and that replace
            // carries every existing week away — so a regeneration that
            // failed used to destroy the history it was meant to build on.
            let result = await planGenerator.generate(
                PlanRequest(
                    user: toSave,
                    weekNumber: Self.firstWeek,
                    startDate: start,
                    languageCode: languageCode
                )
            )

            guard case .generated(var plan) = result else {
                // Keep what they typed. Thirteen answers is a lot to lose
                // to a failure they did not cause, and losing them means
                // typing it all again to try the very thing that just
                // failed. Saved without a plan, the app opens on the empty
                // state that already says the profile is safe and offers to
                // create a plan — so coming back later costs one tap.
                //
                // Only for a first profile. An existing one is already stored,
                // and saving replaces: doing this to a client who has been
                // training would carry their weeks away, which is the whole
                // reason nothing is written before the plan.
                if existing == nil {
                    dependencies.attempt("saveUser", { try store.saveUser(toSave) })
                }
                isLoading = false
                if case .failure(let failure) = result {
                    generationFailure = failure
                    failureCount += 1
                }
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
