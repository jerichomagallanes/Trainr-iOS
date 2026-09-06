import SwiftUI

// The animation covers the wait; it must not create one. Generating starts
// with the screen rather than after a timer, and the screen stays only long
// enough to be read when the answer comes back at once.
struct GeneratingView: View {
    let isReady: Bool
    let onStart: () -> Void
    let onDone: () -> Void
    // Non-nil when there is no plan and there will not be one until something
    // changes. The animation stays behind the dialog rather than pretending to
    // still be working.
    var failure: PlanGenerationFailure?
    var onRetry: () -> Void = {}
    var onGiveUp: () -> Void = {}
    var giveUpLabel = L10n.cancel

    @State private var activeIndicator = 0
    @State private var shownAt = Date()

    private static let totalIndicators = 14
    private static let minimumVisible: TimeInterval = 1.5

    var body: some View {
        VStack(spacing: 0) {
            Image("Wordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 48)
                .accessibilityLabel(L10n.trainr)

            Spacer().frame(height: Spacing.extraLarge * 2)

            Text(L10n.generatingYourWorkoutRoutine)
                .font(.sectionTitle)
                .foregroundStyle(Color.slate800)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Spacing.extraLarge)

            loadingIndicator
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task {
            onStart()
            while !Task.isCancelled {
                for index in 0..<Self.totalIndicators {
                    activeIndicator = index
                    try? await Task.sleep(for: .milliseconds(100))
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        .task(id: isReady) {
            guard isReady else { return }
            let shown = Date().timeIntervalSince(shownAt)
            let remaining = max(Self.minimumVisible - shown, 0)
            try? await Task.sleep(for: .seconds(remaining))
            onDone()
        }
        .alert(
            failure == .dailyLimitReached ? L10n.generationLimitTitle : L10n.generationFailedTitle,
            isPresented: .constant(failure != nil)
        ) {
            // Retrying a spent allowance cannot work, so that dialog does not
            // offer it. A button the app already knows will fail is worse than
            // no button: it invites the client to keep tapping and keep failing.
            if failure == .dailyLimitReached {
                // The only thing left to do is leave, so it reads as an
                // acknowledgement rather than as giving up on something.
                Button(L10n.gotIt, action: onGiveUp)
            } else {
                Button(L10n.tryAgain, action: onRetry)
                Button(giveUpLabel, role: .cancel, action: onGiveUp)
            }
        } message: {
            Text(failureMessage)
        }
    }

    private var failureMessage: String {
        switch failure {
        case .offline: L10n.generationFailedOffline
        case .dailyLimitReached: L10n.generationLimitMessage
        case .failed, nil: L10n.generationFailedMessage
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: Spacing.extraSmall) {
            ForEach(0..<Self.totalIndicators, id: \.self) { index in
                let isActive = index <= activeIndicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.orange500 : Color(rgb: 0xCCCCCC))
                    .frame(width: 12, height: 24)
                    .opacity(alpha(for: index))
            }
        }
    }

    private func alpha(for index: Int) -> Double {
        switch index {
        case activeIndicator: 1
        case activeIndicator - 1: 0.8
        case activeIndicator - 2: 0.6
        case ..<activeIndicator: 1
        default: 0.3
        }
    }
}

#Preview {
    GeneratingView(isReady: false, onStart: {}, onDone: {})
}
