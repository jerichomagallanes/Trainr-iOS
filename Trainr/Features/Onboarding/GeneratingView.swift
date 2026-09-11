import SwiftUI

struct GeneratingView: View {
    let isReady: Bool
    let onStart: () -> Void
    let onDone: () -> Void
    var failure: PlanGenerationResult?
    var failureCount = 0
    var onRetry: () -> Void = {}
    var onGiveUp: () -> Void = {}
    var giveUpLabel = L10n.cancel

    @State private var activeIndicator = 0
    @State private var shownAt = Date()
    // Owned and re-armed by failureCount: an alert on a constant binding never reappears once dismissed.
    @State private var isShowingFailure = false

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
                .foregroundStyle(Color.onSurface)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Spacing.extraLarge)

            loadingIndicator
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePage)
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
            // The wait is restarted whenever readiness changes, which cancels
            // this one. try? swallows that, so without the check a run that was
            // superseded still reported itself done.
            guard !Task.isCancelled else { return }
            onDone()
        }
        .onChange(of: failureCount, initial: true) { _, _ in
            isShowingFailure = failure != nil
        }
        .alert(L10n.generationFailedTitle, isPresented: $isShowingFailure) {
            Button(L10n.tryAgain, action: onRetry)
            Button(giveUpLabel, role: .cancel, action: onGiveUp)
        } message: {
            Text(L10n.generationFailedMessage)
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: Spacing.extraSmall) {
            ForEach(0..<Self.totalIndicators, id: \.self) { index in
                let isActive = index <= activeIndicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(isActive ? Color.brand : Color.barIdle)
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
