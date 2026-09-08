import SwiftUI

struct CardArrow: View {
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.oneOff(14, .semibold))
            .foregroundStyle(Color.arrowInk)
            .frame(width: 30, height: 30)
            .background(Color.arrowDisc, in: .circle)
            .overlay { Circle().strokeBorder(Color.arrowEdge, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}
