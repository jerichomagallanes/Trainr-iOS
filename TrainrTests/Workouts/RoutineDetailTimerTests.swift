import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("A countdown running out")
struct RoutineDetailTimerTests {

    private let holdSeconds = 1

    private func heldDay() throws -> (RoutineDetailFixture, RoutineDetailModel) {
        let fixture = try RoutineDetailFixture(holdSeconds: holdSeconds)
        return (fixture, fixture.loaded(day: fixture.firstDayNumber))
    }

    private func hold(_ model: RoutineDetailModel) throws -> ExerciseUi {
        try #require(model.state.routine.exercises.first { $0.measure == .duration })
    }

    private func ranOut(_ model: RoutineDetailModel) async -> Bool {
        for _ in 0..<60 {
            if model.state.timer?.isFinished == true { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return model.state.timer?.isFinished == true
    }

    // The minutes on the card are the whole block rounded up; counting those
    // down would log a hold nobody held.
    @Test("A held set is counted down for the hold it asks for")
    func theCountdownIsTheHold() throws {
        let (_, model) = try heldDay()
        let plank = try hold(model)

        model.startTimer(for: plank)

        #expect(model.state.timer?.totalSeconds == holdSeconds)
        #expect(plank.minutes * Constants.Workout.secondsPerMinute > holdSeconds)
    }

    @Test("It ends on the row at zero rather than disappearing")
    func itEndsWhereItRan() async throws {
        let (_, model) = try heldDay()
        model.startTimer(for: try hold(model))

        let finished = await ranOut(model)
        #expect(finished)

        let timer = try #require(model.state.timer)
        #expect(timer.remainingSeconds == 0)
        #expect(!timer.isRunning)
        model.resumeTimer()
        #expect(model.state.timer?.isRunning == false)
    }

    @Test("It logs the time it measured on a held set and nothing else")
    func itLogsOnlyWhatItMeasured() async throws {
        let (fixture, model) = try heldDay()
        let plank = try hold(model)
        model.startTimer(for: plank)

        let finished = await ranOut(model)
        #expect(finished)

        let exercise = try #require(
            model.state.routine.exercises.first { $0.position == plank.position }
        )
        let set = try #require(exercise.sets.first)
        #expect(set.actualSeconds == holdSeconds)
        #expect(set.actualOrigin == .measured)
        #expect(set.actualReps == nil)
        #expect(set.actualWeightKg == nil)
        #expect(!set.isCompleted)
        #expect(!exercise.isCompleted)

        let stored = try fixture.storedDay(fixture.firstDayNumber)
        let recorded = try #require(stored.exercises.first { $0.measure == .duration })
        #expect(recorded.sets.first?.actualSeconds == holdSeconds)
        #expect(!recorded.isCompleted)
    }

    @Test("Nothing is written onto the exercise counted in reps")
    func repsAreLeftAlone() async throws {
        let (_, model) = try heldDay()
        model.startTimer(for: try hold(model))

        let finished = await ranOut(model)
        #expect(finished)

        let reps = try #require(model.state.routine.exercises.first { $0.measure == .reps })
        #expect(reps.sets.allSatisfy { $0.actualReps == nil && !$0.isCompleted })
        #expect(!reps.isCompleted)
    }

    @Test("The end is announced once")
    func theEndIsAnnouncedOnce() async throws {
        let (_, model) = try heldDay()
        let alerts = Counter()
        model.onTimerFinished = { alerts.bump() }
        model.startTimer(for: try hold(model))

        let finished = await ranOut(model)
        #expect(finished)

        #expect(alerts.count == 1)
    }

    // A screen that was away for the end has nothing to catch up on: a haptic
    // and a tone minutes late belong to no countdown the person can see.
    @Test("The end of a countdown nobody was watching is not kept for later")
    func anUnwatchedEndIsDropped() async throws {
        let (_, model) = try heldDay()
        model.startTimer(for: try hold(model))

        let finished = await ranOut(model)
        #expect(finished)

        let alerts = Counter()
        model.onTimerFinished = { alerts.bump() }
        try await Task.sleep(for: .milliseconds(300))

        #expect(alerts.count == 0)
    }

    @MainActor
    private final class Counter {
        private(set) var count = 0

        func bump() { count += 1 }
    }
}
