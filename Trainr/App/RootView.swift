import SwiftUI

struct RootView: View {

    private enum Phase {
        case splash
        case welcome
        case home
    }

    @State private var dependencies = AppDependencies.shared
    @State private var appearance = AppearancePreference()
    @State private var entitlements = Entitlements(breadcrumbs: AppDependencies.shared.breadcrumbs)
    private let allowance: any FreeGenerationAllowance = StoredGenerationAllowance()
    @State private var onboarding: OnboardingModel?
    @State private var phase = Phase.splash
    @State private var path: [Route] = []
    @State private var nextWeek: NextWeekModel?
    // Bumped to give home a new identity, and with it a model that re-reads.
    @State private var planGeneration = 0
    @State private var prompt: PaywallReason?

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .onAppear {
                            dependencies.breadcrumbs.record("screen: \(route.breadcrumbName)")
                        }
                }
        }
        .environment(dependencies)
        .environment(appearance)
        .environment(entitlements)
        .preferredColorScheme(appearance.mode.colorScheme)
        // Reading the entitlement is a network round trip, so it runs beside
        // startup rather than in front of it. Nothing on the first screen depends
        // on it, and the paywall refreshes again when it opens.
        .sheet(item: $prompt) { reason in
            ProPromptSheet(reason: reason) {
                prompt = nil
                path.append(.paywall(reason: reason))
            } onDismiss: {
                prompt = nil
            }
        }
        .task { await entitlements.refresh() }
        .task {
            entitlements.configure()
            let model = OnboardingModel(dependencies: dependencies)
            onboarding = model
            #if DEBUG
            if let start = UITestFixtures.requestedStart() {
                UITestFixtures.seedAnswers(for: start, into: model)
                nextWeek = NextWeekModel(dependencies: dependencies)
                phase = .welcome
                path = UITestFixtures.path(for: start)
                return
            }
            #endif
            try? await Task.sleep(for: .seconds(Self.splashSeconds))
            nextWeek = NextWeekModel(dependencies: dependencies)
            phase = model.hasCompletedOnboarding() ? .home : .welcome
        }
    }

    @ViewBuilder
    private var root: some View {
        switch phase {
        case .splash:
            SplashView()
        case .welcome:
            WelcomeView { path.append(.basicInfo(editing: false)) }
        case .home:
            WeeklyPlanView(
                dependencies: dependencies,
                versionName: Self.version,
                onDayTap: { path.append(.routineDetail(dayNumber: $0.dayNumber, weekNumber: nil)) },
                onTrackProgress: { path.append(.weeklyProgress) },
                onStartWorkout: {
                    path.append(.routineDetail(dayNumber: $0.dayNumber, weekNumber: nil))
                },
                // Starts from the answered profile, with the plan left underneath
                // so the review's close button is a real way back out.
                onLeavePlanConfirmed: {
                    path.append(.review(fromPlan: true, profileOnly: false))
                },
                onUpdateProfile: { path.append(.review(fromPlan: true, profileOnly: true)) },
                onOpenPro: { path.append(.pro) },
                onStartNextWeek: { ask(.nextWeek, toReach: .generatingNextWeek) },
                onRepeatWeek: { nextWeek?.repeatWeek() },
                onRegenerateWeek: { ask(.rewrite, toReach: .regeneratingWeek) },
                onCreatePlan: {
                    path.append(.review(fromPlan: true, profileOnly: false))
                }
            )
            .id(planGeneration)
        }
    }

    // A week already generated is never taken away, so only the act of writing a
    // new one asks for Pro.
    // Spent on a week that arrived, never on one that failed: a model that
    // refused has taken nothing.
    private func spendFreeGeneration() {
        guard !entitlements.isPro else { return }
        allowance.markUsed()
    }

    // A week already generated is never taken away, so only writing a new one
    // asks for Pro, and it asks where the tap happened rather than by replacing
    // the screen.
    private func ask(_ reason: PaywallReason, toReach route: Route) {
        if entitlements.isPro || !allowance.hasBeenUsed() {
            path.append(route)
        } else {
            prompt = reason
        }
    }

    private func restartOnHome() {
        planGeneration += 1
        phase = .home
        path = []
    }

    private static var splashSeconds: Double {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-splashSeconds"),
           arguments.indices.contains(index + 1),
           let seconds = Double(arguments[index + 1]) {
            return seconds
        }
        #endif
        return 2
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        if let onboarding {
            destination(for: route, onboarding: onboarding)
        }
    }

    @ViewBuilder
    private func destination(for route: Route, onboarding: OnboardingModel) -> some View {
        switch route {
        case .basicInfo(let editing):
            BasicInfoView(
                initial: onboarding.filled(for: .basicInfo, editing: editing),
                isEditing: editing,
                onNext: { firstName, age, gender, experience in
                    onboarding.updateBasicInfo(
                        firstName: firstName, age: age, gender: gender, experience: experience)
                    step(editing: editing, next: .bodyMetrics(editing: false))
                },
                onBack: pop
            )

        case .bodyMetrics(let editing):
            BodyMetricsView(
                initial: onboarding.filled(for: .bodyMetrics, editing: editing),
                isEditing: editing,
                onNext: { height, weight, units in
                    onboarding.updateBodyMetrics(height: height, weight: weight, units: units)
                    step(editing: editing, next: .fitnessGoal(editing: false))
                },
                onBack: pop
            )

        case .fitnessGoal(let editing):
            FitnessGoalView(
                initial: onboarding.filled(for: .goals, editing: editing),
                isEditing: editing,
                onNext: { goal, workoutType in
                    onboarding.updateFitnessGoal(goal, workoutType: workoutType)
                    step(editing: editing, next: .workoutSetup(editing: false))
                },
                onBack: pop
            )

        case .workoutSetup(let editing):
            WorkoutSetupView(
                stockedEquipment: onboarding.stockedEquipment,
                initial: onboarding.filled(for: .setup, editing: editing),
                isEditing: editing,
                onNext: { location, equipment, liftingUnits, days, duration, time in
                    onboarding.updateWorkoutSetup(
                        location: location, equipment: equipment, liftingUnits: liftingUnits,
                        daysPerWeek: days, duration: duration, preferredTime: time)
                    step(editing: editing, next: .limitations(editing: false))
                },
                onBack: pop
            )

        case .limitations(let editing):
            LimitationsView(
                initial: onboarding.filled(for: .limitations, editing: editing),
                isEditing: editing,
                onNext: { injuries in
                    onboarding.updateLimitations(injuries: injuries)
                    step(editing: editing, next: .review(fromPlan: false, profileOnly: false))
                },
                onBack: pop
            )

        case .review(let fromPlan, let profileOnly):
            ReviewView(
                profile: onboarding.profile,
                isRegenerating: fromPlan,
                isProfileUpdate: profileOnly,
                onConfirm: {
                    if profileOnly {
                        onboarding.updateProfileOnly { path = [] }
                    } else {
                        if fromPlan {
                            ask(.freshPlan, toReach: .generating)
                        } else {
                            path.append(.generating)
                        }
                    }
                },
                onBack: pop,
                onEdit: { editRoute in path.append(editRoute) }
            )

        case .generating:
            GeneratingView(
                isReady: onboarding.isCompleted,
                onStart: { onboarding.saveUserProfile() },
                onDone: {
                    spendFreeGeneration()
                    restartOnHome()
                },
                failure: onboarding.generationFailure,
                failureCount: onboarding.failureCount,
                onRetry: { onboarding.saveUserProfile() },
                // Nothing was written yet, and cancelRun stops the abandoned
                // run from writing one.
                onGiveUp: {
                    onboarding.cancelRun()
                    pop()
                },
                giveUpLabel: L10n.backToProfile
            )

        default:
            workoutDestination(for: route)
        }
    }

    @ViewBuilder
    private func workoutDestination(for route: Route) -> some View {
        switch route {
        case .routineDetail(let dayNumber, let weekNumber):
            RoutineDetailView(
                dependencies: dependencies,
                dayNumber: dayNumber,
                weekNumber: weekNumber,
                onBack: pop,
                onDayCompleted: { path.append(.dayCompleted(dayNumber: $0)) },
                onWeekCompleted: { path.append(.weekCompleted(weekNumber: $0)) }
            )

        case .dayCompleted(let dayNumber):
            DayCompletedView(
                dayNumber: dayNumber,
                onBack: pop,
                onViewProgress: { path.append(.weeklyProgress) },
                onBackToPlan: restartOnHome
            )

        case .weekCompleted(let weekNumber):
            WeekCompletedView(
                weekNumber: weekNumber,
                onBack: pop,
                onViewProgress: { path.append(.weeklyProgress) },
                onGenerateNextWeek: { ask(.nextWeek, toReach: .generatingNextWeek) }
            )

        case .weeklyProgress:
            WeeklyProgressView(
                dependencies: dependencies,
                onBack: pop,
                onWeekTap: { path.append(.weekPlan(weekNumber: $0.weekNumber)) },
                onLastWeekDeleted: restartOnHome
            )

        case .paywall(let reason):
            ProPaywallView(reason: reason) { path.removeLast() }

        // One route, because which of the two belongs here is the entitlement's
        // answer and it can change while the app is open.
        case .pro:
            if entitlements.isPro {
                ProStatusView { path.removeLast() }
            } else {
                ProPaywallView(reason: nil) { path.removeLast() }
            }

        case .generatingNextWeek:
            generating(start: { nextWeek?.generateNextWeek() })

        case .regeneratingWeek:
            generating(start: { nextWeek?.regenerateThisWeek() })

        case .weekPlan(let weekNumber):
            WeeklyPlanView(
                dependencies: dependencies,
                weekNumber: weekNumber,
                onDayTap: {
                    path.append(
                        .routineDetail(dayNumber: $0.dayNumber, weekNumber: weekNumber)
                    )
                },
                onStartWorkout: {
                    path.append(
                        .routineDetail(dayNumber: $0.dayNumber, weekNumber: weekNumber)
                    )
                },
                // The copy joins the plan at the end, so refreshing here would
                // re-read the old week; home is where the copy now lives.
                onRepeatWeek: {
                    nextWeek?.repeatWeek(numbered: weekNumber)
                    if nextWeek?.isReady == true { restartOnHome() }
                },
                onBack: pop
            )

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func generating(start: @escaping () -> Void) -> some View {
        if let nextWeek {
            GeneratingView(
                isReady: nextWeek.isReady,
                onStart: start,
                onDone: restartOnHome,
                failure: nextWeek.failure,
                failureCount: nextWeek.failureCount,
                onRetry: start,
                onGiveUp: {
                    nextWeek.cancelRun()
                    pop()
                },
                giveUpLabel: L10n.cancel
            )
        }
    }

    private func step(editing: Bool, next: Route) {
        if editing {
            pop()
        } else {
            path.append(next)
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .accessibilityLabel(L10n.appName)
            Text(L10n.versionFormat(Self.version))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePage)
    }

    private static var version: String { RootView.version }
}
