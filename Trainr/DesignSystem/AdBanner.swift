import SwiftUI
import TrainrDependencies

// One anchored banner sized to the slot it sits in, the shape Google reserves
// space for up front so the layout does not jump when the ad arrives. Measured
// against the slot's own width and never the screen's: the two agree only while
// the banner is as wide as the window, and the wrong width keeps the wrong
// height.
struct AdBanner: View {
    let adUnitID: String

    var body: some View {
        AdSlot {
            GeometryReader { proxy in
                let size = currentOrientationAnchoredAdaptiveBanner(width: proxy.size.width)
                BannerViewContainer(adUnitID: adUnitID, adSize: size)
                    .frame(width: size.size.width, height: size.size.height)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// The height is answered from the width the slot is offered, before the banner
// inside it is placed, which is the one thing a GeometryReader cannot do.
private struct AdSlot: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        return CGSize(
            width: width,
            height: currentOrientationAnchoredAdaptiveBanner(width: width).size.height
        )
    }

    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
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
