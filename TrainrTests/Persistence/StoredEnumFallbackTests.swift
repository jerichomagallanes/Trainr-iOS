import Foundation
import SwiftData
import Testing
@testable import Trainr

// A row written by a build that knew an extra case must still read back. The
// mapping degrades to a default rather than throwing, and nothing proved it.
@MainActor
@Suite("Stored values that no longer exist")
struct StoredEnumFallbackTests {

    private let container: ModelContainer
    private let store: TrainingStore

    init() throws {
        container = try TrainingStore.container(inMemory: true)
        store = TrainingStore(container: container)
    }

    private func storedRecord(_ profile: UserProfile) throws -> UserRecord {
        try store.saveUser(profile)
        let id = profile.id
        let records = try container.mainContext.fetch(
            FetchDescriptor<UserRecord>(predicate: #Predicate { $0.id == id })
        )
        return try #require(records.first)
    }

    @Test("A gender the app no longer knows reads back as unstated")
    func anUnknownGenderDegrades() throws {
        let record = try storedRecord(UserProfile(firstName: "Alex", age: 30))
        record.gender = "androgynousCyborg"

        #expect(record.profile.gender == .preferNotToSay)
    }

    @Test("An unknown goal, level, place and time each fall back")
    func theOtherChoicesDegradeToo() throws {
        let record = try storedRecord(UserProfile(firstName: "Alex", age: 30))
        record.fitnessGoal = "becomeABird"
        record.experienceLevel = "olympian"
        record.workoutLocation = "moon"
        record.preferredWorkoutTime = "thirdWatch"
        record.workoutType = "interpretiveDance"

        let profile = record.profile
        #expect(profile.fitnessGoal == .generalFitness)
        #expect(profile.experienceLevel == .beginner)
        #expect(profile.workoutLocation == .home)
        #expect(profile.preferredWorkoutTime == .anytime)
        #expect(profile.workoutType == .mixed)
    }

    // Dropped rather than defaulted: equipment the client does not have must
    // not become equipment they do.
    @Test("Unknown equipment is dropped, and what is recognised is kept")
    func unknownEquipmentIsDroppedNotDefaulted() throws {
        let record = try storedRecord(UserProfile(firstName: "Alex", age: 30))
        record.availableEquipment = ["dumbbell", "antigravityBoots", "kettlebell"]

        let equipment = record.profile.availableEquipment
        #expect(equipment == [.dumbbell, .kettlebell])
        #expect(equipment.count == 2)
    }

    @Test("An unknown unit system falls back, and an absent lifting one stays absent")
    func unitsDegradeWithoutInventingAChoice() throws {
        let record = try storedRecord(UserProfile(firstName: "Alex", age: 30))
        record.bodyUnitSystem = "cubits"
        record.liftingUnitSystem = "stone"

        #expect(record.profile.bodyUnitSystem == .standard)
        #expect(record.profile.liftingUnitSystem == nil)
    }

    @Test("A day whose status is unreadable is not started")
    func anUnknownDayStatusDegrades() throws {
        var profile = UserProfile(firstName: "Alex", age: 30)
        profile.id = UUID()
        try store.saveUser(profile)
        var plan = SampleWorkoutData.weekOne
        plan.userID = profile.id
        try store.savePlan(plan)

        let days = try container.mainContext.fetch(FetchDescriptor<WorkoutDayRecord>())
        let day = try #require(days.first)
        day.status = "abandonedHalfway"

        #expect(day.day.status == .notStarted)
    }

    // Nine categories replaced a longer list, and a profile saved under the
    // old names must not come back with no equipment at all.
    @Test("Equipment saved under the old names still reads back")
    func equipmentSavedUnderTheOldNamesStillReadsBack() throws {
        let record = try storedRecord(UserProfile(firstName: "Alex", age: 30))
        record.availableEquipment = ["dumbbells", "cableMachine", "pullUpBar", "squatRack"]

        #expect(record.profile.availableEquipment == [.dumbbell, .machine, .machine, .barbell])
    }
}
