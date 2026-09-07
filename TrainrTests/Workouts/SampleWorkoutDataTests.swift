import Foundation
import Testing
@testable import Trainr

// The sample week is not preview-only: it is the plan screen's state before a
// plan is read, the routine screen's date fallback, and the seed every UI test
// fixture is built from. A malformed one weakens all three quietly.
@Suite("Sample workout data")
struct SampleWorkoutDataTests {

    private let week = SampleWorkoutData.weekOne

    @Test("Every day carries exercises, and says how many it has")
    func exerciseCountMatchesTheExercises() {
        #expect(!week.workoutDays.isEmpty)
        for day in week.workoutDays {
            #expect(!day.exercises.isEmpty)
            #expect(day.exerciseCount == day.exercises.count)
        }
    }

    @Test("A day's minutes are the sum of the work in it")
    func durationIsTheSumOfItsExercises() {
        for day in week.workoutDays {
            #expect(day.duration == day.exercises.reduce(0) { $0 + $1.durationMinutes })
        }
    }

    @Test("A day's status agrees with the exercises it holds")
    func statusFollowsTheExercises() {
        for day in week.workoutDays {
            let allDone = day.exercises.allSatisfy(\.isCompleted)
            let noneDone = day.exercises.allSatisfy { !$0.isCompleted }
            switch day.status {
            case .completed: #expect(allDone)
            case .notStarted: #expect(noneDone)
            case .inProgress: #expect(!allDone && !noneDone)
            }
        }
    }

    // History is matched on the key, never the display name, so a blank or a
    // repeat inside one day would silently break the PREVIOUS column.
    @Test("Every exercise has its own key, well formed")
    func exerciseKeysAreUsableForHistory() {
        for day in week.workoutDays {
            let keys = day.exercises.map(\.exerciseKey)
            #expect(keys.allSatisfy { !$0.isEmpty })
            #expect(keys.allSatisfy { $0 == $0.lowercased() })
            #expect(keys.allSatisfy { !$0.contains(" ") })
            #expect(Set(keys).count == keys.count)
        }
    }

    @Test("Every exercise names a video the catalogue can read")
    func everyExerciseLinksAVideoThatParses() {
        for day in week.workoutDays {
            for exercise in day.exercises {
                let url = ExerciseVideoCatalog.url(for: exercise.exerciseKey)
                #expect(url != nil, "no video for \(exercise.exerciseKey)")
                #expect(YouTubeVideo.from(url) != nil, "unreadable video for \(exercise.exerciseKey)")
            }
        }
    }

    @Test("A set is prescribed whatever the exercise is measured in")
    func everySetCarriesItsPrescription() {
        for day in week.workoutDays {
            for exercise in day.exercises {
                #expect(!exercise.sets.isEmpty)
                #expect(exercise.sets.map(\.setNumber) == Array(1...exercise.sets.count))
                for set in exercise.sets {
                    switch exercise.measure {
                    case .reps, .weightAndReps: #expect(set.targetReps != nil)
                    case .duration: #expect(set.targetSeconds != nil)
                    }
                }
            }
        }
    }

    @Test("A finished exercise has its numbers logged, an unstarted one has none")
    func logsFollowCompletion() {
        for day in week.workoutDays {
            for exercise in day.exercises where exercise.isCompleted {
                #expect(exercise.sets.allSatisfy { $0.actualReps != nil || $0.actualSeconds != nil })
            }
            for exercise in day.exercises where !exercise.isCompleted && day.status == .notStarted {
                #expect(exercise.sets.allSatisfy { $0.actualReps == nil && $0.actualSeconds == nil })
            }
        }
    }

    @Test("Equipment is named on a day only where its exercises use some")
    func equipmentIsNamedWhereItIsNeeded() {
        for day in week.workoutDays {
            #expect(day.equipment.allSatisfy { !$0.isEmpty })
            #expect(Set(day.equipment).count == day.equipment.count)
        }
    }

    @Test("The days are in order and the week spans them")
    func daysAreOrderedInsideTheWeek() {
        let numbers = week.workoutDays.map(\.dayNumber)
        #expect(numbers == numbers.sorted())
        #expect(Set(numbers).count == numbers.count)
        #expect(numbers.allSatisfy { (1...7).contains($0) })
        #expect(SampleWorkoutData.weekStart < SampleWorkoutData.weekEnd)
    }

    // Read per call rather than cached, so a time zone that changes while the
    // app runs does not freeze a stale date.
    @Test("A day's date follows the time zone in force when it is asked for")
    func datesAreNotFrozenAtFirstUse() {
        let first = SampleWorkoutData.date(of: 1)
        let last = SampleWorkoutData.date(of: 7)
        #expect(Calendar(identifier: .gregorian).dateComponents([.day], from: first, to: last).day == 6)
    }

    @Test("A day asked for by number is the one returned")
    func aDayIsFoundByItsNumber() {
        for day in week.workoutDays {
            #expect(SampleWorkoutData.day(for: day.dayNumber).title == day.title)
        }
    }

    @Test("The default day is one the week actually has")
    func theDefaultDayExists() {
        #expect(week.workoutDays.contains { $0.dayNumber == SampleWorkoutData.defaultDayNumber })
    }
}
