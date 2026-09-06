import SwiftUI

// The "go" mark on a card: a white disc with the outline grey rim and a near-
// black arrow, as the frames export it. A filled dark disc read as a button of
// its own rather than as the card's edge.
struct CardArrow: View {
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.arrowInk)
            .frame(width: 30, height: 30)
            .background(Color.white, in: .circle)
            .overlay { Circle().strokeBorder(Color.outlineGray, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}
