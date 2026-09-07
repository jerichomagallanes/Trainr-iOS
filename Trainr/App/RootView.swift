import SwiftUI

// Where the app decides what it is showing: the splash while it reads the
// store, then onboarding for a first run or the plan for a returning client.
struct RootView: View {

    private enum Phase {
        case splash
        case welcome
        case home
    }

    @State private var dependencies = AppDependencies.live()
    @State private var onboarding: OnboardingModel?
    @State private var phase = Phase.splash
    @State private var path: [Route] = []
    @State private var nextWeek: NextWeekModel?
    // Bumped whenever the plan is replaced wholesale, to give home a new
    // identity and with it a model that reads the new plan.
    @State private var planGeneration = 0

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .onAppear {
                            // The route taken, so a crash report says which
                            // screen the client was on rather than only which
                            // line failed.
                            dependencies.breadcrumbs.record("screen: \(route.breadcrumbName)")
                        }
                }
        }
        .environment(dependencies)
        .task {
            let model = OnboardingModel(dependencies: dependencies)
            onboarding = model
            try? await Task.sleep(for: .seconds(Self.splashSeconds))
            // A returning user lands on their plan; onboarding is for the
            // first run.
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
                // The profile is already answered, so building another plan
                // starts from it rather than from the first question again.
                // The plan stays underneath, which is what makes the review's
                // close button a real way back out of regenerating.
                onLeavePlanConfirmed: {
                    path.append(.review(fromPlan: true, profileOnly: false))
                },
                onUpdateProfile: { path.append(.review(fromPlan: true, profileOnly: true)) },
                onStartNextWeek: { path.append(.generatingNextWeek) },
                onRepeatWeek: { nextWeek?.repeatWeek() },
                onRegenerateWeek: { path.append(.regeneratingWeek) },
                onCreatePlan: {
                    path.append(.review(fromPlan: true, profileOnly: false))
                }
            )
            // A plan rebuilt from nothing is a different plan, so the screen
            // that shows it starts over too rather than keeping the week it
            // had already read.
            .id(planGeneration)
        }
    }

    // The new plan is a fresh start whichever door led here, so the whole
    // stack goes with it.
    private func restartOnHome() {
        planGeneration += 1
        phase = .home
        path = []
    }

    // Two seconds, unless a UI test asks for longer so it can read the splash.
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
                        // The plan and its history stay exactly as they are;
                        // the edited profile shapes the next week.
                        onboarding.updateProfileOnly { path = [] }
                    } else {
                        path.append(.generating)
                    }
                },
                onBack: pop,
                onEdit: { editRoute in path.append(editRoute) }
            )

        case .generating:
            GeneratingView(
                isReady: onboarding.isCompleted,
                onStart: { onboarding.saveUserProfile() },
                onDone: restartOnHome,
                failure: onboarding.generationFailure,
                failureCount: onboarding.failureCount,
                onRetry: { onboarding.saveUserProfile() },
                // Nothing was written, so the way out is back to the profile
                // the plan would have been built from.
                onGiveUp: pop,
                giveUpLabel: L10n.backToProfile
            )

        default:
            workoutDestination(for: route)
        }
    }

    // The workout surface, kept apart from the questions that lead into it:
    // they are two flows that happen to share a stack.
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
                // The session is over, so the way on is the plan itself rather
                // than the routine that led here.
                onBackToPlan: restartOnHome
            )

        case .weekCompleted(let weekNumber):
            WeekCompletedView(
                weekNumber: weekNumber,
                onBack: pop,
                onViewProgress: { path.append(.weeklyProgress) },
                onGenerateNextWeek: { path.append(.generatingNextWeek) }
            )

        case .weeklyProgress:
            WeeklyProgressView(
                dependencies: dependencies,
                onBack: pop,
                onWeekTap: { path.append(.weekPlan(weekNumber: $0.weekNumber)) },
                // Nothing left to show progress against, so the plan screen
                // takes over: it is the one that can offer to build another.
                onLastWeekDeleted: restartOnHome
            )

        case .generatingNextWeek:
            generating(start: { nextWeek?.generateNextWeek() })

        case .regeneratingWeek:
            generating(start: { nextWeek?.regenerateThisWeek() })

        // A week opened from Weekly Progress: the same screen, given a way back
        // and a particular week to read. Whether it is live or a record is the
        // week's own business, so the screen decides that from what it finds.
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
                // The copy joins the plan at the end, so the week being
                // trained is no longer the one on screen. Refreshing here would
                // re-read the same old week and look like nothing happened, so
                // the way on is home, where the copy now lives.
                onRepeatWeek: {
                    nextWeek?.repeatWeek(numbered: weekNumber)
                    if nextWeek?.isReady == true { restartOnHome() }
                },
                onBack: pop
            )

        // The onboarding routes never reach here; they are answered above.
        default:
            EmptyView()
        }
    }

    // Both ways of writing a week wear the same wait: the difference is which
    // week is being written, and the client is watching the same thing happen.
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
                // The plan they already have is still there to go back to, so
                // this asks to stop waiting rather than offering somewhere new.
                onGiveUp: pop,
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
            // The wordmark rather than the app's name in text: it is the same
            // mark the top bar carries, so the first screen and every screen
            // after it agree about what this app looks like.
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(width: 180)
                .accessibilityLabel(L10n.appName)
            Text(L10n.versionFormat(Self.version))
                .font(.body14)
                .foregroundStyle(Color.slate800)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private static var version: String { RootView.version }
}
