import SwiftUI

struct WeeklyPlanView: View {

    @Bindable var model: WeeklyPlanModel
    var versionName = ""
    var onDayTap: (WorkoutDay) -> Void = { _ in }
    var onTrackProgress: () -> Void = {}
    var onStartWorkout: (WorkoutDay) -> Void = { _ in }
    var onLeavePlanConfirmed: () -> Void = {}
    var onUpdateProfile: () -> Void = {}
    var onStartNextWeek: () -> Void = {}
    var onRepeatWeek: () -> Void = {}
    var onRegenerateWeek: () -> Void = {}
    var onCreatePlan: () -> Void = {}
    // Set only when a week was opened from Weekly Progress.
    var onBack: (() -> Void)?

    @State private var showLeaveDialog = false
    @State private var showRegenerateDialog = false
    @State private var showAbout = false

    private var state: WeeklyPlanState { model.state }

    // Such a week is a look at the record rather than the plan being trained,
    // so it gets a way back and drops the actions that belong to the plan
    // standing in as home. A week already behind you keeps its dates and its
    // order, and offers none of the actions that belong to the week being
    // trained. The newest week is live wherever it was opened from, so home and
    // the list show the same thing rather than two versions of it.
    private var isBrowsedWeek: Bool { state.hasPlan && !state.isCurrentWeek }

    // Two different questions, and one flag was answering both. Whether the week
    // is live decides what may be done to its contents. Whether this is home
    // decides what may be done to the plan as a whole: a week opened from the
    // list is a week you went to see, so it does not carry the actions that
    // rebuild the plan, nor a link back to the list you came from.
    private var isHome: Bool { onBack == nil }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack) {
                // Who you are belongs to home, not to a week you opened from
                // somewhere else: a screen with a way back is somewhere you
                // went, and the account is not part of what you went to see.
                if isHome {
                    profileMenu
                }
            }

            // Nothing is drawn until the plan has been looked for: a blank
            // moment is honest, where a stand-in week would be read as the real
            // thing.
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
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.refresh() }
        .alert(L10n.aboutTheApp, isPresented: $showAbout) {
            Button(L10n.close) {}
        } message: {
            // Kept reachable after onboarding: the review shows it once, and a
            // client training months later has nowhere else to find it.
            Text(L10n.appVersionFormat(versionName) + "\n\n"
                + L10n.appAboutMessage + "\n\n" + L10n.healthDisclaimer)
        }
        // A week with nothing logged in it is just a week; one with training in
        // it is a record, and what a new week costs is named before it is asked
        // for.
        .alert(L10n.regenerateWeekTitle, isPresented: $showRegenerateDialog) {
            Button(L10n.regenerateWeekConfirm, role: .destructive, action: onRegenerateWeek)
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.regenerateWeekMessageTrained(loggedWorkouts, state.days.count))
        }
        .alert(L10n.leavePlanTitle, isPresented: $showLeaveDialog) {
            Button(L10n.leavePlanConfirm, role: .destructive, action: onLeavePlanConfirmed)
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.leavePlanMessage)
        }
    }

    private var loggedWorkouts: Int {
        state.days.count { $0.day.status == .completed }
    }

    // The week is one list rather than a scroll view wrapping another: the day
    // cards reorder by long press, scroll themselves at the edges and announce
    // their move actions to VoiceOver, none of which a hand-rolled drag would
    // get for free.
    private var plan: some View {
        List {
            Group {
                heading
                // An explicit rule rather than a Divider: a list row lays its
                // content out horizontally, where a Divider draws itself as a
                // vertical hairline.
                Rectangle()
                    .fill(Color.dividerGray)
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
                // A finished session is the record of a date it was actually
                // trained on, and a week being read back is a record entire.
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
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Repeating is the one action a week can offer about itself: its
            // subject is the week you are looking at, not the plan, so it
            // belongs on whichever week that is. Building the next week and
            // starting over are about the plan's future, and stay on home,
            // which is where they have somewhere to go afterwards.
            if isHome || state.canAddWeek {
                planMenu
            }
        }
    }

    private var planMenu: some View {
        Menu {
            // With the week behind you there are two sound ways on: progress
            // from what you lifted, or run the same week again. The second is a
            // coaching decision, so it is offered rather than assumed.
            if isHome && state.canStartNextWeek {
                Button(L10n.generateNextWeek, action: onStartNextWeek)
            }
            // Any week can be run again, this one or one from months ago; the
            // copy joins the plan at the end, which is why it waits for the same
            // moment as a generated week rather than landing on top of one still
            // being trained.
            if state.canAddWeek {
                Button(L10n.repeatThisWeek, action: onRepeatWeek)
            }
            // The other half of the same question: still in this week, so it can
            // be written again; done with it, and the offer becomes the week
            // that follows.
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
                Button(L10n.regeneratePlan, role: .destructive) { showLeaveDialog = true }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.slate800)
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
            .foregroundStyle(Color.slate800)
        } icon: {
            Image(systemName: "calendar")
                .foregroundStyle(Color.slate800)
        }
        .font(.body14)
    }

    private var trackProgressLink: some View {
        Button(action: onTrackProgress) {
            Label {
                Text(L10n.trackWeeklyProgress + " →")
                    .font(.labelLarge)
            } icon: {
                Image(systemName: "chart.line.uptrend.xyaxis")
            }
            .foregroundStyle(Color.orange500)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // Whatever is actually left: a session to train, or — with the week behind
    // you — the week that follows it. Never a finished session dressed as the
    // next one. Training is offered wherever the live week was opened from;
    // building the next one is home's business.
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
            .background(
                Color.white.shadow(.drop(color: .black.opacity(0.08), radius: 4, y: -2))
            )
    }

    // Who you are and what the app is: the two things that are about the client
    // rather than about this week's training, kept out of the plan's own menu.
    private var profileMenu: some View {
        Menu {
            Button(L10n.updateProfile, action: onUpdateProfile)
            Button(L10n.aboutTheApp) { showAbout = true }
        } label: {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.slate800)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(L10n.profileAndApp)
    }

    // Deleting every week is allowed, so landing there has to be a place rather
    // than a gap: it says what happened and offers the way out of it.
    private var noPlanYet: some View {
        VStack(spacing: 0) {
            Spacer()
            Text(L10n.noPlanTitle)
                .font(.screenTitle)
                .foregroundStyle(Color.slate800)
                .multilineTextAlignment(.center)
            Spacer().frame(height: Spacing.small)
            Text(L10n.noPlanMessage)
                .font(.body16)
                .foregroundStyle(Color.textMuted)
                .multilineTextAlignment(.center)
            Spacer().frame(height: Spacing.sectionGap)
            PrimaryButton(title: L10n.createMyPlan, action: onCreatePlan)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
    }

    // The list hands back an insertion point, which is one past the source when
    // a card travels down; the plan speaks in destination indices.
    private func move(from source: IndexSet, to destination: Int) {
        guard let from = source.first else { return }
        model.moveDay(from: from, to: destination > from ? destination - 1 : destination)
    }
}

#Preview {
    NavigationStack {
        WeeklyPlanView(
            model: WeeklyPlanModel(dependencies: .preview),
            versionName: "1.0.0"
        )
    }
}
