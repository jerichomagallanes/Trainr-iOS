import Foundation
import Testing
@testable import Trainr

private func catalogExercise(
    _ key: String, _ muscle: MuscleGroup,
    _ measure: ExerciseMeasure, _ pattern: MovementPattern,
    equipment: Equipment = Equipment.none
) -> CatalogExercise {
    CatalogExercise(
        key: key, name: key.replacingOccurrences(of: "_", with: " "),
        primary: muscle, secondary: [], equipment: equipment, measure: measure, pattern: pattern, staple: true,
        summary: key, steps: []
    )
}

private extension GeneratedPlan {
    func mapDays(_ change: (inout GeneratedDay) -> Void) -> GeneratedPlan {
        var copy = self
        for index in copy.days.indices { change(&copy.days[index]) }
        return copy
    }

    func mapExercise(_ key: String, _ change: (inout GeneratedExercise) -> Void) -> GeneratedPlan {
        mapDays { day in
            for index in day.exercises.indices where day.exercises[index].exerciseKey == key {
                change(&day.exercises[index])
            }
        }
    }
}

struct GeneratedPlanParserTests {

    private let catalog = InMemoryExerciseCatalog([
        catalogExercise("warm_up_jog", .cardio, .duration, .conditioning),
        catalogExercise("bicycle_crunch", .abdominals, .reps, .core),
        catalogExercise("goblet_squat", .quadriceps, .weightAndReps, .squat),
        catalogExercise("plank", .abdominals, .duration, .core)
    ])

    private var parser: GeneratedPlanParser { GeneratedPlanParser(catalog: catalog) }
    private let userID = UUID()
    private let startDate = Date(timeIntervalSince1970: 1_753_056_000)
    private let unbounded = PlanLimits(maxSetsPerSession: .max)

    // Deliberately out of order: ordering is ours.
    private let good = GeneratedPlan(
        title: "Week 1",
        days: [
            GeneratedDay(
                dayNumber: 3,
                title: "Cardio & Core",
                exercises: [
                    GeneratedExercise(exerciseKey: "warm_up_jog", sets: [GeneratedSet(seconds: 300)]),
                    GeneratedExercise(
                        exerciseKey: "bicycle_crunch", restSeconds: 30,
                        sets: [GeneratedSet(reps: 20), GeneratedSet(reps: 20)]
                    )
                ]
            ),
            GeneratedDay(
                dayNumber: 1,
                title: "Full Body Strength",
                exercises: [
                    GeneratedExercise(
                        exerciseKey: "goblet_squat", restSeconds: 60,
                        sets: [
                            GeneratedSet(reps: 12, weightKg: 20),
                            GeneratedSet(reps: 11, weightKg: 20),
                            GeneratedSet(reps: 10, weightKg: 22.5)
                        ]
                    )
                ]
            )
        ]
    )

    private func parseGood() throws -> WeeklyPlan {
        let result = parser.parse(good, userID: userID, weekNumber: 2, startDate: startDate, limits: unbounded)
        guard case .parsed(let plan) = result else {
            throw ParserTestFailure.expectedParsed
        }
        return plan
    }

    private func errors(of plan: GeneratedPlan) throws -> [String] {
        let result = parser.parse(plan, userID: UUID(), weekNumber: 1,
                                  startDate: Date(timeIntervalSince1970: 0), limits: unbounded)
        guard case .invalid(let errors) = result else {
            throw ParserTestFailure.expectedInvalid
        }
        return errors
    }

    private enum ParserTestFailure: Error {
        case expectedParsed
        case expectedInvalid
    }

    @Test func theAppSuppliedFieldsLandOnThePlan() throws {
        let plan = try parseGood()

        #expect(plan.userID == userID)
        #expect(plan.weekNumber == 2)
        #expect(plan.startDate == startDate)
        #expect(plan.title == "Week 1")
    }

    @Test func daysComeOutSortedByDayNumber() throws {
        #expect(try parseGood().workoutDays.map(\.dayNumber) == [1, 3])
    }

    // Five minutes of jogging, then two sets of twenty at three seconds a rep
    // with thirty seconds between them: eight minutes of work, plus the minute
    // spent walking from one to the other.
    @Test func aDaysNumbersAreDerivedNotAccepted() throws {
        let cardio = try #require(parseGood().workoutDays.first { $0.dayNumber == 3 })

        #expect(cardio.duration == 9)
        #expect(cardio.exerciseCount == 2)
        #expect(cardio.duration == cardio.exercises.reduce(0) { $0 + $1.durationMinutes } + 1)
    }

    @Test func anExerciseArrivesWithEverythingItsCardShows() throws {
        let day = try #require(parseGood().workoutDays.first { $0.dayNumber == 1 })
        let squat = try #require(day.exercises.first)

        #expect(squat.exerciseKey == "goblet_squat")
        #expect(squat.name == "goblet squat")
        #expect(squat.measure == .weightAndReps)
        #expect(squat.durationMinutes == 4)
        #expect(squat.restTime == 60)
        #expect(squat.setCount == 3)
    }

    @Test func setsAreNumberedInOrderAndCarryOnlyTargets() throws {
        let day = try #require(parseGood().workoutDays.first { $0.dayNumber == 1 })
        let squatSets = try #require(day.exercises.first).sets

        #expect(squatSets.map(\.setNumber) == [1, 2, 3])
        #expect(squatSets.map(\.targetReps) == [12, 11, 10])
        #expect(squatSets.last?.targetWeightKg == 22.5)
        for set in squatSets {
            #expect(set.actualReps == nil)
            #expect(set.actualWeightKg == nil)
            #expect(!set.isCompleted)
        }
    }

    @Test func aFreshPlanStartsWithNothingDone() throws {
        for day in try parseGood().workoutDays {
            #expect(day.status == .notStarted)
            #expect(day.completedAt == nil)
            for exercise in day.exercises {
                #expect(!exercise.isCompleted)
                #expect(exercise.videoTutorialURL == nil)
            }
        }
    }

    // How a movement is measured is a fact about the movement, so it comes
    // from the catalog.
    @Test func theCatalogDecidesHowAMovementIsMeasured() throws {
        let plan = try parseGood()
        let jog = try #require(
            plan.workoutDays.first { $0.dayNumber == 3 }?.exercises.first
        )
        let squat = try #require(
            plan.workoutDays.first { $0.dayNumber == 1 }?.exercises.first
        )

        #expect(jog.measure == .duration)
        #expect(squat.measure == .weightAndReps)
    }

    // The day's kit is the union of what its movements need.
    @Test func theDaysEquipmentComesFromItsMovements() throws {
        let loaded = GeneratedPlanParser(catalog: InMemoryExerciseCatalog([
            catalogExercise("goblet_squat", .quadriceps, .weightAndReps, .squat,
                            equipment: Equipment.dumbbell),
            catalogExercise("warm_up_jog", .cardio, .duration, .conditioning),
            catalogExercise("bicycle_crunch", .abdominals, .reps, .core)
        ]))
        let result = loaded.parse(
            good, userID: UUID(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0), limits: unbounded
        )

        guard case .parsed(let plan) = result else { throw ParserTestFailure.expectedParsed }
        #expect(plan.workoutDays.first { $0.dayNumber == 1 }?.equipment == ["Dumbbell"])
        #expect(plan.workoutDays.first { $0.dayNumber == 3 }?.equipment == [])
    }

    @Test func aStrayTargetTheMeasureDoesNotRenderIsStripped() throws {
        let result = parser.parse(
            good.mapExercise("bicycle_crunch") { $0.sets[0] = GeneratedSet(reps: 20, weightKg: 8, seconds: 40) },
            userID: UUID(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0), limits: unbounded
        )

        guard case .parsed(let plan) = result else { throw ParserTestFailure.expectedParsed }
        let day = try #require(plan.workoutDays.first { $0.dayNumber == 3 })
        let stripped = try #require(
            day.exercises.first { $0.exerciseKey == "bicycle_crunch" }
        ).sets[0]
        #expect(stripped.targetReps == 20)
        #expect(stripped.targetWeightKg == nil)
        #expect(stripped.targetSeconds == nil)
    }

    @Test func aBlankTitleAndNoDaysAreBothReported() throws {
        let errors = try errors(of: GeneratedPlan(title: " ", days: []))

        #expect(errors == ["plan: title is blank", "plan: has no days"])
    }

    @Test func aRepeatedDayNumberIsRejected() throws {
        let errors = try errors(of: good.mapDays { if $0.dayNumber == 3 { $0.dayNumber = 1 } })

        #expect(errors == ["plan: day 1 appears more than once"])
    }

    @Test func aDayNumberOutsideTheWeekIsRejected() throws {
        let errors = try errors(of: good.mapDays { if $0.dayNumber == 3 { $0.dayNumber = 8 } })

        #expect(errors == ["day 8: dayNumber must be 1..7, Monday to Sunday"])
    }

    @Test func anExerciseKeyThatIsNotASlugIsRejected() throws {
        let errors = try errors(of: good.mapExercise("goblet_squat") { $0.exerciseKey = "Goblet Squat" })

        #expect(errors == [
            "day 1, Goblet Squat: exerciseKey 'Goblet Squat' is not a lower_snake_case slug"
        ])
    }

    @Test func theSameExerciseTwiceInOneDayIsRejected() throws {
        let errors = try errors(of: good.mapExercise("warm_up_jog") { $0.exerciseKey = "bicycle_crunch" })

        #expect(errors.contains("day 3: exerciseKey 'bicycle_crunch' appears more than once"))
    }

    @Test func aSetMissingTheTargetItsMeasureNeedsIsRejected() throws {
        let repsErrors = try errors(of: good.mapExercise("goblet_squat") { $0.sets[0] = GeneratedSet() })
        let secondsErrors = try errors(of: good.mapExercise("warm_up_jog") { $0.sets[0] = GeneratedSet(reps: 300) })

        #expect(repsErrors == ["day 1, goblet_squat, set 1: needs reps between 1 and 100"])
        #expect(secondsErrors == ["day 3, warm_up_jog, set 1: needs seconds between 5 and 5400"])
    }

    @Test func numbersNoClientCouldPerformAreRejected() throws {
        #expect(try errors(of: good.mapExercise("bicycle_crunch") { $0.restSeconds = -30 })
            == ["day 3, bicycle_crunch: restSeconds must be 5..600"])
        #expect(try errors(of: good.mapExercise("goblet_squat") { $0.sets[2] = GeneratedSet(reps: 10, weightKg: 0) })
            == ["day 1, goblet_squat, set 3: weightKg must be between 0.5 and 500.0"])
        #expect(try errors(of: good.mapExercise("goblet_squat") { $0.sets[0] = GeneratedSet(reps: 400) })
            == ["day 1, goblet_squat, set 1: needs reps between 1 and 100"])
    }

    // A session is a time budget: three sets is not something a two-set
    // session pays for.
    @Test func aDayThatOverspendsTheSessionIsRejected() throws {
        let result = parser.parse(
            good,
            userID: userID,
            weekNumber: 2,
            startDate: startDate,
            limits: PlanLimits(maxSetsPerSession: 2)
        )

        guard case .invalid(let errors) = result else {
            Issue.record("expected the plan to be rejected")
            return
        }
        #expect(errors == [
            "day 3: has 3 sets but the client's session length allows at most 2, warm-up included",
            "day 1: has 3 sets but the client's session length allows at most 2, warm-up included"
        ])
    }

    @Test func anExerciseWithNoSetsIsRejected() throws {
        let errors = try errors(of: good.mapExercise("warm_up_jog") { $0.sets = [] })

        #expect(errors == ["day 3, warm_up_jog: has no sets"])
    }

    // A rejected week names every problem it has, not only the first.
    @Test func everyProblemIsReportedNotJustTheFirst() throws {
        let errors = try errors(
            of: good.mapExercise("bicycle_crunch") { $0.restSeconds = -30 }
                .mapExercise("goblet_squat") { $0.sets[2] = GeneratedSet(reps: 10, weightKg: 0) }
        )

        #expect(errors.count == 2)
        #expect(errors.contains { $0.hasPrefix("day 1, goblet_squat, set 3: weightKg must be between") })
        #expect(errors.contains { $0.hasPrefix("day 3, bicycle_crunch: restSeconds must be") })
    }
}
