import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Onboarding model")
struct OnboardingModelTests {

    private struct RefusingGenerator: PlanGenerator {
        let reason: PlanGenerationFailure
        func generate(_ request: PlanRequest) async -> PlanGenerationResult { .failure(reason) }
    }

    private func dependencies(_ generator: any PlanGenerator = CannedPlanGenerator()) throws -> AppDependencies {
        AppDependencies(
            store: TrainingStore(container: try TrainingStore.container(inMemory: true)),
            planGenerator: generator,
            breadcrumbs: NoBreadcrumbs()
        )
    }

    private func answerEverything(_ model: OnboardingModel, liftingUnits: UnitSystem? = .metric) {
        model.updateBasicInfo(firstName: "Alex", age: 30, gender: .male, experience: .beginner)
        model.updateBodyMetrics(height: 175, weight: 72, units: .imperial)
        model.updateFitnessGoal(.muscleGain, workoutType: .strength)
        model.updateWorkoutSetup(
            location: .home, equipment: [.dumbbells], liftingUnits: liftingUnits,
            daysPerWeek: 3, duration: 45, preferredTime: .morning
        )
        model.updateLimitations(injuries: ["Lower Back Pain"])
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
        #expect(model.profile.workoutType == .strength)
        #expect(model.profile.workoutLocation == .home)
        #expect(model.profile.availableEquipment == [.dumbbells])
        #expect(model.profile.workoutDaysPerWeek == 3)
        #expect(model.profile.workoutDuration == 45)
        #expect(model.profile.preferredWorkoutTime == .morning)
        #expect(model.profile.injuries == ["Lower Back Pain"])
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

    @Test("Limitations leave the workout style alone")
    func limitationsLeaveStyleAlone() throws {
        let model = OnboardingModel(dependencies: try dependencies())
        model.updateFitnessGoal(.endurance, workoutType: .cardio)
        model.updateLimitations(injuries: [])
        #expect(model.profile.workoutType == .cardio)
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
        let deps = try dependencies(RefusingGenerator(reason: .offline))
        let model = OnboardingModel(dependencies: deps)
        answerEverything(model)

        model.saveUserProfile()
        await settle(model)

        #expect(model.generationFailure == .offline)
        #expect(!model.isCompleted)
        let user = try #require(try deps.store.currentUser())
        #expect(try deps.store.plans(for: user.id).isEmpty)
    }

    @Test("A failed regeneration leaves the stored plan exactly where it was")
    func failedRegenerationLeavesPlan() async throws {
        let store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        let first = OnboardingModel(dependencies: AppDependencies(
            store: store, planGenerator: CannedPlanGenerator(), breadcrumbs: NoBreadcrumbs()))
        answerEverything(first)
        first.saveUserProfile()
        await settle(first)
        let user = try #require(try store.currentUser())
        let before = try store.plans(for: user.id)

        let again = OnboardingModel(dependencies: AppDependencies(
            store: store, planGenerator: RefusingGenerator(reason: .failed), breadcrumbs: NoBreadcrumbs()))
        again.saveUserProfile()
        await settle(again)

        #expect(again.generationFailure == .failed)
        #expect(try store.plans(for: user.id).map(\.id) == before.map(\.id))
    }
}
