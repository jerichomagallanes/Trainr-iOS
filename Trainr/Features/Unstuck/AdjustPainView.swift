import SwiftUI

// Nothing here reads the gate, the interpreter or the policy: pain is a free
// route with no substitute and no clearance to continue (C09).
struct AdjustPainView: View {
    var onSaveAndFinishEarly: () -> Void = {}
    var onReturn: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        ScreenScaffold(onBack: onBack) {
            VStack(spacing: Spacing.tight) {
                PrimaryButton(title: L10n.saveAndFinishEarly, action: onSaveAndFinishEarly)
                QuietAction(title: L10n.returnToWorkout, action: onReturn)
            }
        } content: {
            ScreenContent {
                Text(L10n.painTitle)
                    .font(.screenTitle)
                    .foregroundStyle(Color.onSurface)
                Text(L10n.painBody)
                    .font(.body14)
                    .foregroundStyle(Color.onSurface)
                    .padding(.top, Spacing.small)

                card

                Text(L10n.painSaveHint)
                    .font(.body14)
                    .foregroundStyle(Color.onSurfaceMuted)
                    .padding(.top, Spacing.medium)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(L10n.painCardTitle)
                .font(.sectionTitle)
                .foregroundStyle(Color.onSurface)
            Text(L10n.painCardBody1)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
            Text(L10n.painCardBody2)
                .font(.body14)
                .foregroundStyle(Color.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.card)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.top, Spacing.medium)
    }
}

#Preview("Light") {
    AdjustPainView()
}

#Preview("Dark") {
    AdjustPainView()
        .preferredColorScheme(.dark)
}
