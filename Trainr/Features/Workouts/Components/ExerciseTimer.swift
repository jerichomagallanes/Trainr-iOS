import SwiftUI

struct ExerciseTimer: View {
    let timer: ExerciseTimerUi?
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onReset: () -> Void
    let onStop: () -> Void

    var body: some View {
        if let timer {
            VStack(alignment: .leading, spacing: Spacing.card) {
                clock(timer)
                controls(timer)
            }
        } else {
            PillButton(title: L10n.startTimer, systemImage: "play.fill", action: onStart)
        }
    }

    private func clock(_ timer: ExerciseTimerUi) -> some View {
        VStack(spacing: Spacing.tight) {
            Text(timer.display)
                .font(.oneOff(24, .semibold))
                .foregroundStyle(Color.orange500)
                // The digits are read as one changing value rather than
                // announced character by character as they tick.
                .monospacedDigit()
                .accessibilityLabel(timer.display)
            Text(timer.isRunning ? L10n.exerciseInProgress : L10n.timerPaused)
                .font(.body12)
                .foregroundStyle(Color.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.orange500, lineWidth: 2)
        }
    }

    private func controls(_ timer: ExerciseTimerUi) -> some View {
        HStack(spacing: Spacing.tight) {
            if timer.isRunning {
                PillButton(title: L10n.pauseTimer, systemImage: "pause.fill", action: onPause)
            } else {
                PillButton(title: L10n.resumeTimer, systemImage: "play.fill", action: onResume)
            }
            PillButton(
                title: L10n.resetTimer, systemImage: "arrow.clockwise", filled: false, action: onReset
            )
            PillButton(
                title: L10n.stopTimer, systemImage: "stop.fill", filled: false, action: onStop
            )
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.screen) {
        ExerciseTimer(timer: nil, onStart: {}, onPause: {}, onResume: {}, onReset: {}, onStop: {})
        ExerciseTimer(
            timer: ExerciseTimerUi(position: 2, remainingSeconds: 58, isRunning: true),
            onStart: {}, onPause: {}, onResume: {}, onReset: {}, onStop: {}
        )
    }
    .padding(Spacing.screen)
}
