import Foundation
import Testing
@testable import Trainr

let testCatalog: any ExerciseCatalog = BundleExerciseCatalog()

func testUser(
    goal: FitnessGoal = .muscleGain,
    kit: [Equipment] = Equipment.allCases,
    injuries: [Injury] = [],
    minutes: Int = 45
) -> UserProfile {
    UserProfile(
        age: 30, gender: .male, weight: 80, fitnessGoal: goal, experienceLevel: .intermediate,
        availableEquipment: kit, workoutDaysPerWeek: 3, workoutDuration: minutes,
        injuries: injuries, bodyUnitSystem: .metric
    )
}

func testDay(_ exercises: [WorkoutExercise]) -> WorkoutDay {
    WorkoutDay(
        dayNumber: 1, title: "Day 1", duration: 45,
        exerciseCount: exercises.count, exercises: exercises
    )
}

func planned(
    _ key: String,
    sets: Int,
    performed: Int = 0,
    omitted: Int = 0,
    reps: Int = 8,
    seconds: Int = 300,
    rest: Int? = nil,
    weightKg: Double? = nil
) -> WorkoutExercise {
    let entry = testCatalog[key]
    let timed = entry?.measure == .duration
    let omittedBy = UUID()
    return WorkoutExercise(
        exerciseKey: key,
        name: entry?.name ?? key,
        measure: entry?.measure ?? .reps,
        sets: (1...sets).map { number in
            ExerciseSet(
                setNumber: number,
                targetReps: timed ? nil : reps,
                targetWeightKg: weightKg,
                targetSeconds: timed ? seconds : nil,
                isCompleted: number <= performed,
                omittedBy: number > sets - omitted ? omittedBy : nil
            )
        },
        restTime: rest
    )
}

extension WorkoutExercise {
    func logged(setNumber: Int, reps: Int) -> WorkoutExercise {
        var after = self
        after.sets = sets.map { set in
            guard set.setNumber == setNumber else { return set }
            var logged = set
            logged.actualReps = reps
            logged.isCompleted = true
            return logged
        }
        return after
    }
}

extension PolicyDecision {
    var proposal: AdjustmentProposal? {
        guard case let .proposed(proposal, _) = self else { return nil }
        return proposal
    }

    var summary: ProposalSummary? {
        guard case let .proposed(_, summary) = self else { return nil }
        return summary
    }
}

extension ChangeRow {
    var exerciseKey: String {
        switch self {
        case let .reduced(key, _, _, _): key
        case let .omitted(key, _, _): key
        case let .replaced(fromKey, _, _, _, _): fromKey
        }
    }
}

// Every proposal the policy produces has to survive the transport and say
// only what its own kind is allowed to say.
func assertWellFormed(_ proposal: AdjustmentProposal, catalog: any ExerciseCatalog) throws {
    #expect(!proposal.changes.isEmpty)
    #expect(proposal.policyVersion == UnstuckPolicy.version)
    #expect(try ProposalCoder.decode(ProposalCoder.encode(proposal)) == proposal)
    for change in proposal.changes {
        #expect(!change.before.sets.isEmpty)
        #expect(catalog[change.before.catalogKey] != nil)
        switch change.kind {
        case .reduceUnperformed:
            let after = try #require(change.after)
            #expect(after.catalogKey == change.before.catalogKey)
            #expect(after.exerciseInstanceID == change.before.exerciseInstanceID)
            #expect(after.sets.count < change.before.sets.count)
            #expect(Set(change.before.sets.map(\.setID)).isSuperset(of: after.sets.map(\.setID)))
        case .omitUnperformed:
            #expect(change.after == nil)
        case .replaceUnperformed:
            let after = try #require(change.after)
            #expect(catalog[after.catalogKey] != nil)
            #expect(after.exerciseInstanceID == "new")
        }
    }
}
