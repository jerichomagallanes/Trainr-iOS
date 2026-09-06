import SwiftUI
import UIKit

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
                .gesture(
                    HorizontalPan(
                        // Leftwards only: a row that slid right would reveal
                        // nothing.
                        onChanged: { offset = min($0, 0) },
                        onEnded: settle
                    )
                )
        }
        // The same promise without the gesture, for anyone driving the screen
        // by voice, switch or keyboard.
        .accessibilityAction(named: label, delete)
        // Back at rest, the row can be asked again.
        .onChange(of: offset) { _, now in
            if now == 0 { committed = false }
        }
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
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .opacity(offset < 0 ? 1 : 0)
    }

    private func settle(_ translation: CGFloat) {
        let travelled = -translation
        if travelled > Self.actionWidth * 1.5 {
            delete()
            return
        }
        withAnimation(.snappy(duration: MotionDuration.short)) {
            offset = travelled > Self.actionWidth / 2 ? -Self.actionWidth : 0
        }
    }

    // Exactly once per swipe: a gesture that ends past the threshold and a tap
    // on the revealed button are the same request. The row then returns to
    // rest, so one that survives the question the delete asks is not left
    // hanging open.
    private func delete() {
        guard !committed else { return }
        committed = true
        onDelete()
        withAnimation(.snappy(duration: MotionDuration.short)) { offset = 0 }
    }
}

// A pan that answers only to sideways movement. Built on UIKit rather than
// DragGesture because a DragGesture cannot give a touch up once it has it: as
// a high-priority gesture it took every vertical drag and the page stopped
// scrolling, and as a simultaneous one the swipe reached the row's button as
// a tap, opening what was being deleted. A UIKit recogniser that fails on
// vertical movement hands the touch to the scroll view, and one that
// recognises cancels the touch for everything beneath it.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> HorizontalPanRecognizer {
        HorizontalPanRecognizer()
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: HorizontalPanRecognizer, context: Context
    ) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended:
            onEnded(translation)
        case .cancelled, .failed:
            onEnded(0)
        default:
            break
        }
    }
}

private final class HorizontalPanRecognizer: UIPanGestureRecognizer {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        // Decided once, from the first movement past the threshold.
        guard state == .began else { return }
        let velocity = velocity(in: view)
        if abs(velocity.y) > abs(velocity.x) {
            state = .cancelled
        }
    }
}
