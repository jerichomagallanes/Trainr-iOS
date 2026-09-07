import SwiftUI

struct CardArrow: View {
    var body: some View {
        Image(systemName: "arrow.forward")
            .font(.oneOff(14, .semibold))
            .foregroundStyle(Color.arrowInk)
            .frame(width: 30, height: 30)
            .background(Color.white, in: .circle)
            .overlay { Circle().strokeBorder(Color.outlineGray, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}
