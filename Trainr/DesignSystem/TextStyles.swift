import SwiftUI

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.screenTitle)
            .foregroundStyle(Color.onSurface)
    }
}

struct Subtitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body14)
            .foregroundStyle(Color.onSurfaceMuted)
    }
}

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.sectionTitle)
            .foregroundStyle(Color.onSurface)
    }
}
