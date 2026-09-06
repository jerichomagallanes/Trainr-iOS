import Foundation
import Testing
@testable import Trainr

@Suite("Set formatting")
struct SetFormattingTests {

    @Test("Seconds read as m:ss")
    func secondsAreClockShaped() {
        #expect(SetFormatting.seconds(0) == "0:00")
        #expect(SetFormatting.seconds(9) == "0:09")
        #expect(SetFormatting.seconds(60) == "1:00")
        #expect(SetFormatting.seconds(305) == "5:05")
    }

    @Test("Digits fill in from the seconds end, like a microwave timer")
    func durationIsTypedFromTheRight() {
        #expect(SetFormatting.secondsFromDigits("5") == 5)
        #expect(SetFormatting.secondsFromDigits("45") == 45)
        #expect(SetFormatting.secondsFromDigits("500") == 300)
        #expect(SetFormatting.secondsFromDigits("130") == 90)
        #expect(SetFormatting.secondsFromDigits("") == nil)
        // Only the last four digits count, and leading zeros fall away.
        #expect(SetFormatting.secondsFromDigits("00130") == 90)
    }

    @Test("A stored duration types back to the digits that made it")
    func digitsRoundTrip() {
        for total in [5, 45, 90, 300, 3599] {
            #expect(SetFormatting.secondsFromDigits(SetFormatting.durationDigits(total)) == total)
        }
    }

    @Test("A weight drops a trailing zero but keeps a real fraction")
    func weightsAreReadable() {
        #expect(SetFormatting.weight(20, in: .metric) == "20")
        #expect(SetFormatting.weight(22.5, in: .metric) == "22.5")
    }

    @Test("The previous column shows what was done, never what was asked")
    func previousShowsOnlyLoggedWork() {
        var logged = ExerciseSet(setNumber: 1, targetReps: 10, targetWeightKg: 20)
        logged.actualReps = 12
        logged.actualWeightKg = 25

        #expect(SetFormatting.previousCell(measure: .weightAndReps, previous: logged, units: .metric)
            == "25kg × 12")
        #expect(SetFormatting.previousCell(measure: .reps, previous: logged) == "12")

        // Prescribed but never logged is a dash, not the target.
        let untouched = ExerciseSet(setNumber: 1, targetReps: 10, targetWeightKg: 20)
        #expect(SetFormatting.previousCell(measure: .weightAndReps, previous: untouched)
            == SetFormatting.noPrevious)
        #expect(SetFormatting.previousCell(measure: .reps, previous: nil)
            == SetFormatting.noPrevious)
    }

    @Test("Imperial reads in pounds")
    func imperialUsesPounds() {
        var logged = ExerciseSet(setNumber: 1)
        logged.actualReps = 10
        logged.actualWeightKg = 45.359237

        let cell = SetFormatting.previousCell(
            measure: .weightAndReps, previous: logged, units: .imperial
        )
        #expect(cell.contains("lbs"))
        #expect(cell.contains("100"))
    }

    @Test("A timer counts down in the same clock shape")
    func timerDisplayMatches() {
        #expect(ExerciseTimerUi(position: 1, remainingSeconds: 58, isRunning: true).display == "0:58")
        #expect(ExerciseTimerUi(position: 1, remainingSeconds: 600, isRunning: false).display == "10:00")
    }
}
