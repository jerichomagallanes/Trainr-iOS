import SwiftUI

// Shared by the result and its explanation so the citation cannot point somewhere
// different depending on which way the reader found it. No measurements enter a URL.
enum BMISource {
    case calculation
    case categories
    case limitations

    var title: String {
        switch self {
        case .calculation: L10n.bmiCdcCalculation
        case .categories: L10n.bmiCdcCategories
        case .limitations: L10n.bmiCdcAbout
        }
    }

    var url: URL {
        switch self {
        case .calculation, .limitations:
            URL(string: "https://www.cdc.gov/bmi/about/index.html")!
        case .categories:
            URL(string: "https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html")!
        }
    }
}

struct BMISourceLink: View {
    let source: BMISource

    var body: some View {
        Link(destination: source.url) {
            Label(source.title, systemImage: "arrow.up.right.square")
                .font(.body14)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .foregroundStyle(Color.brandStrong)
    }
}
