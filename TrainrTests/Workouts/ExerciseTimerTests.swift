import Foundation
import Testing
@testable import Trainr

@Suite("Exercise timer")
struct ExerciseTimerTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func after(_ seconds: Double) -> Date { start.addingTimeInterval(seconds) }

    @Test("A running timer reads the clock, not the number of ticks it was given")
    func remainingFollowsTheClock() {
        var timer = ExerciseTimerUi.running(position: 1, totalSeconds: 60, from: start)

        let afterOne = timer.advance(to: after(1))
        #expect(afterOne)
        #expect(timer.remainingSeconds == 59)
        // A tick that arrives late does not lose the seconds it missed.
        let afterTwelve = timer.advance(to: after(12.4))
        #expect(afterTwelve)
        #expect(timer.remainingSeconds == 48)
    }

    @Test("A fraction of a second left still reads as one")
    func roundsUp() {
        let timer = ExerciseTimerUi.running(position: 1, totalSeconds: 10, from: start)
        #expect(timer.remaining(at: after(9.3)) == 1)
        #expect(timer.remaining(at: after(10)) == 0)
        #expect(timer.remaining(at: after(30)) == 0)
    }

    @Test("Running out ends the timer, however late the clock is read")
    func runningOutEndsIt() {
        var timer = ExerciseTimerUi.running(position: 1, totalSeconds: 5, from: start)
        let onTime = timer.advance(to: after(5))
        #expect(!onTime)
        #expect(timer.remainingSeconds == 0)

        var late = ExerciseTimerUi.running(position: 1, totalSeconds: 5, from: start)
        let longAfter = late.advance(to: after(120))
        #expect(!longAfter)
    }

    @Test("Pausing keeps what was left, and resuming carries on from there")
    func pauseAndResume() {
        var timer = ExerciseTimerUi.running(position: 1, totalSeconds: 60, from: start)
        timer.pause(at: after(20))
        #expect(!timer.isRunning)
        #expect(timer.remainingSeconds == 40)
        #expect(timer.endsAt == nil)
        // Time spent paused does not count.
        #expect(timer.remaining(at: after(500)) == 40)

        timer.resume(at: after(500))
        #expect(timer.isRunning)
        #expect(timer.remaining(at: after(510)) == 30)
    }

    @Test("Reset goes back to the top of the interval and holds there")
    func reset() {
        var timer = ExerciseTimerUi.running(position: 1, totalSeconds: 90, from: start)
        _ = timer.advance(to: after(33))
        timer.reset()
        #expect(timer.remainingSeconds == 90)
        #expect(!timer.isRunning)
        #expect(timer.remaining(at: after(1000)) == 90)
        #expect(timer.display == "1:30")
    }
}
