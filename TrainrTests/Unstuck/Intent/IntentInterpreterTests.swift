import Foundation
import Testing
@testable import Trainr

@MainActor
@Suite("The interpreter seam")
struct IntentInterpreterTests {

    @Test("An unavailable interpreter answers unavailable")
    func anUnavailableInterpreterAnswersUnavailable() async {
        let interpreter = UnavailableInterpreter()
        #expect(interpreter.availability == .notInstalled)

        let result = await interpreter.interpret(
            "I have 35 minutes.", locale: Locale(identifier: "en"), directReason: .lessTime
        )

        #expect(result == .unavailable)
    }

    @Test("The app hands out an interpreter that is not installed")
    func theAppHandsOutAnInterpreterThatIsNotInstalled() throws {
        let store = TrainingStore(container: try TrainingStore.container(inMemory: true))
        let dependencies = AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )

        #expect(dependencies.interpreter.availability == .notInstalled)
    }
}
