import SwiftUI

// Drawn rather than a stock toggle, whose minimum touch target shoves the
// visible dot off the corner. Decoration: the card itself is the button.
struct RadioDot: View {
    let isSelected: Bool
    var color: Color?

    var body: some View {
        let dotColor = color ?? (isSelected ? Color.onSurfaceSelected : .outlineControl)
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
