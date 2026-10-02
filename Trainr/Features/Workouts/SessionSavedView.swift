import SwiftUI

struct SessionSavedView: View {
    let performedExercises: Int
    let plannedExercises: Int
    var onBack: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TopBar(onBack: onBack)

            VStack(spacing: 0) {
                Spacer().frame(height: Spacing.section * 2)

                Image("TaskDone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .accessibilityHidden(true)

                Text(L10n.workoutSaved)
                    .font(.oneOff(20, .semibold))
                    .foregroundStyle(Color.onSurface)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.screen)

                Text(L10n.finishedEarlySummaryFormat(performedExercises, plannedExercises))
                    .font(.body16)
                    .lineSpacing(6)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.card)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screen)

            PrimaryButton(title: L10n.done, action: onDone)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.section * 2)
        }
        .background(Color.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SessionSavedView(performedExercises: 4, plannedExercises: 6)
}
