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
    @State private var weeklyPlan: WeeklyPlanModel?

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
            try? await Task.sleep(for: .seconds(2))
            // A returning user lands on their plan; onboarding is for the
            // first run.
            weeklyPlan = WeeklyPlanModel(dependencies: dependencies)
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
            if let weeklyPlan {
                WeeklyPlanView(
                    model: weeklyPlan,
                    versionName: Self.version,
                    onDayTap: { path.append(.routineDetail(dayNumber: $0.dayNumber, weekNumber: nil)) },
                    onTrackProgress: { path.append(.weeklyProgress) },
                    onStartWorkout: { path.append(.routineDetail(dayNumber: $0.dayNumber, weekNumber: nil)) },
                    onLeavePlanConfirmed: { phase = .welcome },
                    onUpdateProfile: { path.append(.review(fromPlan: true, profileOnly: true)) },
                    onStartNextWeek: { path.append(.generatingNextWeek) },
                    onRepeatWeek: { weeklyPlan.refresh() },
                    onRegenerateWeek: { path.append(.regeneratingWeek) },
                    onCreatePlan: { phase = .welcome }
                )
            }
        }
    }

    // The new plan is a fresh start whichever door led here, so the whole
    // stack goes with it.
    private func restartOnHome() {
        weeklyPlan?.refresh()
        phase = .home
        path = []
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
                onRetry: { onboarding.saveUserProfile() },
                // Nothing was written, so the way out is back to the profile
                // the plan would have been built from.
                onGiveUp: pop,
                giveUpLabel: L10n.backToProfile
            )

        // The rest of the workout surface is still being ported; until it lands
        // these routes say so rather than showing a blank screen.
        default:
            NotPortedYetView()
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

// Stands in for a screen the port has not reached yet.
struct NotPortedYetView: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Image("Wordmark").resizable().scaledToFit().frame(width: 140)
            Text("This screen lands in the next part of the port.")
                .font(.body14)
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }
}
