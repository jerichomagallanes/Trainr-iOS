import Foundation
import SwiftData

@Observable
final class AppDependencies {

    let store: TrainingStore
    let planGenerator: any PlanGenerator
    let breadcrumbs: any Breadcrumbs
    let catalog: any ExerciseCatalog
    let interpreter: any IntentInterpreter
    let modelInstaller: any LocalModelInstaller
    // The only path allowed to change today's plan, and it shares the store's
    // container so both read the one open database.
    let adjustments: AdjustmentStore

    init(
        store: TrainingStore,
        planGenerator: any PlanGenerator,
        breadcrumbs: any Breadcrumbs,
        catalog: any ExerciseCatalog = BundleExerciseCatalog(),
        interpreter: any IntentInterpreter = UnavailableInterpreter(),
        modelInstaller: any LocalModelInstaller = UnavailableModelInstaller()
    ) {
        self.store = store
        self.planGenerator = planGenerator
        self.breadcrumbs = breadcrumbs
        self.catalog = catalog
        self.interpreter = interpreter
        self.modelInstaller = modelInstaller
        self.adjustments = AdjustmentStore(container: store.container, catalog: catalog)
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
        let breadcrumbs = CrashlyticsBreadcrumbs()
        let container: ModelContainer
        do {
            container = try TrainingStore.container(inMemory: startsFresh, breadcrumbs: breadcrumbs)
        } catch {
            // In-memory keeps the session alive long enough to write the
            // crash report that explains the broken database.
            breadcrumbs.record("store: persistent container failed, using memory")
            do {
                container = try TrainingStore.container(inMemory: true)
            } catch {
                // Naming the reason here is what puts it in the crash report.
                breadcrumbs.record("store: memory container failed too: \(error)")
                fatalError("Trainr cannot open a data store: \(error)")
            }
        }
        let store = TrainingStore(container: container)
        #if DEBUG
        UITestFixtures.seedIfRequested(into: store)
        #endif
        let installer = makeModelInstaller()
        let engine = LlamaEngine(modelFile: { installer.readyFile })
        return AppDependencies(
            store: store,
            planGenerator: makePlanGenerator(),
            breadcrumbs: breadcrumbs,
            interpreter: LlamaIntentInterpreter(installer: installer, eligibility: .current, model: engine),
            modelInstaller: installer
        )
    }

    static var preview: AppDependencies {
        // swiftlint:disable:next force_try
        let store = TrainingStore(container: try! TrainingStore.container(inMemory: true))
        return AppDependencies(
            store: store, planGenerator: WeekPlanGenerator(), breadcrumbs: NoBreadcrumbs()
        )
    }

    private static var startsFresh: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        #else
        false
        #endif
    }

    // Last week's movements carried forward wherever nothing forces a change,
    // and a week built from the catalog otherwise.
    private static func makePlanGenerator() -> any PlanGenerator {
        #if DEBUG
        if let failing = UITestFixtures.failingGeneratorIfRequested() { return failing }
        if let slow = UITestFixtures.slowGeneratorIfRequested() { return slow }
        #endif
        return WeekPlanGenerator()
    }

    private static func makeModelInstaller() -> any LocalModelInstaller {
        #if DEBUG
        if let fake = UITestFixtures.fakeModelInstallerIfRequested() { return fake }
        #endif
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(filePath: NSHomeDirectory()).appending(path: "Library/Application Support")
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.jericx.trainr.model")
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = false
        return ModelInstaller(
            directory: support.appending(path: "models"),
            eligibility: .current,
            configuration: configuration,
            freeSpace: { _ in
                let home = URL(filePath: NSHomeDirectory())
                let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                return values?.volumeAvailableCapacityForImportantUsage ?? 0
            }
        )
    }
}
