import SwiftUI
import Testing
@testable import Trainr

@MainActor
@Suite("Week and workout status")
struct WeekStatusTests {

    @Test("Every week status reads back as words")
    func everyStatusIsLabelled() {
        let all: [WeekStatus] = [.completed, .inProgress, .notCompleted, .skipped, .upcoming]
        #expect(all.allSatisfy { !$0.label.isEmpty })
        #expect(Set(all.map(\.label)).count == all.count)
    }

    // The design shows a missed week, a part-done one and one not yet started
    // alike: five labels, three colours.
    @Test("Missed, part-done and upcoming weeks share a colour")
    func fiveLabelsCollapseToThreeColours() {
        #expect(WeekStatus.notCompleted.chipColor == WeekStatus.skipped.chipColor)
        #expect(WeekStatus.skipped.chipColor == WeekStatus.upcoming.chipColor)
        #expect(WeekStatus.upcoming.chipColor == .statusIdle)
    }

    @Test("A finished week and one in progress each keep their own colour")
    func theTwoLiveStatusesAreDistinct() {
        #expect(WeekStatus.completed.chipColor == .statusDone)
        #expect(WeekStatus.inProgress.chipColor == .statusActive)
        #expect(WeekStatus.completed.chipColor != WeekStatus.inProgress.chipColor)
        #expect(WeekStatus.completed.chipColor != WeekStatus.notCompleted.chipColor)
    }

    @Test("A week and a day agree on what finished and in-progress look like")
    func aWeekAndADayShareThePalette() {
        #expect(WeekStatus.completed.chipColor == WorkoutStatus.completed.chipColor)
        #expect(WeekStatus.inProgress.chipColor == WorkoutStatus.inProgress.chipColor)
        #expect(WeekStatus.upcoming.chipColor == WorkoutStatus.notStarted.chipColor)
    }

    @Test("Every workout status reads back as words")
    func everyDayStatusIsLabelled() {
        let all = WorkoutStatus.allCases
        #expect(all.allSatisfy { !$0.label.isEmpty })
        #expect(Set(all.map(\.label)).count == all.count)
    }
}
