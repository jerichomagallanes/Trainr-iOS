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
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { reload() }
        .alert(deleteTitle, isPresented: deleteBinding, presenting: weekToDelete) { week in
            Button(L10n.deleteWeekConfirm, role: .destructive) {
                model.deleteWeek(numbered: week.weekNumber)
                leaveIfNothingLeft()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: { week in
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
                    .foregroundStyle(Color.onSurface)

                Rectangle()
                    .fill(Color.outlineDivider)
                    .frame(height: 1)

                // The swipe asks before it deletes: a week is a good deal more
                // than a set.
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

    // Asked right after a read rather than watched, so an empty list that only
    // means "not read yet" can never send the screen away.
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
