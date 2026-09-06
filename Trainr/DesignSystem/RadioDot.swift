import SwiftUI

// The design's 20pt radio, drawn rather than borrowed from a control: a stock
// toggle carries its own minimum touch target that shoves the visible dot away
// from the corner the frames pin it to. The dot is decoration on a card that is
// itself the button.
struct RadioDot: View {
    let isSelected: Bool
    var color: Color?

    var body: some View {
        let dotColor = color ?? (isSelected ? Color.white : .outlineGray)
        Circle()
            .strokeBorder(dotColor, lineWidth: 2)
            .frame(width: 20, height: 20)
            .overlay {
                if isSelected {
                    Circle().fill(dotColor).frame(width: 10, height: 10)
                }
            }
    }
}
