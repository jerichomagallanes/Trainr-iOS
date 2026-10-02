import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("Using the note on the context screen")
struct AdjustmentModelContextTests {

    private static let timeNote = "I have 35 minutes for the whole workout today."
    private static let discomfortNote = "I have 20 minutes and my knee feels off."
    private static let equipmentNote = "The cable machine is taken."

    private let store: TrainingStore

    init() throws {
        store = TrainingStore(container: try TrainingStore.container(inMemory: true))
    }

    private final class FakeInstaller: LocalModelInstaller {
        var state: ModelState
        nonisolated let readyFile: URL? = nil
        private(set) var installs = 0
        private(set) var cancels = 0

        init(_ state: ModelState = .notInstalled) {
            self.state = state
        }

        func install() { installs += 1 }
        func cancel() { cancels += 1 }
    }

    private nonisolated final class ReadyInterpreter: IntentInterpreter, @unchecked Sendable {
        let availability = InterpreterAvailability.ready
        private let answers: AsyncStream<InterpreterResult>
        private(set) var calls: [(note: String, reason: DirectReason?)] = []

        init(_ answers: AsyncStream<InterpreterResult>) {
            self.answers = answers
        }

        convenience init(_ answer: InterpreterResult) {
            self.init(AsyncStream { continuation in
                continuation.yield(answer)
                continuation.finish()
            })
        }

        func interpret(_ text: String, locale: Locale, directReason: DirectReason?) async -> InterpreterResult {
            calls.append((text, directReason))
            for await answer in answers { return answer }
            return .unavailable
        }
    }

    private static func fullDay() -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1),
            planned("barbell_bench_press", sets: 4),
            planned("barbell_bent_over_row", sets: 3),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10),
            planned("bicycle_crunch", sets: 3, reps: 12)
        ])
    }

    private static func partlyDoneDay() -> WorkoutDay {
        testDay([
            planned("warm_up", sets: 1, performed: 1),
            planned("barbell_bench_press", sets: 4, performed: 2),
            planned("dumbbell_bicep_curl", sets: 3, reps: 10)
        ])
    }

    private func model(
        _ day: WorkoutDay = AdjustmentModelContextTests.fullDay(),
        interpreter: any IntentInterpreter = UnavailableInterpreter(),
        installer: any LocalModelInstaller = FakeInstaller()
    ) throws -> AdjustmentModel {
        let profile = testUser()
        try store.saveUser(profile)
        try store.savePlan(
            WeeklyPlan(
                userID: profile.id, weekNumber: 1, title: "Week 1",
                startDate: Calendar(identifier: .gregorian).startOfDay(for: Date()),
                workoutDays: [day]
            )
        )
        let dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs(),
            interpreter: interpreter, modelInstaller: installer
        )
        return AdjustmentModel(dependencies: dependencies, dayNumber: 1, weekNumber: 1, reason: .other)
    }

    private func interpreted(_ note: String, _ extraction: IntentExtraction) throws -> InterpreterResult {
        .interpreted(IntentValidator.validate(try extraction.asJSON(), input: note))
    }

    private func timeAnswer(_ minutes: Int, quote: String) -> IntentExtraction {
        extracted(
            intent: .lessTime,
            timeBudget: TimeBudgetMention(minutes: minutes, scope: .wholeSession),
            evidence: [Evidence(field: .timeBudget, quote: quote)]
        )
    }

    private func timeAnswer() throws -> InterpreterResult {
        try interpreted(Self.timeNote, timeAnswer(35, quote: "35 minutes for the whole workout"))
    }

    @Test("A named part outranks what the model read from the note")
    func aNamedPartOutranksWhatTheModelReadFromTheNote() async throws {
        let interpreter = ReadyInterpreter(try timeAnswer())
        let model = try model(interpreter: interpreter)
        model.typeNote(Self.timeNote)

        #expect(await model.chooseFromContext(.equipment) == .equipment)

        #expect(model.state.reason == .equipment)
        #expect(interpreter.calls.count == 1)
        #expect(interpreter.calls.first?.note == Self.timeNote)
        #expect(interpreter.calls.first?.reason == .other)
    }

    @Test("A discomfort the model reads turns a named time tap into pain")
    func aDiscomfortTheModelReadsTurnsANamedTimeTapIntoPain() async throws {
        let answer = try interpreted(
            Self.discomfortNote,
            extracted(
                intent: .lessTime,
                timeBudget: TimeBudgetMention(minutes: 20, scope: .wholeSession),
                concern: .painOrUnclearDiscomfort,
                evidence: [
                    Evidence(field: .timeBudget, quote: "20 minutes"),
                    Evidence(field: .concern, quote: "my knee feels off")
                ]
            )
        )
        let model = try model(interpreter: ReadyInterpreter(answer))
        model.typeNote(Self.discomfortNote)

        #expect(await model.chooseFromContext(.lessTime) == .pain)
        #expect(model.state.contextHint == nil)
    }

    @Test("A note about missing equipment lands on the equipment screen able to ask")
    func aNoteAboutMissingEquipmentLandsOnTheEquipmentScreenAbleToAsk() async throws {
        let day = Self.fullDay()
        let answer = try interpreted(
            Self.equipmentNote,
            extracted(
                intent: .equipmentUnavailable,
                equipmentMention: "cable machine",
                evidence: [Evidence(field: .equipmentMention, quote: "cable machine")]
            )
        )
        let model = try model(day, interpreter: ReadyInterpreter(answer))
        model.typeNote(Self.equipmentNote)

        #expect(await model.chooseFromContext(.other) == .equipment)

        #expect(model.state.reason == .equipment)
        #expect(model.state.selectedExerciseID == nil)
        model.selectExercise(try #require(day.exercises.first?.id))
        model.toggleEquipment(.dumbbell)
        #expect(model.state.canShowRecommendation)
    }

    @Test("A pain word in the note routes to pain without the model")
    func aPainWordInTheNoteRoutesToPainWithoutTheModel() async throws {
        let interpreter = ReadyInterpreter(try timeAnswer())
        let model = try model(interpreter: interpreter)
        model.typeNote("35 minutes and my knee hurts")

        #expect(await model.chooseFromContext(.other) == .pain)
        #expect(interpreter.calls.isEmpty)
    }

    @Test("Using the note reads it and carries the minutes to the time screen")
    func usingTheNoteReadsItAndCarriesTheMinutesToTheTimeScreen() async throws {
        let interpreter = ReadyInterpreter(try timeAnswer())
        let model = try model(interpreter: interpreter)
        model.typeNote(Self.timeNote)

        #expect(await model.chooseFromContext(.other) == .time)

        #expect(model.state.reason == .lessTime)
        #expect(model.state.selectedMinutes == 35)
        #expect(model.state.canShowRecommendation)
        #expect(model.state.contextHint == nil)
        #expect(!model.state.isInterpreting)
        #expect(model.state.note == Self.timeNote)
        #expect(interpreter.calls.count == 1)
    }

    @Test("A stated number that is no preset goes in the field")
    func aStatedNumberThatIsNoPresetGoesInTheField() async throws {
        let (stream, continuation) = AsyncStream<InterpreterResult>.makeStream()
        let model = try model(interpreter: ReadyInterpreter(stream))
        let minutes = try #require(model.state.presets.first) + 3
        let note = "Only \(minutes) minutes today."
        continuation.yield(try interpreted(note, timeAnswer(minutes, quote: "\(minutes) minutes today")))
        continuation.finish()
        model.typeNote(note)

        #expect(await model.chooseFromContext(.other) == .time)

        #expect(!model.state.presets.contains(minutes))
        #expect(model.state.selectedMinutes == minutes)
        #expect(model.state.customMinutesText == String(minutes))
    }

    @Test("A whole-session number is not carried onto a remaining screen")
    func aWholeSessionNumberIsNotCarriedOntoARemainingScreen() async throws {
        let model = try model(Self.partlyDoneDay(), interpreter: ReadyInterpreter(try timeAnswer()))
        model.typeNote(Self.timeNote)

        #expect(await model.chooseFromContext(.other) == .time)

        #expect(model.state.scope == .remaining)
        #expect(model.state.selectedMinutes == nil)
        #expect(model.state.customMinutesText.isEmpty)
    }

    @Test("The interpreting flag is up while the model reads, and a second tap waits")
    func theInterpretingFlagIsUpWhileTheModelReads() async throws {
        let (stream, continuation) = AsyncStream<InterpreterResult>.makeStream()
        let interpreter = ReadyInterpreter(stream)
        let model = try model(interpreter: interpreter)
        model.typeNote(Self.timeNote)

        let first = Task { await model.chooseFromContext(.other) }
        while !model.state.isInterpreting { await Task.yield() }

        #expect(await model.chooseFromContext(.lessTime) == nil)

        continuation.yield(try timeAnswer())
        continuation.finish()
        #expect(await first.value == .time)
        #expect(!model.state.isInterpreting)
        #expect(interpreter.calls.count == 1)
    }

    @Test("An unclear note shows the chooser hint and keeps the note")
    func anUnclearNoteShowsTheChooserHintAndKeepsTheNote() async throws {
        let note = "Just a weird day."
        let model = try model(interpreter: ReadyInterpreter(try interpreted(note, extracted())))
        model.typeNote(note)

        #expect(await model.chooseFromContext(.other) == .chooser)

        #expect(model.state.contextHint == .chooser)
        #expect(model.state.note == note)
    }

    @Test("A guidance note shows the guide hint")
    func aGuidanceNoteShowsTheGuideHint() async throws {
        let note = "How do I do a hip thrust?"
        let answer = try interpreted(note, extracted(intent: .exerciseGuidance))
        let model = try model(interpreter: ReadyInterpreter(answer))
        model.typeNote(note)

        #expect(await model.chooseFromContext(.other) == .guide)
        #expect(model.state.contextHint == .guide)
    }

    @Test("A failed read shows the failed hint")
    func aFailedReadShowsTheFailedHint() async throws {
        let model = try model(interpreter: ReadyInterpreter(.failed(.timeout)))
        model.typeNote(Self.timeNote)

        #expect(await model.chooseFromContext(.other) == .chooser)

        #expect(model.state.contextHint == .failed)
        #expect(model.state.selectedMinutes == nil)
    }

    @Test("The installer state reaches the screen")
    func theInstallerStateReachesTheScreen() throws {
        let installer = FakeInstaller(.notInstalled)
        let model = try model(installer: installer)

        #expect(model.interpreter == .notInstalled)

        model.installModel()
        installer.state = .downloading(done: 250, total: 1000)
        #expect(model.interpreter == .downloading(percent: 25))

        model.cancelModelInstall()
        installer.state = .ready

        #expect(model.interpreter == .ready)
        #expect(installer.installs == 1)
        #expect(installer.cancels == 1)
    }
}
