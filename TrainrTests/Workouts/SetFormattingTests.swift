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
        #expect(SetFormatting.secondsFromDigits("00130") == 90)
        #expect(SetFormatting.secondsFromDigits("5959") == 3599)
    }

    // 6-3-0 used to stall at 0:06, and writing "63" back as the 1:03 it is
    // stored as would land the third digit in the minutes and read 10:30.
    @Test("A clock is written as the digits typed, not as the seconds they hold")
    func theFaceKeepsTheDigitsTyped() {
        #expect(SetFormatting.clockFace("") == "")
        #expect(SetFormatting.clockFace("6") == "0:06")
        #expect(SetFormatting.clockFace("63") == "0:63")
        #expect(SetFormatting.clockFace("630") == "6:30")
        #expect(SetFormatting.clockFace("164") == "1:64")
        #expect(SetFormatting.clockFace("1640") == "16:40")
        #expect(SetFormatting.clockFace("0:06") == "0:06")
    }

    // A time logged by the exercise timer can run past the four digits the
    // keypad types, and the clock still has to read as the time that is stored.
    @Test("A time past the longest typable one is still shown in full")
    func aLongTimeIsShownInFull() {
        #expect(SetFormatting.clockFace("12000") == "120:00")
        #expect(SetFormatting.seconds(7200) == "120:00")
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

    @Test("A filled cell is named by its column and set")
    func aFilledCellIsNamedByItsColumnAndSet() {
        #expect(
            SetFormatting.cellLabel(column: "Set 1 weight in kilograms", value: "17.5", target: "20")
                == "Set 1 weight in kilograms"
        )
        #expect(
            SetFormatting.cellLabel(column: "Set 2 reps", value: "6", target: "12") == "Set 2 reps"
        )
    }

    // The placeholder is the prescription; reading it as the value claims a set
    // that was never logged.
    @Test("An empty cell offers its target without claiming it")
    func anEmptyCellOffersItsTargetWithoutClaimingIt() {
        #expect(
            SetFormatting.cellLabel(column: "Set 1 reps", value: nil, target: "12")
                == "Set 1 reps, target 12"
        )
        #expect(
            SetFormatting.cellLabel(column: "Set 3 time", value: nil, target: "1:30")
                == "Set 3 time, target 1:30"
        )
    }

    @Test("A cell with neither value nor target is just its column")
    func aCellWithNeitherValueNorTargetIsJustItsColumn() {
        #expect(SetFormatting.cellLabel(column: "Set 1 reps", value: nil, target: nil) == "Set 1 reps")
    }

    @Test("A set cell names the unit its column is showing")
    func aWeightCellNamesItsUnit() {
        #expect(L10n.setWeightCell("1", L10n.weightUnitKilograms) == "Set 1 weight in kilograms")
        #expect(L10n.setWeightCell("1", L10n.weightUnitPounds) == "Set 1 weight in pounds")
        #expect(L10n.setNumberLabel("3") == "Set 3")
    }

    @Test("A timer counts down in the same clock shape")
    func timerDisplayMatches() {
        #expect(ExerciseTimerUi(position: 1, remainingSeconds: 58, isRunning: true).display == "0:58")
        #expect(ExerciseTimerUi(position: 1, remainingSeconds: 600, isRunning: false).display == "10:00")
    }
}
