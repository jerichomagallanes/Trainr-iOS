import SwiftUI
import TrainrDependencies

// One anchored banner sized to the screen's width, the shape Google reserves
// space for up front so the layout does not jump when the ad arrives.
struct AdBanner: View {
    let adUnitID: String

    var body: some View {
        GeometryReader { proxy in
            let size = currentOrientationAnchoredAdaptiveBanner(width: proxy.size.width)
            BannerViewContainer(adUnitID: adUnitID, adSize: size)
                .frame(width: size.size.width, height: size.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width).size.height)
    }
}

private struct BannerViewContainer: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
