import Foundation
import Testing
@testable import Trainr

struct GeneratedPlanParserTests {

    private let parser = GeneratedPlanParser()
    private let userID = UUID()
    private let startDate = Date(timeIntervalSince1970: 1_753_056_000)

    // Deliberately out of order and carrying an unknown key: ordering is ours, extras ignored.
    private let goodJSON = """
        {
          "title": "Week 1",
          "coachNote": "an extra key the contract does not define",
          "days": [
            {
              "dayNumber": 3,
              "title": "Cardio & Core",
              "equipment": ["Yoga Mat"],
              "exercises": [
                {
                  "exerciseKey": "warm_up_jog",
                  "name": "Warm-up jog",
                  "measure": "DURATION",
                  "durationMinutes": 5,
                  "prescription": "5 minutes",
                  "instructions": "Light jogging in place to warm up.",
                  "sets": [{ "seconds": 300 }]
                },
                {
                  "exerciseKey": "bicycle_crunch",
                  "name": "Bicycle Crunches",
                  "measure": "REPS",
                  "durationMinutes": 4,
                  "prescription": "2 sets of 20 reps",
                  "instructions": "Alternate elbow to knee.",
                  "restSeconds": 30,
                  "sets": [{ "reps": 20 }, { "reps": 20 }]
                }
              ]
            },
            {
              "dayNumber": 1,
              "title": "Full Body Strength",
              "equipment": ["Dumbbells"],
              "exercises": [
                {
                  "exerciseKey": "goblet_squat",
                  "name": "Goblet Squats",
                  "measure": "WEIGHT_AND_REPS",
                  "durationMinutes": 8,
                  "prescription": "3 sets of 12 reps",
                  "instructions": "Squat holding a dumbbell at your chest.",
                  "restSeconds": 60,
                  "sets": [
                    { "reps": 12, "weightKg": 20 },
                    { "reps": 11, "weightKg": 20 },
                    { "reps": 10, "weightKg": 22.5 }
                  ]
                }
              ]
            }
          ]
        }
        """

    private func parseGood() throws -> WeeklyPlan {
        let result = parser.parse(goodJSON, userID: userID, weekNumber: 2, startDate: startDate)
        guard case .parsed(let plan) = result else {
            throw ParserTestFailure.expectedParsed
        }
        return plan
    }

    private func errors(of json: String) throws -> [String] {
        let result = parser.parse(json, userID: UUID(), weekNumber: 1,
                                  startDate: Date(timeIntervalSince1970: 0))
        guard case .invalid(let errors) = result else {
            throw ParserTestFailure.expectedInvalid
        }
        return errors
    }

    private func goodJSON(replacing from: String, with to: String) -> String {
        #expect(goodJSON.contains(from))
        return goodJSON.replacingOccurrences(of: from, with: to)
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
    // with thirty seconds between them: eight minutes, whatever the model
    // would have claimed.
    @Test func aDaysNumbersAreDerivedNotAccepted() throws {
        let cardio = try #require(parseGood().workoutDays.first { $0.dayNumber == 3 })

        #expect(cardio.duration == 8)
        #expect(cardio.exerciseCount == 2)
    }

    @Test func anExerciseArrivesWithEverythingItsCardShows() throws {
        let day = try #require(parseGood().workoutDays.first { $0.dayNumber == 1 })
        let squat = try #require(day.exercises.first)

        #expect(squat.exerciseKey == "goblet_squat")
        #expect(squat.name == "Goblet Squats")
        #expect(squat.measure == .weightAndReps)
        #expect(squat.durationMinutes == 4)
        #expect(squat.prescription == "3 sets of 12 reps")
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

    @Test func anUnknownMeasureDegradesToReps() throws {
        let result = parser.parse(
            goodJSON(replacing: "\"measure\": \"REPS\"", with: "\"measure\": \"DISTANCE\""),
            userID: UUID(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)
        )

        guard case .parsed(let plan) = result else { throw ParserTestFailure.expectedParsed }
        let day = try #require(plan.workoutDays.first { $0.dayNumber == 3 })
        let crunches = try #require(day.exercises.first { $0.exerciseKey == "bicycle_crunch" })
        #expect(crunches.measure == .reps)
    }

    @Test func aStrayTargetTheMeasureDoesNotRenderIsStripped() throws {
        let result = parser.parse(
            goodJSON(replacing: "{ \"reps\": 20 },",
                     with: "{ \"reps\": 20, \"weightKg\": 8, \"seconds\": 40 },"),
            userID: UUID(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)
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

    @Test func malformedJSONIsInvalidNotACrash() throws {
        #expect(try errors(of: "here is your plan! { \"title\": ").count == 1)
        #expect(try !errors(of: "{}").isEmpty)
    }

    @Test func aBlankTitleAndNoDaysAreBothReported() throws {
        let errors = try errors(of: #"{ "title": " ", "days": [] }"#)

        #expect(errors == ["plan: title is blank", "plan: has no days"])
    }

    @Test func aRepeatedDayNumberIsRejected() throws {
        let errors = try errors(of: goodJSON(replacing: "\"dayNumber\": 3,",
                                             with: "\"dayNumber\": 1,"))

        #expect(errors == ["plan: day 1 appears more than once"])
    }

    @Test func aDayNumberOutsideTheWeekIsRejected() throws {
        let errors = try errors(of: goodJSON(replacing: "\"dayNumber\": 3,",
                                             with: "\"dayNumber\": 8,"))

        #expect(errors == ["day 8: dayNumber must be 1..7, Monday to Sunday"])
    }

    @Test func anExerciseKeyThatIsNotASlugIsRejected() throws {
        let errors = try errors(of: goodJSON(replacing: "goblet_squat", with: "Goblet Squat"))

        #expect(errors == [
            "day 1, Goblet Squat: exerciseKey 'Goblet Squat' is not a lower_snake_case slug"
        ])
    }

    @Test func theSameExerciseTwiceInOneDayIsRejected() throws {
        let errors = try errors(of: goodJSON(replacing: "warm_up_jog", with: "bicycle_crunch"))

        #expect(errors == ["day 3: exerciseKey 'bicycle_crunch' appears more than once"])
    }

    @Test func aSetMissingTheTargetItsMeasureNeedsIsRejected() throws {
        let repsErrors = try errors(
            of: goodJSON(replacing: "{ \"reps\": 12, \"weightKg\": 20 },", with: "{},"))
        let secondsErrors = try errors(
            of: goodJSON(replacing: "{ \"seconds\": 300 }", with: "{ \"reps\": 300 }"))

        #expect(repsErrors == ["day 1, goblet_squat, set 1: needs reps between 1 and 100"])
        #expect(secondsErrors == ["day 3, warm_up_jog, set 1: needs seconds between 5 and 5400"])
    }

    @Test func numbersNoClientCouldPerformAreRejected() throws {
        #expect(try errors(of: goodJSON(replacing: "\"restSeconds\": 30,",
                                        with: "\"restSeconds\": -30,"))
            == ["day 3, bicycle_crunch: restSeconds must be 5..600"])
        #expect(try errors(of: goodJSON(replacing: "\"weightKg\": 22.5",
                                        with: "\"weightKg\": 0"))
            == ["day 1, goblet_squat, set 3: weightKg must be between 0.5 and 500.0"])
        #expect(try errors(of: goodJSON(replacing: "{ \"reps\": 12, \"weightKg\": 20 },",
                                        with: "{ \"reps\": 400 },"))
            == ["day 1, goblet_squat, set 1: needs reps between 1 and 100"])
    }

    // A session is a time budget: three sets is not something a two-set
    // session pays for, and the model is told so before it is asked again.
    @Test func aDayThatOverspendsTheSessionIsRejected() throws {
        let result = parser.parse(
            goodJSON,
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
        let errors = try errors(of: goodJSON(replacing: "\"sets\": [{ \"seconds\": 300 }]",
                                             with: "\"sets\": []"))

        #expect(errors == ["day 3, warm_up_jog: has no sets"])
    }

    @Test func everyProblemIsReportedNotJustTheFirst() throws {
        let errors = try errors(
            of: goodJSON(replacing: "\"prescription\": \"5 minutes\"",
                         with: "\"prescription\": \"\"")
                .replacingOccurrences(of: "\"instructions\": \"Alternate elbow to knee.\"",
                                      with: "\"instructions\": \" \"")
        )

        #expect(errors == [
            "day 3, warm_up_jog: prescription is blank",
            "day 3, bicycle_crunch: instructions are blank"
        ])
    }
}
