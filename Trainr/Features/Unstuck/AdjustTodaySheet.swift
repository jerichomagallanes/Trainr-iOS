import SwiftUI

struct AdjustTodaySheet: View {
    private let dayTitle: String
    private let exercises: [String]
    private let onChoose: (DirectReason) -> Void
    private let onShowHowTo: (Int) -> Void
    private let onDismiss: () -> Void

    @State private var isPickingExercise: Bool
    @State private var content: CGFloat?
    @State private var inset: CGFloat = 0

    init(
        dayTitle: String,
        exercises: [String],
        startOnExercises: Bool = false,
        onChoose: @escaping (DirectReason) -> Void = { _ in },
        onShowHowTo: @escaping (Int) -> Void = { _ in },
        onDismiss: @escaping () -> Void = {}
    ) {
        self.dayTitle = dayTitle
        self.exercises = exercises
        _isPickingExercise = State(initialValue: startOnExercises)
        self.onChoose = onChoose
        self.onShowHowTo = onShowHowTo
        self.onDismiss = onDismiss
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.tight) {
                Text(L10n.adjustSheetEyebrowFormat(dayTitle.lowercased()))
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                Text(isPickingExercise ? L10n.guidePickExercise : L10n.adjustSheetTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)

                if isPickingExercise {
                    ForEach(Array(exercises.enumerated()), id: \.offset) { index, name in
                        OptionRow(title: name, description: L10n.adjustReasonGuidanceHint) {
                            onShowHowTo(index + 1)
                        }
                    }
                } else {
                    reasons
                }

                QuietAction(title: L10n.keepTodaysPlan, action: onDismiss)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.large)
            .padding(.top, Spacing.medium)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { content = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset = $0 }
        // Five choices and a quiet action do not fit a half sheet, and a choice
        // nobody can see is not a choice.
        .presentationDetents([content.map { .height($0 + inset) } ?? .large])
        .presentationBackground(Color.surfaceCard)
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var reasons: some View {
        Text(L10n.adjustSheetSubtitle)
            .font(.body14)
            .foregroundStyle(Color.onSurfaceMuted)
        OptionRow(title: L10n.adjustReasonTime, description: L10n.adjustReasonTimeHint) {
            onChoose(.lessTime)
        }
        OptionRow(title: L10n.adjustReasonEquipment, description: L10n.adjustReasonEquipmentHint) {
            onChoose(.equipment)
        }
        OptionRow(title: L10n.adjustReasonGuidance, description: L10n.adjustReasonGuidanceHint) {
            isPickingExercise = true
        }
        OptionRow(title: L10n.adjustReasonPain, description: L10n.adjustReasonPainHint) {
            onChoose(.pain)
        }
        OptionRow(title: L10n.adjustReasonOther, description: L10n.adjustReasonOtherHint) {
            onChoose(.other)
        }
    }
}

#Preview("Light") {
    Color.surfacePage.sheet(isPresented: .constant(true)) {
        AdjustTodaySheet(dayTitle: "Upper Body Push", exercises: SampleAdjustmentStates.exerciseNames)
    }
}

#Preview("Dark") {
    Color.surfacePage.sheet(isPresented: .constant(true)) {
        AdjustTodaySheet(
            dayTitle: "Upper Body Push",
            exercises: SampleAdjustmentStates.exerciseNames,
            startOnExercises: true
        )
    }
    .preferredColorScheme(.dark)
}
