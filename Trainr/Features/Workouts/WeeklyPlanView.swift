import SwiftUI

struct WeeklyPlanView: View {

    @Environment(AppearancePreference.self) private var appearance
    // Owned here, so a screen rebuilt around it keeps the week it read.
    @State private var model: WeeklyPlanModel
    private let versionName: String
    private let onDayTap: (WorkoutDay) -> Void
    private let onTrackProgress: () -> Void
    private let onStartWorkout: (WorkoutDay) -> Void
    private let onLeavePlanConfirmed: () -> Void
    private let onUpdateProfile: () -> Void
    private let onOpenPro: () -> Void
    private let onStartNextWeek: () -> Void
    private let onRepeatWeek: () -> Void
    private let onRegenerateWeek: () -> Void
    private let onCreatePlan: () -> Void
    // Set only when a week was opened from Weekly Progress.
    private let onBack: (() -> Void)?

    init(
        dependencies: AppDependencies,
        weekNumber: Int? = nil,
        versionName: String = "",
        onDayTap: @escaping (WorkoutDay) -> Void = { _ in },
        onTrackProgress: @escaping () -> Void = {},
        onStartWorkout: @escaping (WorkoutDay) -> Void = { _ in },
        onLeavePlanConfirmed: @escaping () -> Void = {},
        onUpdateProfile: @escaping () -> Void = {},
        onOpenPro: @escaping () -> Void = {},
        onStartNextWeek: @escaping () -> Void = {},
        onRepeatWeek: @escaping () -> Void = {},
        onRegenerateWeek: @escaping () -> Void = {},
        onCreatePlan: @escaping () -> Void = {},
        onBack: (() -> Void)? = nil
    ) {
        _model = State(
            initialValue: WeeklyPlanModel(dependencies: dependencies, weekNumber: weekNumber)
        )
        self.versionName = versionName
        self.onDayTap = onDayTap
        self.onTrackProgress = onTrackProgress
        self.onStartWorkout = onStartWorkout
        self.onLeavePlanConfirmed = onLeavePlanConfirmed
        self.onUpdateProfile = onUpdateProfile
        self.onOpenPro = onOpenPro
        self.onStartNextWeek = onStartNextWeek
        self.onRepeatWeek = onRepeatWeek
        self.onRegenerateWeek = onRegenerateWeek
        self.onCreatePlan = onCreatePlan
        self.onBack = onBack
    }

    @State private var showLeaveDialog = false
    @State private var showRegenerateDialog = false
    @State private var showAbout = false

    private var state: WeeklyPlanState { model.state }

    // A week already behind you is a record: it keeps its order and offers none
    // of the actions that belong to the week being trained.
    private var isBrowsedWeek: Bool { state.hasPlan && !state.isCurrentWeek }

    // Distinct from isBrowsedWeek: that decides what may be done to a week's
    // contents, this what may be done to the plan as a whole.
    private var isHome: Bool { onBack == nil }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack) {
                if isHome {
                    profileMenu
                }
            }

            if state.hasLoaded {
                if state.hasPlan {
                    plan
                } else {
                    noPlanYet
                }
            } else {
                Spacer()
            }
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.refresh() }
        .alert(L10n.aboutTheApp, isPresented: $showAbout) {
            Button(L10n.close) {}
        } message: {
            Text(L10n.appVersionFormat(versionName) + "\n\n"
                + L10n.appAboutMessage + "\n\n" + L10n.healthDisclaimer)
        }
        .alert(L10n.regenerateWeekTitle, isPresented: $showRegenerateDialog) {
            Button(L10n.regenerateWeekConfirm, role: .destructive, action: onRegenerateWeek)
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.regenerateWeekMessageTrained(loggedWorkouts, state.days.count))
        }
        // Not destructive on purpose, unlike the dialog above: leaving the plan
        // asks the same question the app opened with.
        .alert(L10n.leavePlanTitle, isPresented: $showLeaveDialog) {
            Button(L10n.leavePlanConfirm, action: onLeavePlanConfirmed)
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.leavePlanMessage)
        }
    }

    private var loggedWorkouts: Int {
        state.days.count { $0.day.status == .completed }
    }

    // A List rather than a ScrollView: reorder by long press, edge scrolling and
    // VoiceOver move actions all come free.
    private var plan: some View {
        List {
            Group {
                heading
                // An explicit rule, not a Divider: a list row lays out
                // horizontally, so a Divider draws as a vertical hairline.
                Rectangle()
                    .fill(Color.outlineDivider)
                    .frame(height: 1)
                weekRange
                if isHome {
                    trackProgressLink
                }
            }
            .listRowSeparator(.hidden)
            .listRowInsets(.init(top: 0, leading: 0, bottom: Spacing.medium, trailing: 0))
            .listRowBackground(Color.clear)
            .moveDisabled(true)

            ForEach(state.days) { planDay in
                WorkoutDayCard(
                    weekday: WorkoutDateFormatter.weekday(planDay.date),
                    day: planDay.day,
                    isMissed: planDay.isMissed,
                    onTap: { onDayTap(planDay.day) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 0, leading: 0, bottom: Spacing.medium, trailing: 0))
                .listRowBackground(Color.clear)
                .moveDisabled(isBrowsedWeek || planDay.isFrozen)
            }
            .onMove(perform: move)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
        .contentMargins(.vertical, Spacing.medium, for: .scrollContent)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomAction }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.yourWeeklyWorkoutPlan)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            // The last term keeps the menu on the current week opened from
            // Weekly Progress: it is the week that can be written again, and
            // without it that is the one week with nothing behind the button.
            if state.hasPlan && (isHome || state.canAddWeek || !isBrowsedWeek) {
                planMenu
            }
        }
    }

    private var planMenu: some View {
        Menu {
            if isHome && state.canStartNextWeek {
                Button(L10n.generateNextWeek, action: onStartNextWeek)
            }
            // The copy joins the plan at the end, so it waits for the same
            // moment as a generated week.
            if state.canAddWeek {
                Button(L10n.repeatThisWeek) {
                    onRepeatWeek()
                    // The copy lands with this screen still on top, so nothing
                    // else will re-read the plan for it.
                    model.refresh()
                }
            }
            // The other half of the same question: still in this week, so it
            // can be written again.
            if !state.canAddWeek {
                Button(L10n.regenerateWeek) {
                    if loggedWorkouts > 0 {
                        showRegenerateDialog = true
                    } else {
                        onRegenerateWeek()
                    }
                }
            }
            if isHome {
                Button(L10n.regeneratePlan) { showLeaveDialog = true }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.oneOff(18, .semibold))
                .foregroundStyle(Color.onSurface)
                .frame(width: 44, height: 44, alignment: .trailing)
        }
        .accessibilityLabel(L10n.planOptions)
    }

    private var weekRange: some View {
        Label {
            Text(L10n.weekRangeFormat(
                state.plan.weekNumber,
                WorkoutDateFormatter.weekRange(from: state.weekStart, to: state.weekEnd)
            ))
            .font(.body16)
            .foregroundStyle(Color.onSurface)
        } icon: {
            Image(systemName: "calendar")
                .foregroundStyle(Color.onSurface)
        }
        .font(.body14)
    }

    private var trackProgressLink: some View {
        Button(action: onTrackProgress) {
            Label {
                Text(L10n.trackWeeklyProgress + " →")
                    .font(.labelLarge)
            } icon: {
                Image(.moving)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .foregroundStyle(Color.brandStrong)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // Training is offered wherever the live week was opened from; building the
    // next one is home's business.
    @ViewBuilder
    private var bottomAction: some View {
        if let next = state.nextWorkout, !isBrowsedWeek {
            pinned {
                PrimaryButton(
                    title: state.nextWorkoutIsToday
                        ? L10n.startTodaysWorkout : L10n.startNextWorkout,
                    action: { onStartWorkout(next.day) }
                )
            }
        } else if isHome && state.canStartNextWeek {
            pinned {
                PrimaryButton(title: L10n.generateNextWeek, action: onStartNextWeek)
            }
        }
    }

    private func pinned(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.medium)
            .pinnedBar()
    }

    private var profileMenu: some View {
        @Bindable var preference = appearance
        return Menu {
            Button(L10n.updateProfile, action: onUpdateProfile)
            Button(L10n.proName, action: onOpenPro)
            Picker(L10n.appearance, selection: $preference.mode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            Button(L10n.aboutTheApp) { showAbout = true }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.oneOff(22))
                .foregroundStyle(Color.onSurface)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.profileAndApp)
    }

    private var noPlanYet: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(L10n.noPlanTitle)
                .font(.screenTitle)
                .foregroundStyle(Color.onSurface)
                .multilineTextAlignment(.center)
            Spacer().frame(height: Spacing.small)
            Text(L10n.noPlanMessage)
                .font(.body16)
                .foregroundStyle(Color.onSurfaceMuted)
                .multilineTextAlignment(.center)
            Spacer().frame(height: Spacing.sectionGap)
            PrimaryButton(title: L10n.createMyPlan, action: onCreatePlan)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
    }

    // The list hands back an insertion point, one past the source when a card
    // travels down; the plan speaks in destination indices.
    private func move(from source: IndexSet, to destination: Int) {
        guard let from = source.first else { return }
        model.moveDay(from: from, to: destination > from ? destination - 1 : destination)
    }
}

#Preview {
    NavigationStack {
        WeeklyPlanView(dependencies: .preview, versionName: "1.0.0")
    }
    .environment(AppearancePreference())
}
