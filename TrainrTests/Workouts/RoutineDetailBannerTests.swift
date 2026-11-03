import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Routine detail: the adjusted banner")
struct RoutineDetailBannerTests {

    private let store: TrainingStore
    private let dependencies: AppDependencies
    private let user = testUser()
    private let day: WorkoutDay

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
        try store.saveUser(user)
        try store.savePlan(
            WeeklyPlan(
                userID: user.id,
                weekNumber: 1,
                title: "Week 1",
                startDate: Calendar(identifier: .gregorian).startOfDay(for: Date()),
                workoutDays: [
                    WorkoutDay(
                        dayNumber: 1,
                        title: "Full Body",
                        duration: 45,
                        exerciseCount: 4,
                        equipment: ["Barbell", "Dumbbells"],
                        exercises: [
                            Self.exercise("bicycle_crunch", "Bicycle Crunches"),
                            Self.exercise("dumbbell_bicep_curl", "Bicep Curls"),
                            Self.exercise("barbell_bench_press", "Bench Presses"),
                            Self.exercise("dumbbell_step_up", "Dumbbell Step-Ups")
                        ]
                    )
                ]
            )
        )
        day = try #require(try store.plan(for: user.id, weekNumber: 1)?.workoutDays.first)
    }

    @Test("The banner names the replaced exercise the way the day stores it")
    func theBannerNamesTheReplacedExerciseAsTheDayStoresIt() throws {
        try record([
            ProposalChange(
                kind: .replaceUnperformed,
                before: try snapshot("bicycle_crunch"),
                after: ExerciseSnapshot(
                    exerciseInstanceID: "new", catalogKey: "dumbbell_step_up",
                    sets: [SetSnapshot(setID: "new:1", targetReps: 10)]
                )
            )
        ])

        let banner = try #require(loaded().state.adjustedBanner)
        #expect(banner.kind == .replaced)
        #expect(banner.fromName == "Bicycle Crunches")
        #expect(banner.toName == "Dumbbell Step-Ups")
        #expect(banner.fromName != dependencies.catalog["bicycle_crunch"]?.name)
        #expect(banner.toName != dependencies.catalog["dumbbell_step_up"]?.name)
    }

    @Test("The banner lists regions in the order the review uses")
    func theBannerListsRegionsInTheOrderTheReviewUses() throws {
        try record([
            try reduction("bicycle_crunch"),
            try reduction("dumbbell_bicep_curl"),
            try reduction("barbell_bench_press")
        ])

        let banner = try #require(loaded().state.adjustedBanner)
        #expect(banner.kind == .lessWorkForRegions)
        #expect(banner.regions == [.chest, .arms, .core])
    }

    // MARK: - Seeding

    private func loaded() -> RoutineDetailModel {
        let model = RoutineDetailModel(dependencies: dependencies, dayNumber: day.dayNumber)
        model.load()
        return model
    }

    private func record(_ changes: [ProposalChange]) throws {
        try store.recordAdjustment(
            AppliedAdjustment(
                dayID: day.id,
                proposal: AdjustmentProposal(
                    proposalID: "proposal-banner",
                    requestID: "request-banner",
                    sessionID: "day:\(day.id.uuidString)",
                    baseRevision: PlanRevision.of(day),
                    policyVersion: UnstuckPolicy.version,
                    changes: changes,
                    preservedPerformedSetIDs: [],
                    reasonCode: .timeConstraint,
                    tradeoffCode: "reduced_session",
                    factReferences: []
                ),
                reason: .lessTime,
                appliedAt: Date()
            )
        )
    }

    private func reduction(_ key: String) throws -> ProposalChange {
        let before = try snapshot(key)
        return ProposalChange(
            kind: .reduceUnperformed,
            before: before,
            after: ExerciseSnapshot(
                exerciseInstanceID: before.exerciseInstanceID,
                catalogKey: key,
                sets: Array(before.sets.prefix(1))
            )
        )
    }

    private func snapshot(_ key: String) throws -> ExerciseSnapshot {
        let exercise = try #require(day.exercises.first { $0.exerciseKey == key })
        return ExerciseSnapshot(
            exerciseInstanceID: "exercise:\(exercise.id.uuidString)",
            catalogKey: key,
            sets: exercise.sets.map {
                SetSnapshot(setID: "set:\($0.id.uuidString)", targetReps: $0.targetReps)
            }
        )
    }

    private static func exercise(_ key: String, _ name: String) -> WorkoutExercise {
        WorkoutExercise(
            exerciseKey: key,
            name: name,
            sets: (1...2).map { ExerciseSet(setNumber: $0, targetReps: 10) },
            durationMinutes: 10
        )
    }
}
