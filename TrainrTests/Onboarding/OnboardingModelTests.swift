import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Onboarding model")
struct OnboardingModelTests {

    private struct RefusingGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult { .failed }
    }

    private func dependencies(_ generator: any PlanGenerator = TemplatePlanGenerator()) throws -> AppDependencies {
        AppDependencies(
            store: TrainingStore(container: try TrainingStore.container(inMemory: true)),
            planGenerator: generator,
            breadcrumbs: NoBreadcrumbs()
        )
    }

    private func answerEverything(_ model: OnboardingModel, liftingUnits: UnitSystem? = .metric) {
        model.updateBasicInfo(firstName: "Alex", age: 30, gender: .male, experience: .beginner)
        model.updateBodyMetrics(height: 175, weight: 72, units: .imperial)
        model.updateFitnessGoal(.muscleGain)
        model.updateWorkoutSetup(
            equipment: [.dumbbell], liftingUnits: liftingUnits,
            daysPerWeek: 3, duration: 45
        )
        model.updateLimitations(injuries: [.lowerBack])
    }

    private func settle(_ model: OnboardingModel) async {
        for _ in 0..<100 where model.isLoading || (!model.isCompleted && model.generationFailure == nil) {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    @Test("Starts blank and idle, answering no step yet")
    func initialState() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        #expect(model.profile.firstName.isEmpty)
        #expect(model.profile.age == 0)
        #expect(!model.isLoading)
        #expect(!model.isCompleted)
        #expect(model.filled(for: .basicInfo, editing: false) == nil)
        #expect(model.filled(for: .basicInfo, editing: true) != nil)
    }

    @Test("Each step writes only its own answers")
    func stepsWriteTheirOwnFields() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        answerEverything(model)

        #expect(model.profile.firstName == "Alex")
        #expect(model.profile.age == 30)
        #expect(model.profile.gender == .male)
        #expect(model.profile.experienceLevel == .beginner)
        #expect(model.profile.height == 175)
        #expect(model.profile.weight == 72)
        #expect(model.profile.fitnessGoal == .muscleGain)
        #expect(model.profile.availableEquipment == [.dumbbell])
        #expect(model.profile.workoutDaysPerWeek == 3)
        #expect(model.profile.workoutDuration == 45)
        #expect(model.profile.injuries == [.lowerBack])
        #expect(model.filled(for: .setup, editing: false) != nil)
    }

    @Test("Body units and lifting units are kept apart")
    func unitsAreSeparate() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        answerEverything(model, liftingUnits: .metric)
        #expect(model.profile.bodyUnitSystem == .imperial)
        #expect(model.profile.liftingUnitSystem == .metric)
        #expect(model.profile.weightUnits == .metric)
    }

    @Test("Without loaded equipment the sets follow the body units")
    func weightsFallBackToBodyUnits() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        answerEverything(model, liftingUnits: nil)
        #expect(model.profile.liftingUnitSystem == nil)
        #expect(model.profile.weightUnits == .imperial)
    }

    @Test("Limitations leave the goal alone")
    func limitationsLeaveGoalAlone() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        model.updateFitnessGoal(.endurance)
        model.updateLimitations(injuries: [])
        #expect(model.profile.fitnessGoal == .endurance)
    }

    @Test("A successful save stores the user and a plan against them, and says so")
    func successStoresUserAndPlan() async throws {
        let deps = try dependencies()
        let model = OnboardingModel(dependencies: deps)
        answerEverything(model)
        var called = false

        model.saveUserProfile { called = true }
        await settle(model)

        #expect(model.isCompleted)
        #expect(called)
        let user = try #require(try deps.store.currentUser())
        let plans = try deps.store.plans(for: user.id)
        #expect(plans.count == 1)
        #expect(plans.first?.userID == user.id)
    }

    @Test("A failed generation writes no plan, keeps the first profile, and says why")
    func failureKeepsProfileWritesNoPlan() async throws {
        let deps = try dependencies(RefusingGenerator())
        let model = OnboardingModel(dependencies: deps)
        answerEverything(model)

        model.saveUserProfile()
        await settle(model)

        #expect(model.generationFailure == .failed)
        #expect(!model.isCompleted)
        let user = try #require(try deps.store.currentUser())
        #expect(try deps.store.plans(for: user.id).isEmpty)
    }

    @Test("A failed regeneration leaves the stored plan exactly where it was")
    func failedRegenerationLeavesPlan() async throws {
        let store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        let first = OnboardingModel(dependencies: AppDependencies(
            store: store, planGenerator: TemplatePlanGenerator(), breadcrumbs: NoBreadcrumbs()))
        answerEverything(first)
        first.saveUserProfile()
        await settle(first)
        let user = try #require(try store.currentUser())
        let before = try store.plans(for: user.id)

        let again = OnboardingModel(dependencies: AppDependencies(
            store: store, planGenerator: RefusingGenerator(), breadcrumbs: NoBreadcrumbs()))
        again.saveUserProfile()
        await settle(again)

        #expect(again.generationFailure == .failed)
        #expect(try store.plans(for: user.id).map(\.id) == before.map(\.id))
    }

    // MARK: - Which forms come back filled in

    @Test("A step offers nothing back until it has been answered")
    func anUnansweredStepIsNotSeeded() throws {
        let model = OnboardingModel(dependencies: try dependencies())

        #expect(model.filled(for: .basicInfo, editing: false) == nil)

        model.updateBasicInfo(firstName: "Alex", age: 30, gender: .male, experience: .beginner)

        #expect(model.filled(for: .basicInfo, editing: false)?.firstName == "Alex")
        #expect(model.filled(for: .bodyMetrics, editing: false) == nil)
    }

    @Test("Editing seeds a step that was never answered in this run")
    func editingAlwaysSeeds() throws {
        let model = OnboardingModel(dependencies: try dependencies())

        #expect(model.filled(for: .setup, editing: true) != nil)
    }

    @Test("Answered steps accumulate rather than replace one another")
    func answeredStepsAddUp() throws {
        let model = OnboardingModel(dependencies: try dependencies())

        model.updateBasicInfo(firstName: "Alex", age: 30, gender: .male, experience: .beginner)
        model.updateFitnessGoal(.muscleGain)

        #expect(model.answeredSteps == [.basicInfo, .goals])
    }

    // MARK: - Returning to a saved profile

    @Test("A returning client starts from the profile they saved")
    func aStoredProfileIsLoadedOnInit() async throws {
        let dependencies = try dependencies()
        let first = OnboardingModel(dependencies: dependencies)
        answerEverything(first)
        first.saveUserProfile()
        await settle(first)

        let returning = OnboardingModel(dependencies: dependencies)

        #expect(returning.profile.firstName == "Alex")
        #expect(returning.hasCompletedOnboarding())
    }

    @Test("A client with nothing saved has not completed onboarding")
    func afreshInstallHasNoProfile() throws {
        let model = OnboardingModel(dependencies: try dependencies())

        #expect(!model.hasCompletedOnboarding())
    }

    @Test("Updating the profile alone keeps the weeks already trained")
    func updatingTheProfileKeepsThePlan() async throws {
        let dependencies = try dependencies()
        let first = OnboardingModel(dependencies: dependencies)
        answerEverything(first)
        first.saveUserProfile()
        await settle(first)
        let store = dependencies.store
        let user = try #require(try store.currentUser())
        let before = try store.plans(for: user.id).map(\.weekNumber)

        let editing = OnboardingModel(dependencies: dependencies)
        editing.updateBasicInfo(firstName: "Sam", age: 31, gender: .male, experience: .advanced)
        var done = false
        editing.updateProfileOnly { done = true }
        for _ in 0..<100 where !done { try? await Task.sleep(for: .milliseconds(20)) }

        let after = try #require(try store.currentUser())
        #expect(after.firstName == "Sam")
        #expect(after.id == user.id)
        #expect(try store.plans(for: user.id).map(\.weekNumber) == before)
    }

    private struct SlowGenerator: PlanGenerator {
        func generate(_ request: PlanRequest) async -> PlanGenerationResult {
            try? await Task.sleep(for: .milliseconds(400))
            return await TemplatePlanGenerator().generate(request)
        }
    }

    // The model outlives every screen that uses it, so a second run must not
    // start wearing the first one's result: the wait reads isCompleted to decide
    // it is over, and a stale true sends the client back before a plan exists.
    @Test("Asking for another plan stops claiming the last one is ready")
    func aSecondRunDoesNotInheritTheFirstResult() async throws {
        let dependencies = try dependencies(SlowGenerator())
        let model = OnboardingModel(dependencies: dependencies)
        answerEverything(model)
        model.saveUserProfile()
        await settle(model)
        #expect(model.isCompleted)

        model.saveUserProfile()

        #expect(!model.isCompleted)
    }
}
