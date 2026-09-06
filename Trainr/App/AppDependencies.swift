import FirebaseCore
import Foundation
import SwiftData

// The one place the app is wired together. Everything below it takes what it
// needs through init, so a test can hand in a fake of any piece.
@Observable
final class AppDependencies {

    let store: TrainingStore
    let planGenerator: any PlanGenerator
    let breadcrumbs: any Breadcrumbs
    // English-only for now, whatever the device says: the build ships English
    // alone, and the plan's display copy has to match the words around it.
    let languageCode = "en"

    init(store: TrainingStore, planGenerator: any PlanGenerator, breadcrumbs: any Breadcrumbs) {
        self.store = store
        self.planGenerator = planGenerator
        self.breadcrumbs = breadcrumbs
    }

    static func live() -> AppDependencies {
        let container: ModelContainer
        do {
            container = try TrainingStore.container()
        } catch {
            // The store is the app; without it there is nothing to fall back
            // to. In-memory keeps the session alive so the crash report that
            // explains the broken database can actually be written.
            CrashlyticsBreadcrumbs().record("store: persistent container failed, using memory")
            // swiftlint:disable:next force_try
            container = try! TrainingStore.container(inMemory: true)
        }
        let store = TrainingStore(container: container)
        let breadcrumbs = CrashlyticsBreadcrumbs()
        return AppDependencies(
            store: store,
            planGenerator: makePlanGenerator(breadcrumbs: breadcrumbs),
            breadcrumbs: breadcrumbs
        )
    }

    // The shipped build asks the model, through Firebase AI Logic so no key
    // travels inside the app. Development answers from the canned coach — by
    // launch argument (which the UI tests pass), or simply by running a
    // checkout that has no Firebase credentials. A canned week asks no model,
    // so no run of a development build can spend the day's allowance.
    private static func makePlanGenerator(breadcrumbs: any Breadcrumbs) -> any PlanGenerator {
        #if DEBUG
        let canned = ProcessInfo.processInfo.arguments.contains("-cannedGeneration")
            || FirebaseApp.app() == nil
        if canned { return CannedPlanGenerator() }
        #endif
        return GeminiPlanGenerator(
            client: FirebaseAIPlanModelClient(),
            promptBuilder: PlanPromptBuilder(
                canonicalKeys: Set(ExerciseVideoCatalog.videoIDs.keys)
            ),
            spentModels: DailySpentModels(),
            breadcrumbs: breadcrumbs
        )
    }
}
