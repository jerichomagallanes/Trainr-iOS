import Foundation
import Testing
@testable import Trainr

struct CannedPlanGeneratorTests {

    private let userID = UUID()

    private func request(
        daysPerWeek: Int = 3,
        weekNumber: Int = 1,
        duration: Int = 45,
        equipment: [Equipment] = [.dumbbells],
        previousWeek: WeeklyPlan? = nil
    ) -> PlanRequest {
        PlanRequest(
            user: UserProfile(
                id: userID,
                firstName: "Jericho",
                availableEquipment: equipment,
                workoutDaysPerWeek: daysPerWeek,
                workoutDuration: duration
            ),
            weekNumber: weekNumber,
            startDate: Date(timeIntervalSince1970: 1),
            languageCode: "en",
            previousWeek: previousWeek
        )
    }

    private func plan(
        daysPerWeek: Int = 3,
        duration: Int = 45,
        equipment: [Equipment] = [.dumbbells],
        previousWeek: WeeklyPlan? = nil,
        weekNumber: Int = 1
    ) async throws -> WeeklyPlan {
        let result = await CannedPlanGenerator().generate(
            request(daysPerWeek: daysPerWeek, weekNumber: weekNumber, duration: duration,
                    equipment: equipment, previousWeek: previousWeek)
        )
        guard case .generated(let plan) = result else {
            throw CannedFailure.expectedGenerated
        }
        return plan
    }

    private enum CannedFailure: Error {
        case expectedGenerated
    }

    @Test func itHonoursTheNumberOfDaysAsked() async throws {
        for days in 1...7 {
            #expect(try await plan(daysPerWeek: days).workoutDays.count == days)
        }
    }

    @Test func itSpacesSessionsAcrossTheWeekWithoutRepeatingADay() async throws {
        let slots = try await plan(daysPerWeek: 3).workoutDays.map(\.dayNumber)

        #expect(Set(slots).count == slots.count)
        #expect(slots == slots.sorted())
        #expect(slots.allSatisfy { (1...7).contains($0) })
    }

    @Test func everyExerciseUsesAKeyTheCatalogKnows() async throws {
        let keys = try await plan().workoutDays.flatMap(\.exercises).map(\.exerciseKey)

        #expect(!keys.isEmpty)
        #expect(Set(keys).isSubset(of: Set(ExerciseVideoCatalog.videoIDs.keys)))
    }

    @Test func itCarriesTheRequestsWeekAndStartDate() async throws {
        let plan = try await plan(weekNumber: 4)

        #expect(plan.weekNumber == 4)
        #expect(plan.startDate == Date(timeIntervalSince1970: 1))
        #expect(plan.userID == userID)
    }

    @Test func itProgressesFromTheWeekBefore() async throws {
        let first = try await plan()
        let second = try await plan(previousWeek: first, weekNumber: 2)

        let before = try #require(first.workoutDays.first?.exercises
            .first { $0.exerciseKey == "goblet_squat" }?.sets.first?.targetWeightKg)
        let after = try #require(second.workoutDays.first?.exercises
            .first { $0.exerciseKey == "goblet_squat" }?.sets.first?.targetWeightKg)

        #expect(after > before)
    }

    @Test func itNeverFails() async {
        let result = await CannedPlanGenerator().generate(request())

        guard case .generated = result else {
            Issue.record("expected a generated plan, got \(result)")
            return
        }
    }

    @Test func itFillsTheSessionLengthThatWasAskedFor() async throws {
        for requested in [30, 45, 60, 90] {
            let day = try #require(await plan(duration: requested).workoutDays.first)

            #expect(day.duration == requested)
            #expect(day.exercises.reduce(0) { $0 + $1.durationMinutes } == requested)
        }
    }

    @Test func itOnlyPrescribesMovementsTheClientHasTheKitFor() async throws {
        let keys = Set(try await plan(equipment: [Equipment.none])
            .workoutDays.flatMap(\.exercises).map(\.exerciseKey))

        #expect(!keys.isEmpty)
        #expect(keys.isDisjoint(with: ["goblet_squat", "dumbbell_floor_press", "overhead_press"]))
    }

    @Test func aLoadedProfileStillGetsLoadedWork() async throws {
        let keys = Set(try await plan(equipment: [.barbell])
            .workoutDays.flatMap(\.exercises).map(\.exerciseKey))

        #expect(keys.contains("bent_over_row"))
    }

    @Test func itNamesOnlyTheEquipmentTheDayActuallyNeeds() async throws {
        let loaded = try #require(
            await plan(equipment: [.dumbbells, .squatRack]).workoutDays.first)
        #expect(loaded.equipment == ["Dumbbells"])

        let bodyweight = try #require(
            await plan(equipment: [Equipment.none]).workoutDays.first)
        #expect(bodyweight.equipment == ["Bodyweight"])
    }

    @Test func theExerciseCountMatchesTheExercises() async throws {
        for day in try await plan(duration: 60).workoutDays {
            #expect(day.exerciseCount == day.exercises.count)
        }
    }
}
