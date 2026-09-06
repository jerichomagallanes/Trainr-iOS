import SwiftUI

struct WeeklyProgressView: View {

    @State private var model: WeeklyProgressModel
    private let onBack: () -> Void
    private let onWeekTap: (WeekProgressUi) -> Void
    private let onLastWeekDeleted: () -> Void

    @State private var weekToDelete: WeekProgressUi?

    init(
        dependencies: AppDependencies,
        onBack: @escaping () -> Void = {},
        onWeekTap: @escaping (WeekProgressUi) -> Void = { _ in },
        onLastWeekDeleted: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: WeeklyProgressModel(dependencies: dependencies))
        self.onBack = onBack
        self.onWeekTap = onWeekTap
        self.onLastWeekDeleted = onLastWeekDeleted
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack)
            weeks
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        // Coming back from a routine re-reads the plans, so a day completed
        // there is reflected here.
        .onAppear { reload() }
        .alert(deleteTitle, isPresented: deleteBinding, presenting: weekToDelete) { week in
            Button(L10n.deleteWeekConfirm, role: .destructive) {
                model.deleteWeek(numbered: week.weekNumber)
                leaveIfNothingLeft()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: { week in
            // Training that was actually done is named before it goes, so the
            // choice is made knowing what it costs.
            Text(
                week.hasTraining
                    ? L10n.deleteWeekMessageTrained(week.completedDays, week.totalDays)
                    : L10n.deleteWeekMessage
            )
        }
    }

    private var weeks: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.screen) {
                Text(L10n.weeklyProgress)
                    .font(.screenTitle)
                    .foregroundStyle(Color.slate800)

                Rectangle()
                    .fill(Color.dividerGray)
                    .frame(height: 1)

                // Every week slides aside; the dialog is where the weight of it
                // lands. A week is a good deal more than a set, so the swipe
                // asks before it deletes.
                ForEach(model.weeks) { week in
                    SwipeToDelete(
                        label: L10n.deleteWeekConfirm,
                        onDelete: { weekToDelete = week },
                        content: {
                            WeekProgressCard(
                                week: week,
                                dateRange: WorkoutDateFormatter.weekRange(
                                    from: week.startDate, to: week.endDate, abbreviated: true
                                ),
                                onTap: { onWeekTap(week) }
                            )
                        }
                    )
                    .id(week.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.medium)
        }
    }

    private func reload() {
        model.refresh()
        leaveIfNothingLeft()
    }

    // Delete the last week and this screen is a list of nothing. Progress
    // against no plan is not a place to stand, so it hands back to the one
    // screen that has something to say about having no plan — and something to
    // do about it. Asked right after a read rather than watched, so an empty
    // list that only means "not read yet" can never send the screen away.
    private func leaveIfNothingLeft() {
        guard model.hasLoaded, model.weeks.isEmpty else { return }
        onLastWeekDeleted()
    }

    private var deleteTitle: String {
        weekToDelete.map { L10n.deleteWeekTitle($0.weekNumber) } ?? ""
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { weekToDelete != nil }, set: { if !$0 { weekToDelete = nil } })
    }
}
