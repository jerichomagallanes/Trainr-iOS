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

    static func openTrainingStore(_ breadcrumbs: any Breadcrumbs) throws -> ModelContainer {
        try TrainingStore.container(inMemory: startsFresh, breadcrumbs: breadcrumbs)
    }

    // Nothing, when the training data will not open. There is deliberately no
    // in-memory stand-in: an upgrade is when that open is most likely to fail,
    // and a week trained into a store that dies with the process is worse than
    // a session the app refuses to start.
    static func live(
        breadcrumbs: any Breadcrumbs = CrashlyticsBreadcrumbs(),
        open: @MainActor (any Breadcrumbs) throws -> ModelContainer = openTrainingStore
    ) -> AppDependencies? {
        let container: ModelContainer
        do {
            container = try open(breadcrumbs)
        } catch {
            breadcrumbs.report(error, doing: "openTrainingStore")
            return nil
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
