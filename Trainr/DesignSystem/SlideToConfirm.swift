import SwiftUI

// A deliberate action that a tap would make too easy to do by accident: the
// thumb travels the track, and only a slide that reaches the far end confirms.
struct SlideToConfirm: View {

    let title: String
    let action: () -> Void

    @State private var offset: CGFloat = 0

    private static let trackHeight: CGFloat = 55
    private static let thumbSize: CGFloat = 35
    private static let confirmFraction: CGFloat = 0.9

    var body: some View {
        GeometryReader { proxy in
            let travel = max(proxy.size.width - Spacing.tight * 2 - Self.thumbSize, 0)
            ZStack(alignment: .leading) {
                label(Color.orange500)
                // The same strip again in the inverse colours, cut off exactly
                // where the thumb has reached. Drawing it twice and clipping the
                // top copy is what lets one word be orange on the near side of
                // the thumb and white on the far side, instead of the fill
                // sliding under unchanged text.
                label(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color.orange500)
                    .mask(alignment: .leading) {
                        // The thumb's own inset eases in over the first few
                        // pixels rather than appearing the moment the thumb
                        // moves, so the paint is a continuous function of the
                        // offset and shrinks back to nothing on release.
                        Rectangle().frame(width: offset + min(offset, Spacing.tight))
                    }

                thumb(travel: travel)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: Self.trackHeight)
        .background(Color.white)
        .clipShape(.rect(cornerRadius: CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.orange500, lineWidth: 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        // A slide is a poor gesture to ask of anyone driving the screen by
        // voice or switch, so the same promise is one activation away.
        .accessibilityAction(named: title, action)
    }

    private func label(_ color: Color) -> some View {
        Text(title)
            .font(.buttonTitle)
            .foregroundStyle(color)
            .padding(.leading, Spacing.tight + Self.thumbSize + Spacing.section)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func thumb(travel: CGFloat) -> some View {
        Image(systemName: "arrow.forward.circle.fill")
            .resizable()
            .frame(width: Self.thumbSize, height: Self.thumbSize)
            .foregroundStyle(Color.orange500)
            .padding(.horizontal, Spacing.tight)
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { offset = min(max($0.translation.width, 0), travel) }
                    .onEnded { _ in
                        if offset >= travel * Self.confirmFraction { action() }
                        // Short of the end, the thumb returns: a slide that was
                        // not finished did not ask for anything.
                        withAnimation(.spring(duration: MotionDuration.short)) { offset = 0 }
                    }
            )
    }
}

#Preview {
    SlideToConfirm(title: "SLIDE TO COMPLETE ROUTINE", action: {})
        .padding(Spacing.screen)
}
