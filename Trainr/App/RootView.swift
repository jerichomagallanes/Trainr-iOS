import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    private enum Phase {
        case splash
        case welcome
        case home
    }

    @State private var dependencies = AppDependencies.shared
    @State private var appearance = AppearancePreference()
    @State private var entitlements = Entitlements(breadcrumbs: AppDependencies.shared.breadcrumbs)
    @State private var ads = Ads(breadcrumbs: AppDependencies.shared.breadcrumbs)
    private let allowance: any FreeGenerationAllowance = StoredGenerationAllowance()
    private let adjustments: any AdjustmentAllowance = StoredAdjustmentAllowance()
    @State private var onboarding: OnboardingModel?
    @State private var phase = Phase.splash
    @State private var path: [Route] = []
    @State private var nextWeek: NextWeekModel?
    // Created when the adjust flow is entered and cleared when it is left, so
    // the draft lives exactly as long as the flow does.
    @State private var adjustment: AdjustmentModel?
    @State private var returningFromAdjustment: AdjustmentReturn?
    // Created when the follow-up is accepted and cleared when it is left, so
    // the one answer it writes belongs to one adjustment.
    @State private var feedback: AdjustmentFeedbackModel?
    @State private var howToRequest: String?
    // Bumped to give home a new identity, and with it a model that re-reads.
    @State private var planGeneration = 0
    @State private var prompt: PaywallReason?
    @State private var afterPrompt: Route?

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
        .environment(ads)
        .preferredColorScheme(appearance.mode.colorScheme)
        // Pushed only once the draft has been through an update of its own: a
        // destination built in the same one captures this view while the model
        // is still nil, and keeps the empty screen it drew. Keyed on which
        // draft rather than on there being one: the interactive back-swipe
        // leaves the model behind, and the next entry still has to push.
        .onChange(of: adjustment.map { ObjectIdentifier($0) }) { _, draft in
            if draft != nil { path.append(.adjustEntry) }
        }
        // Keyed on which question rather than on there being one: the
        // interactive back-swipe leaves the model behind, and the next offer
        // still has to push.
        .onChange(of: feedback.map { ObjectIdentifier($0) }) { _, question in
            if question != nil { path.append(.adjustmentFeedback) }
        }
        .sheet(item: $prompt, onDismiss: openAfterPrompt) { reason in
            ProPromptSheet(reason: reason) {
                afterPrompt = .paywall(reason: reason)
                prompt = nil
            } onDismiss: {
                prompt = nil
            }
        }
        // Configured and read in one task, in that order: a read that starts
        // before the SDK is configured returns nothing, and the gate then asks a
        // paying customer for Pro until the paywall's own refresh lands. The
        // read runs beside startup rather than in front of it, since nothing on
        // the first screen depends on it.
        .task {
            entitlements.configure()
            await entitlements.refresh()
        }
        .task { await ads.gatherConsent() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await ads.gatherConsent() } }
        }
        .task {
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
                onStartNextWeek: { ask(.nextWeek) { path.append(.generatingNextWeek) } },
                onRepeatWeek: { ask(.nextWeek) { nextWeek?.repeatWeek() } },
                onRegenerateWeek: { ask(.rewrite) { path.append(.regeneratingWeek) } },
                onCreatePlan: {
                    path.append(.review(fromPlan: true, profileOnly: false))
                },
                onAdjustToday: { day, minutes in
                    adjustment = AdjustmentModel(
                        dependencies: dependencies, dayNumber: day.dayNumber,
                        reason: .lessTime, minutes: minutes
                    )
                },
                onTrainingPreferences: { path.append(.trainingPreferences) }
            )
            .id(planGeneration)
        }
    }

    // Run once the sheet has finished dismissing, the earliest point a push survives.
    private func openAfterPrompt() {
        guard let next = afterPrompt else { return }
        afterPrompt = nil
        path.append(next)
    }

    // Spent only on a week that arrived.
    private func spendFreeGeneration() {
        guard GenerationGate.spends(isPro: entitlements.isPro, canSell: entitlements.canSell)
        else { return }
        allowance.markUsed()
    }

    // A week already generated is never taken away, so only writing a new one
    // asks for Pro, and it asks where the tap happened rather than by replacing
    // the screen.
    private func ask(_ reason: PaywallReason, then action: () -> Void) {
        switch GenerationGate.decide(
            used: allowance.hasBeenUsed(),
            isPro: entitlements.isPro,
            canSell: entitlements.canSell
        ) {
        case .allowed: action()
        case .ask: prompt = reason
        }
    }

    // The free week is never consulted here: an adjustment is included on its
    // own terms, and the two allowances must not spend each other.
    private func askForAdjustment(_ cycleID: String?, then action: () -> Void) {
        switch AdjustmentGate.decide(
            cycleID: cycleID,
            included: adjustments.includedCycleID(),
            isPro: entitlements.isPro,
            canSell: entitlements.canSell
        ) {
        case .allowed: action()
        case .ask: prompt = .adjust
        }
    }

    // Spent only on a change that was actually applied.
    private func spendAdjustmentCycle(_ cycleID: String) {
        guard AdjustmentGate.spends(isPro: entitlements.isPro, canSell: entitlements.canSell)
        else { return }
        adjustments.consume(cycleID: cycleID)
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
            if route.isOnboarding {
                OnboardingFlowView(
                    step: route,
                    model: onboarding,
                    onStep: step(editing:next:),
                    onEdit: { path.append($0) },
                    onConfirm: { fromPlan, profileOnly in
                        if profileOnly {
                            onboarding.updateProfileOnly { path = [] }
                        } else if fromPlan {
                            ask(.freshPlan) { path.append(.generating) }
                        } else {
                            path.append(.generating)
                        }
                    },
                    // Spent once the week has arrived, whichever tier built it,
                    // so a failed generation costs nothing.
                    onGenerated: {
                        spendFreeGeneration()
                        restartOnHome()
                    },
                    onBack: pop
                )
            } else {
                workoutDestination(for: route)
            }
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
                returningFromAdjustment: $returningFromAdjustment,
                howToRequest: $howToRequest,
                onBack: pop,
                onDayCompleted: { day, week in
                    path.append(.dayCompleted(dayNumber: day, weekNumber: week))
                },
                onWeekCompleted: { week, day in
                    path.append(.weekCompleted(weekNumber: week, dayNumber: day))
                },
                onSessionSaved: {
                    path.append(
                        .sessionSaved(
                            dayNumber: $0.dayNumber,
                            weekNumber: $0.weekNumber,
                            performed: $0.performedExercises,
                            planned: $0.plannedExercises
                        )
                    )
                },
                onAdjust: { reason, exerciseID in
                    adjustment = AdjustmentModel(
                        dependencies: dependencies, dayNumber: dayNumber,
                        weekNumber: weekNumber, reason: reason, exerciseID: exerciseID
                    )
                }
            )

        case .sessionSaved(let dayNumber, let weekNumber, let performed, let planned):
            SessionSavedView(
                performedExercises: performed,
                plannedExercises: planned,
                offer: offer(dayNumber: dayNumber, weekNumber: weekNumber, style: .card),
                onBack: pop,
                onDone: restartOnHome
            )

        case .dayCompleted(let dayNumber, let weekNumber):
            DayCompletedView(
                dayNumber: dayNumber,
                offer: offer(dayNumber: dayNumber, weekNumber: weekNumber, style: .card),
                onBack: pop,
                onViewProgress: { path.append(.weeklyProgress) },
                onBackToPlan: restartOnHome
            )

        case .weekCompleted(let weekNumber, let dayNumber):
            WeekCompletedView(
                weekNumber: weekNumber,
                offer: offer(dayNumber: dayNumber, weekNumber: weekNumber),
                onBack: pop,
                onViewProgress: { path.append(.weeklyProgress) },
                onGenerateNextWeek: { ask(.nextWeek) { path.append(.generatingNextWeek) } }
            )

        case .adjustmentFeedback, .feedbackDetail, .feedbackOutcome, .feedbackPain:
            feedbackDestination(for: route)

        case .weeklyProgress:
            WeeklyProgressView(
                dependencies: dependencies,
                onBack: pop,
                onWeekTap: { path.append(.weekPlan(weekNumber: $0.weekNumber)) },
                onLastWeekDeleted: restartOnHome
            )

        default:
            planDestination(for: route)
        }
    }

    @ViewBuilder
    private func generating(start: @escaping () -> Void) -> some View {
        if let nextWeek {
            GeneratingView(
                isReady: nextWeek.isReady,
                onStart: start,
                onDone: {
                    spendFreeGeneration()
                    restartOnHome()
                },
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

private extension RootView {

    @ViewBuilder
    func planDestination(for route: Route) -> some View {
        switch route {
        // Leaves as soon as Pro is there, whether it was just bought or the
        // entitlement read landed after the gate had already opened this.
        case .paywall(let reason):
            ProPaywallView(reason: reason) { path.removeLast() }
                .onChange(of: entitlements.isPro, initial: true) { _, isPro in
                    if isPro { path.removeLast() }
                }

        // One route, because which of the two belongs here is the entitlement's
        // answer and it can change while the app is open: a purchase, or a read
        // that lands late, swaps the screen rather than throwing the person out.
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
                    ask(.nextWeek) {
                        nextWeek?.repeatWeek(numbered: weekNumber)
                        if nextWeek?.isReady == true { restartOnHome() }
                    }
                },
                onBack: pop
            )

        case .debrief, .noteSaved, .trainingPreferences, .editPreference:
            PreferencesFlowView(
                step: route,
                dependencies: dependencies,
                onOpen: { path.append($0) },
                onReplace: { if !path.isEmpty { path[path.count - 1] = $0 } },
                onDone: restartOnHome,
                onBack: pop
            )

        default:
            adjustDestination(for: route)
        }
    }

    @ViewBuilder
    func adjustDestination(for route: Route) -> some View {
        if let adjustment, route.isAdjustment {
            AdjustFlowView(
                step: route,
                model: adjustment,
                onShowRecommendation: showRecommendation,
                onRouted: { if let next = Route($0) { path.append(next) } },
                onApplied: { spendAdjustmentCycle($0); leaveAdjustment(.reload) },
                onLeave: leaveAdjustment,
                onBack: popAdjustment
            )
        }
    }

    // The recommendation is computed first and only then sold: nothing proposed
    // means there is nothing to sell, and someone whose plan already fits must
    // read that rather than a price.
    func showRecommendation() {
        guard let adjustment else { return }
        let proposalID = adjustment.showRecommendation()
        guard adjustment.state.review != nil else { return }
        guard let proposalID else {
            path.append(.adjustReview)
            return
        }
        askForAdjustment(proposalID) { path.append(.adjustReview) }
    }

    // The draft goes when the last step does: the push watches for one appearing,
    // and a stale one never appears again.
    func popAdjustment() {
        pop()
        if path.last?.isAdjustment != true { adjustment = nil }
    }

    // Opened from home there is no session screen behind the flow to tell, and
    // the cards the change may have moved are home's own.
    func leaveAdjustment(_ returned: AdjustmentReturn) {
        while path.last?.isAdjustment == true { path.removeLast() }
        adjustment = nil
        guard path.contains(where: \.isRoutineDetail) else {
            restartOnHome()
            return
        }
        returningFromAdjustment = returned
    }

    // Nothing here reads the gate or the allowance: one question after a
    // session that used an adjustment is free, and the answer changes no
    // future workout.
    func offer(
        dayNumber: Int, weekNumber: Int, style: FeedbackOffer.Style = .link
    ) -> FeedbackOffer {
        FeedbackOffer(
            dependencies: dependencies,
            dayNumber: dayNumber,
            weekNumber: weekNumber,
            style: style,
            onLeaveNote: {
                path.append(.debrief(dayNumber: dayNumber, weekNumber: weekNumber))
            },
            onOffer: { adjustmentID in
                feedback = AdjustmentFeedbackModel(
                    dependencies: dependencies, adjustmentID: adjustmentID
                )
            }
        )
    }

    @ViewBuilder
    func feedbackDestination(for route: Route) -> some View {
        if let feedback {
            FeedbackFlowView(
                step: route,
                model: feedback,
                onDetail: { path.append(.feedbackDetail) },
                onSaved: routeAfterAnswer,
                onSaveForLater: closeFeedback,
                onOpenGuidance: openGuidance,
                onLeave: leaveFeedback,
                onBack: popFeedback
            )
        }
    }

    func routeAfterAnswer(_ answer: FeedbackAnswer?) {
        switch answer {
        case nil: leaveFeedback()
        // Discomfort goes to the free guidance and is never answered with a
        // substitute (C09).
        case .discomfort: path.append(.feedbackPain)
        case .somethingElse: askForTheirOwnWords()
        default: path.append(.feedbackOutcome)
        }
    }

    // The answer is already recorded, so their own words take the place of the
    // fixed outcome line rather than following it.
    func askForTheirOwnWords() {
        guard let session = feedback?.state.session else {
            path.append(.feedbackOutcome)
            return
        }
        closeFeedback()
        path.append(
            .debrief(dayNumber: session.dayNumber, weekNumber: session.weekNumber)
        )
    }

    func popFeedback() {
        pop()
        if path.last?.isFeedback != true { feedback = nil }
    }

    func closeFeedback() {
        while path.last?.isFeedback == true { path.removeLast() }
        feedback = nil
    }

    func leaveFeedback() {
        restartOnHome()
        feedback = nil
    }

    // Back to the day itself with the exercise named, which is where the how-to
    // already lives; there is no separate guidance screen to push.
    func openGuidance(_ exerciseKey: String) {
        guard let index = path.lastIndex(where: \.isRoutineDetail) else {
            leaveFeedback()
            return
        }
        howToRequest = exerciseKey
        path.removeSubrange((index + 1)...)
        feedback = nil
    }
}
