import FirebaseCore
import Foundation
import SwiftData

@Observable
final class AppDependencies {

    let store: TrainingStore
    let planGenerator: any PlanGenerator
    let breadcrumbs: any Breadcrumbs
    let catalog: any ExerciseCatalog

    init(
        store: TrainingStore,
        planGenerator: any PlanGenerator,
        breadcrumbs: any Breadcrumbs,
        catalog: any ExerciseCatalog = BundleExerciseCatalog()
    ) {
        self.store = store
        self.planGenerator = planGenerator
        self.breadcrumbs = breadcrumbs
        self.catalog = catalog
    }

    // Reported with the action's name and never its subject.
    @discardableResult
    func attempt<T>(_ action: String, _ work: () throws -> T) -> T? {
        do {
            return try work()
        } catch {
            breadcrumbs.report(error, doing: action)
            return nil
        }
    }

    func attempt<T>(_ action: String, _ work: () throws -> T?) -> T? {
        do {
            return try work()
        } catch {
            breadcrumbs.report(error, doing: action)
            return nil
        }
    }

    // Built once for the process: every `live()` call opens a store that stays
    // open until it deallocates.
    static let shared = live()

    static func live() -> AppDependencies {
        let container: ModelContainer
        do {
            container = try TrainingStore.container(inMemory: startsFresh)
        } catch {
            // In-memory keeps the session alive long enough to write the
            // crash report that explains the broken database.
            CrashlyticsBreadcrumbs().record("store: persistent container failed, using memory")
            do {
                container = try TrainingStore.container(inMemory: true)
            } catch {
                // Naming the reason here is what puts it in the crash report.
                CrashlyticsBreadcrumbs().record("store: memory container failed too: \(error)")
                fatalError("Trainr cannot open a data store: \(error)")
            }
        }
        let store = TrainingStore(container: container)
        #if DEBUG
        UITestFixtures.seedIfRequested(into: store)
        #endif
        let breadcrumbs = CrashlyticsBreadcrumbs()
        return AppDependencies(
            store: store,
            planGenerator: makePlanGenerator(breadcrumbs: breadcrumbs),
            breadcrumbs: breadcrumbs
        )
    }

    static var preview: AppDependencies {
        // swiftlint:disable:next force_try
        let store = TrainingStore(container: try! TrainingStore.container(inMemory: true))
        return AppDependencies(
            store: store, planGenerator: TemplatePlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
    }

    private static var startsFresh: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        #else
        false
        #endif
    }

    // Debug builds get the week the app builds with no model at all (launch
    // argument, or no Firebase credentials): the same assembly prod falls back
    // on, and no development run spends the day's model allowance.
    private static func makePlanGenerator(breadcrumbs: any Breadcrumbs) -> any PlanGenerator {
        #if DEBUG
        if let failing = UITestFixtures.failingGeneratorIfRequested() { return failing }
        if let slow = UITestFixtures.slowGeneratorIfRequested() { return slow }
        let canned = ProcessInfo.processInfo.arguments.contains("-cannedGeneration")
            || FirebaseApp.app() == nil
        if canned { return TemplatePlanGenerator() }
        #endif
        return GeminiPlanGenerator(
            client: FirebaseAIPlanModelClient(),
            promptBuilder: PlanPromptBuilder(),
            catalog: BundleExerciseCatalog(),
            spentModels: DailySpentModels(),
            breadcrumbs: breadcrumbs
        )
    }
}
