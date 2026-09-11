import Foundation
import Testing
@testable import Trainr

// The shared example is answered, not paraphrased: a contract nothing
// executes drifts from the code within a release.
struct GenerationContractTests {

    private let catalog: any ExerciseCatalog
    private let example: String

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        catalog = ExerciseCatalogReader.read(try Data(contentsOf: url))
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        example = try String(
            contentsOf: root.appendingPathComponent("docs/fixtures/plan-selection-example.json"), encoding: .utf8
        )
    }

    // The client the shared fixtures were rendered for.
    private var user: UserProfile {
        var user = UserProfile()
        user.age = 34
        user.weight = 80
        user.fitnessGoal = .muscleGain
        user.experienceLevel = .intermediate
        user.availableEquipment = Equipment.allCases
        user.workoutDaysPerWeek = 4
        user.workoutDuration = 60
        return user
    }

    private var request: PlanRequest {
        PlanRequest(user: user, weekNumber: 1, startDate: Date(timeIntervalSince1970: 0))
    }

    private var skeleton: PlanSkeleton { PlanSkeletonBuilder(catalog: catalog).build(request) }

    private func repaired() throws -> (selection: PlanSelection, repairs: Int) {
        guard case .accepted(let selection, let repairs) = PlanSelectionRepair().repair(example, skeleton: skeleton)
        else { throw CancellationError() }
        return (selection, repairs)
    }

    @Test func theContractsWorkedExampleNeedsNoRepairAndAssemblesIntoAWeek() throws {
        let answer = try repaired()

        #expect(answer.repairs == 0)
        let week = try #require(PlanAssembler(catalog: catalog).assemble(skeleton, selection: answer.selection, request: request))
        #expect(week.workoutDays.count == user.workoutDaysPerWeek)
        #expect(week.workoutDays.map(\.title)
            == ["Chest and Back", "Squats and Hamstrings", "Shoulders and Arms", "Glutes and Quads"])
    }

    // The worked example is an answer to the schema fixture, so every key it
    // names must be one that week actually offered.
    @Test func everyMovementTheExampleNamesWasOnTheSlotsOwnList() throws {
        let chosen = try repaired().selection

        for day in skeleton.days {
            for slot in day.openSlots {
                let key = try #require(chosen.days[day.id]?.slots[slot.id])
                #expect(slot.candidates.contains(key), "\(day.id) \(slot.id)")
            }
        }
    }
}
