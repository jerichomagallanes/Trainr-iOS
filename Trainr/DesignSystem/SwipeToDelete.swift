import SwiftUI

// The list idiom, for a row that is not in a List: swiping left reveals the
// delete, and carrying the swipe past the row's middle commits it. SwiftUI's
// own swipeActions only exist inside a List, and these rows live inside a card.
struct SwipeToDelete<Content: View>: View {

    var label: String
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var committed = false

    private static var actionWidth: CGFloat { 72 }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction
            content
                .background(Color.white)
                .offset(x: offset)
                .highPriorityGesture(swipe)
        }
        // The same promise without the gesture, for anyone driving the screen
        // by voice, switch or keyboard.
        .accessibilityAction(named: label, delete)
    }

    private var deleteAction: some View {
        Button(action: delete) {
            Image(systemName: "trash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: Self.actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.redError)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .clipShape(.rect(cornerRadius: CornerRadius.small))
        .opacity(offset < 0 ? 1 : 0)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                // Leftwards only: a row that slid right would reveal nothing.
                offset = min(value.translation.width, 0)
            }
            .onEnded { value in
                let travelled = -value.translation.width
                if travelled > Self.actionWidth * 1.5 {
                    delete()
                } else {
                    withAnimation(.snappy(duration: MotionDuration.short)) {
                        offset = travelled > Self.actionWidth / 2 ? -Self.actionWidth : 0
                    }
                }
            }
    }

    // Exactly once per row: a gesture that ends past the threshold and a tap on
    // the revealed button are the same request, and a row already on its way
    // out must not ask twice.
    private func delete() {
        guard !committed else { return }
        committed = true
        onDelete()
    }
}
