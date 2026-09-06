import SwiftUI

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.screenTitle)
            .foregroundStyle(Color.slate800)
    }
}

struct Subtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body14)
            .foregroundStyle(Color.textMuted)
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.sectionTitle)
            .foregroundStyle(Color.slate800)
    }
}
