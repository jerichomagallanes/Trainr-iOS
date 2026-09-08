import SwiftUI
import UIKit

// Swipe-to-delete for a row inside a card: SwiftUI's own swipeActions exist
// only inside a List.
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
                .background(Color.surfaceCard)
                .offset(x: offset)
                .gesture(
                    HorizontalPan(
                        onChanged: { offset = min($0, 0) },
                        onEnded: settle
                    )
                )
        }
        .accessibilityAction(named: label, delete)
        .onChange(of: offset) { _, now in
            if now == 0 { committed = false }
        }
    }

    private var deleteAction: some View {
        Button(action: delete) {
            Image(systemName: "trash")
                .font(.oneOff(16, .semibold))
                .foregroundStyle(Color.onDanger)
                .frame(width: Self.actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.danger)
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

    // Exactly once per swipe: a gesture past the threshold and a tap on the
    // revealed button are the same request.
    private func delete() {
        guard !committed else { return }
        committed = true
        onDelete()
        withAnimation(.snappy(duration: MotionDuration.short)) { offset = 0 }
    }
}

// UIKit rather than DragGesture, which cannot give a touch back: high-priority
// it swallows vertical drags and the page stops scrolling, simultaneous it lets
// the swipe reach the row's button as a tap.
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
