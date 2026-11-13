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
                .foregroundStyle(Color.brandStrong)
                .monospacedDigit()
                .accessibilityLabel(L10n.timerRemaining(timer.display))
                .accessibilityAddTraits(.updatesFrequently)
            Text(note(timer))
                .font(.body12)
                .foregroundStyle(timer.isFinished ? Color.brandStrong : Color.onSurfaceMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.brand, lineWidth: 2)
        }
    }

    private func note(_ timer: ExerciseTimerUi) -> String {
        switch (timer.isFinished, timer.isRunning) {
        case (true, _): L10n.timerFinished
        case (false, true): L10n.exerciseInProgress
        case (false, false): L10n.timerPaused
        }
    }

    private func controls(_ timer: ExerciseTimerUi) -> some View {
        HStack(spacing: Spacing.tight) {
            if !timer.isFinished {
                PillButton(
                    title: timer.isRunning ? L10n.pauseTimer : L10n.resumeTimer,
                    systemImage: timer.isRunning ? "pause.fill" : "play.fill",
                    action: timer.isRunning ? onPause : onResume
                )
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
        ExerciseTimer(
            timer: ExerciseTimerUi(
                position: 6, remainingSeconds: 0, isRunning: false,
                totalSeconds: 300, isFinished: true
            ),
            onStart: {}, onPause: {}, onResume: {}, onReset: {}, onStop: {}
        )
    }
    .padding(Spacing.screen)
}
