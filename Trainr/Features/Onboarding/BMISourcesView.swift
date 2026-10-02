import SwiftUI

struct BMISourcesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text(L10n.bmiExplanation)
                    Text(L10n.bmiRanges)
                    Text(L10n.bmiLimitations)
                    Link(L10n.bmiCdcCategories,
                         destination: URL(string: "https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html")!)
                    Link(L10n.bmiCdcAbout,
                         destination: URL(string: "https://www.cdc.gov/bmi/about/index.html")!)
                    Text(L10n.bmiSourceDate)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                }
                .font(.body16)
                .foregroundStyle(Color.onSurface)
                .padding(Spacing.large)
            }
            .background(Color.surfacePage)
            .navigationTitle(L10n.bmiAboutSources)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
    }
}
