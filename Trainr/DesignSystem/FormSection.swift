import SwiftUI

struct FormSection<Content: View>: View {
    let title: String
    var verticalPadding: CGFloat = Spacing.medium
    var titleGap: CGFloat = Spacing.small
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle(text: title)
            Spacer().frame(height: titleGap)
            content
        }
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
