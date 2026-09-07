import SwiftUI

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
                // The same strip in inverse colours, clipped where the thumb
                // has reached: that is what changes the word's colour mid-word.
                label(Color.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(Color.orange500)
                    .mask(alignment: .leading) {
                        // The inset eases in over the first pixels, so the
                        // paint stays a continuous function of the offset.
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
                        // travel > 0 as well: with no width yet, "nothing is at
                        // least nothing" let a plain tap finish the session.
                        if travel > 0, offset >= travel * Self.confirmFraction { action() }
                        withAnimation(.spring(duration: MotionDuration.short)) { offset = 0 }
                    }
            )
    }
}

#Preview {
    SlideToConfirm(title: "SLIDE TO COMPLETE ROUTINE", action: {})
        .padding(Spacing.screen)
}
