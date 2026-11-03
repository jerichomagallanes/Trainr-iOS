import SwiftUI

struct BMISourcesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    sourceSection(title: L10n.bmiCalculationTitle,
                                  explanation: L10n.bmiExplanation, source: .calculation)
                    sourceSection(title: L10n.bmiCategoriesTitle,
                                  explanation: L10n.bmiRanges, source: .categories)
                    sourceSection(title: L10n.bmiLimitationsTitle,
                                  explanation: L10n.bmiLimitations, source: .limitations)
                    Text(L10n.bmiSourceDate)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                }
                .font(.body16)
                .foregroundStyle(Color.onSurface)
                .padding(Spacing.large)
            }
            .accessibilityIdentifier("bmiSourcesContent")
            .background(Color.surfacePage)
            .navigationTitle(L10n.bmiAboutSources)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                        .accessibilityIdentifier("bmiSourcesClose")
                }
            }
        }
    }

    private func sourceSection(title: String, explanation: String, source: BMISource) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(title).font(.sectionTitle).accessibilityAddTraits(.isHeader)
            Text(explanation)
            BMISourceLink(source: source)
        }
    }
}
