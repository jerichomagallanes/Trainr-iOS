import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("A countdown running out")
struct RoutineDetailTimerTests {

    private let holdSeconds = 1

    private func heldDay(seconds: Int? = nil) throws -> (RoutineDetailFixture, RoutineDetailModel) {
        let fixture = try RoutineDetailFixture(holdSeconds: seconds ?? holdSeconds)
        return (fixture, fixture.loaded(day: fixture.firstDayNumber))
    }

    private func hold(_ model: RoutineDetailModel) throws -> ExerciseUi {
        try #require(model.state.routine.exercises.first { $0.measure == .duration })
    }

    private func fellBelow(_ seconds: Int, _ model: RoutineDetailModel) async -> Bool {
        for _ in 0..<60 {
            if let remaining = model.state.timer?.remainingSeconds, remaining < seconds { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
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

    @Test("A countdown the screen left behind comes back counting from the clock")
    func itComesBackCountingFromTheClock() async throws {
        let (_, model) = try heldDay(seconds: 30)
        model.startTimer(for: try hold(model))

        model.screenWentAway()
        try await Task.sleep(for: .milliseconds(1200))
        let whileAway = try #require(model.state.timer).remainingSeconds
        model.screenCameBack(announcing: {})

        let resumed = try #require(model.state.timer)
        #expect(resumed.isRunning)
        #expect(resumed.remainingSeconds < whileAway)
        #expect(await fellBelow(resumed.remainingSeconds, model))
    }

    // The screen was away for the end, so there is nothing to announce: it is
    // read off the clock and shown at zero instead.
    @Test("A countdown whose end passed while the screen was away reads as finished")
    func anEndThatPassedWhileAwayReadsAsFinished() async throws {
        let (_, model) = try heldDay()
        model.startTimer(for: try hold(model))

        model.screenWentAway()
        try await Task.sleep(for: .milliseconds(1300))
        #expect(model.state.timer?.isFinished == false)

        let alerts = Counter()
        model.screenCameBack(announcing: { alerts.bump() })

        let timer = try #require(model.state.timer)
        #expect(timer.isFinished)
        #expect(!timer.isRunning)
        #expect(timer.remainingSeconds == 0)
        #expect(alerts.count == 0)
    }

    // A countdown belongs to the exercise it was started on, not to the place
    // that exercise held: an adjustment can leave another movement there.
    @Test("An exercise replaced under a running countdown takes the countdown with it")
    func aReplacedExerciseDropsTheCountdown() async throws {
        let (fixture, model) = try heldDay()
        let plank = try hold(model)
        model.startTimer(for: plank)

        try fixture.replace(exerciseID: try #require(plank.exerciseID))
        model.load()
        #expect(model.state.timer == nil)

        try await Task.sleep(for: .milliseconds(1300))
        #expect(model.state.timer == nil)
        let standing = try #require(
            model.state.routine.exercises.first { $0.position == plank.position }
        )
        #expect(standing.exerciseID != plank.exerciseID)
        #expect(standing.sets.allSatisfy { $0.actualSeconds == nil })
        let stored = try fixture.storedDay(fixture.firstDayNumber)
        #expect(stored.exercises.allSatisfy { exercise in
            exercise.sets.allSatisfy { $0.actualSeconds == nil }
        })
    }

    @Test("Ticking the set stops the countdown and leaves nothing behind")
    func tickingTheSetStopsTheCountdown() async throws {
        let (fixture, model) = try heldDay(seconds: 2)
        let plank = try hold(model)
        let alerts = Counter()
        model.onTimerFinished = { alerts.bump() }
        model.startTimer(for: plank)

        var ticked = try #require(plank.sets.first)
        ticked.isCompleted = true
        model.update(ticked, at: plank.position)
        #expect(model.state.timer == nil)

        try await Task.sleep(for: .milliseconds(2400))
        #expect(model.state.timer == nil)
        #expect(alerts.count == 0)

        let exercise = try #require(
            model.state.routine.exercises.first { $0.position == plank.position }
        )
        #expect(exercise.isCompleted)
        #expect(exercise.sets.allSatisfy { $0.actualOrigin != .measured })
        let stored = try fixture.storedDay(fixture.firstDayNumber)
        let recorded = try #require(stored.exercises.first { $0.measure == .duration })
        #expect(recorded.sets.allSatisfy { $0.actualSeconds == nil })
    }

    @MainActor
    private final class Counter {
        private(set) var count = 0

        func bump() { count += 1 }
    }
}
