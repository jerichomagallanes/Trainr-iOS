import SwiftUI

struct AdjustContextView: View {
    let note: String
    var interpreter = InterpreterUi.unsupported
    var isInterpreting = false
    var hint: ContextHint?
    var onTypeNote: (String) -> Void = { _ in }
    var onChoose: (DirectReason) -> Void = { _ in }
    var onUseNote: () -> Void = {}
    var onInstallModel: () -> Void = {}
    var onCancelInstall: () -> Void = {}
    var onBack: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @FocusState private var isNoteFocused: Bool

    private var text: Binding<String> {
        Binding(get: { note }, set: onTypeNote)
    }

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                if interpreter == .ready {
                    PrimaryButton(
                        title: isInterpreting ? L10n.contextReadingNote : L10n.contextUseNote,
                        isEnabled: !note.isBlank && !isInterpreting
                    ) {
                        isNoteFocused = false
                        onUseNote()
                    }
                }
                QuietAction(title: L10n.backToWorkout, action: onBack)
            }
        } content: {
            ScreenContent {
                Text(L10n.contextTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Text(L10n.contextPrompt)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.medium)
                AppTextArea(placeholder: L10n.contextPlaceholder, text: text)
                    .focused($isNoteFocused)
                    .padding(.top, Spacing.small)
                Text(L10n.contextPrivate)
                    .font(.body12)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.small)

                privateCoaching

                Text(L10n.contextWhichFirst)
                    .font(.sectionTitle)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.large)
                if let hint {
                    Text(hintText(hint))
                        .font(.body14)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .padding(.top, Spacing.tight)
                }
                VStack(spacing: Spacing.tight) {
                    OptionRow(
                        title: L10n.contextOptionTime,
                        description: L10n.contextOptionTimeHint,
                        isEnabled: !isInterpreting
                    ) {
                        onChoose(.lessTime)
                    }
                    OptionRow(
                        title: L10n.contextOptionEquipment,
                        description: L10n.contextOptionEquipmentHint,
                        isEnabled: !isInterpreting
                    ) {
                        onChoose(.equipment)
                    }
                }
                .padding(.top, Spacing.small)
            }
        }
    }

    @ViewBuilder
    private var privateCoaching: some View {
        switch interpreter {
        case .notInstalled:
            OptionRow(
                title: L10n.privateCoachingSetupTitle,
                description: L10n.privateCoachingSetupMessage,
                action: onInstallModel
            )
            .padding(.top, Spacing.medium)
            TextAction(title: L10n.privateCoachingLicence) { openURL(ModelArtifact.lfm25.licenceURL) }
                .padding(.top, Spacing.tight)

        case let .downloading(percent):
            Text(L10n.privateCoachingDownloadingFormat(percent))
                .font(.body14)
                .foregroundStyle(Color.onSurface)
                .padding(.top, Spacing.medium)
            StepProgressBar(currentStep: percent, totalSteps: 100)
                .padding(.top, Spacing.small)
            TextAction(title: L10n.cancel, action: onCancelInstall)
                .padding(.top, Spacing.tight)

        case .verifying:
            notice(L10n.privateCoachingVerifying)

        case .insufficientStorage:
            notice(L10n.privateCoachingStorageMessage)

        case .failed:
            notice(L10n.privateCoachingFailedMessage)
            TextAction(title: L10n.tryAgain, action: onInstallModel)
                .padding(.top, Spacing.tight)

        case .unsupported, .ready:
            EmptyView()
        }
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .padding(.top, Spacing.medium)
    }

    private func hintText(_ hint: ContextHint) -> String {
        switch hint {
        case .chooser: L10n.contextHintChooser
        case .failed: L10n.contextHintFailed
        }
    }
}

#Preview("Light") {
    AdjustContextView(note: "", interpreter: .notInstalled)
}

#Preview("Dark") {
    AdjustContextView(note: "The gym is busy tonight.", interpreter: .ready, hint: .chooser)
        .preferredColorScheme(.dark)
}
