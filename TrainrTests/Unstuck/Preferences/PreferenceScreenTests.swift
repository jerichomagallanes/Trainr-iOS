import Foundation
import Testing
@testable import Trainr

@Suite("What the preference screens say")
struct PreferenceScreenTests {

    @Test("Each adjustment kind has its own line, and no adjustment has one too")
    func everyAdjustmentKindHasItsOwnLine() {
        var state = SamplePreferenceStates.filled

        state.todayAdjustment = .shorter
        #expect(state.todayAdjustmentLabel == L10n.adjustmentShorterToday)

        state.todayAdjustment = .alternative
        #expect(state.todayAdjustmentLabel == L10n.adjustmentAlternativeToday)

        state.todayAdjustment = nil
        #expect(state.todayAdjustmentLabel == L10n.noAdjustmentApplied)
    }

    @Test("A remembered limit reads as a weekday, a length and the day it was agreed")
    func aRememberedLimitReadsAsThreeLines() throws {
        let card = try #require(SamplePreferenceStates.filled.preferences.first)

        #expect(card.title == L10n.weekdayTimeLimitFormat("Tuesday"))
        #expect(card.limit == L10n.minutesForWholeSessionFormat(35))
        #expect(card.confirmation == L10n.confirmedByYouFormat("12 Sept 2026"))
    }

    // Both are the screen's two shapes, and the empty one is a read that found
    // nothing rather than a read that has not happened.
    @Test("The empty state is a finished read with nothing in it")
    func theEmptyStateIsAFinishedRead() {
        #expect(SamplePreferenceStates.empty.isLoaded)
        #expect(SamplePreferenceStates.empty.preferences.isEmpty)
        #expect(SamplePreferenceStates.empty.notes.isEmpty)
    }

    @Test("An editor with an unsupported number offers no save")
    func anEditorWithAnErrorOffersNoSave() {
        #expect(SamplePreferenceStates.editing.canSave)
        #expect(SamplePreferenceStates.editing.isPresetSelected)
        #expect(!SamplePreferenceStates.editingWithError.canSave)
        #expect(!SamplePreferenceStates.editingWithError.isPresetSelected)
    }
}
