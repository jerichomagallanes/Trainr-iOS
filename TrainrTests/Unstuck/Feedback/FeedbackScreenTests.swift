import Foundation
import Testing
@testable import Trainr

@Suite("What the follow-up screens say")
struct FeedbackScreenTests {

    @Test("The question names the substitute and the exercise it stood in for")
    func theEquipmentQuestionNamesBoth() {
        let question = SampleFeedbackStates.equipment.question

        #expect(question.contains("Dumbbell Step-Up"))
        #expect(question.contains("Goblet Squat"))
        #expect(SampleFeedbackStates.equipment.affirmative == L10n.feedbackYesEquipment)
    }

    @Test("A shorter session is asked about without naming an exercise")
    func theTimeQuestionNamesNoExercise() {
        #expect(SampleFeedbackStates.time.question == L10n.feedbackTimeBody)
        #expect(SampleFeedbackStates.time.affirmative == L10n.feedbackYesTime)
    }

    @Test("Every answer has its own sentence")
    func everyAnswerHasItsOwnSentence() {
        var seen: Set<String> = []
        for answer in FeedbackAnswer.allCases {
            var state = SampleFeedbackStates.time
            state.answer = answer
            seen.insert(state.outcome.fitSentence)
        }

        #expect(seen.count == FeedbackAnswer.allCases.count - 1)
        #expect(seen.contains(L10n.outcomeHelped))
        #expect(seen.contains(L10n.outcomeStillTooLong))
        #expect(seen.contains(L10n.outcomeConfusing))
        #expect(seen.contains(L10n.outcomeDiscomfort))
        #expect(seen.contains(L10n.outcomeSomethingElse))
    }

    @Test("The question offers the affirmative, the follow-up and discomfort in that order")
    func theQuestionRowsCarryWhatChoosingThemMeans() {
        let options = SampleFeedbackStates.equipment.options

        #expect(options.map(\.title) == [
            L10n.feedbackYesEquipment, L10n.feedbackNotQuite, L10n.feedbackDiscomfort
        ])
        #expect(options.map(\.choice) == [.answer(.helped), .askDetail, .answer(.discomfort)])
        #expect(SampleFeedbackStates.time.options.first?.title == L10n.feedbackYesTime)
    }

    // Choosing it opens the follow-up question instead, so nothing is recorded
    // until that one is answered.
    @Test("Not quite records no answer")
    func notQuiteRecordsNoAnswer() {
        let notQuite = SampleFeedbackStates.time.options.first { $0.title == L10n.feedbackNotQuite }

        #expect(notQuite?.choice == .askDetail)
    }

    @Test("Every row of what still needs changing carries its own answer")
    func everyDetailRowCarriesItsOwnAnswer() {
        let options = FeedbackOption.detail

        #expect(options.map(\.title) == [
            L10n.feedbackStillTooLong, L10n.feedbackExerciseConfusing, L10n.feedbackSomethingElse
        ])
        #expect(options.map(\.choice) == [
            .answer(.stillTooLong), .answer(.exerciseConfusing), .answer(.somethingElse)
        ])
        #expect(options.allSatisfy { $0.description?.isEmpty == false })
    }

    @Test("The outcome is honest about what one session shows")
    func theOutcomeIsHonestAboutOneSession() {
        var state = SampleFeedbackStates.helped
        state.trend = .strength

        let outcome = state.outcome
        #expect(outcome.progressTitle == L10n.progressTowardGoal)
        #expect(outcome.progressBody == L10n.progressNeedMoreFormat(L10n.trendStrength))
        #expect(outcome.caveat == L10n.progressOneSessionCaveat)
        #expect(outcome.unchanged == L10n.futureWorkoutsUnchanged)
    }

    // No score and no improvement percentage: practicality is not a result (C12).
    @Test("Nothing the outcome screen draws is a percentage")
    func nothingOnTheOutcomeScreenIsAPercentage() throws {
        let digitThenPercent = try Regex(#"\d\s*%"#)
        let answers: [FeedbackAnswer?] = [nil] + FeedbackAnswer.allCases.map { $0 }
        var states: [AdjustmentFeedbackState] = []
        for base in [SampleFeedbackStates.time, SampleFeedbackStates.equipment] {
            for answer in answers {
                for trend in [TrendLabel.strength, .trainingPerformance] {
                    var state = base
                    state.answer = answer
                    state.trend = trend
                    states.append(state)
                }
            }
        }

        for state in states {
            let texts = state.outcome.texts
            #expect(!texts.isEmpty)
            for text in texts {
                #expect(text.firstMatch(of: digitThenPercent) == nil)
                #expect(text.rangeOfCharacter(from: .decimalDigits) == nil)
            }
        }
    }

    @Test("The guidance is offered only for an exercise that confused")
    func theGuidanceIsOfferedOnlyWhenTheExerciseConfused() {
        #expect(SampleFeedbackStates.helped.outcome.guidance == nil)
        #expect(SampleFeedbackStates.confusing.outcome.guidance == L10n.viewExerciseGuidance)

        var dropped = SampleFeedbackStates.confusing
        dropped.guidanceKey = nil
        #expect(dropped.outcome.guidance == nil)
    }
}
