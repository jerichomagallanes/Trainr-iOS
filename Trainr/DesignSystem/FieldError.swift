import SwiftUI

struct FieldError: View {
    let message: String?

    @Environment(\.screenScroll) private var screenScroll
    @State private var identity = UUID()

    var body: some View {
        if let message {
            Text(message)
                .font(.body12)
                .foregroundStyle(Color.dangerInk)
                .padding(.top, Spacing.small)
                .id(identity)
                // The keyboard leaves little of a form in view, so a message
                // explaining a disabled button is laid out behind it.
                .onAppear { screenScroll?.scrollTo(identity) }
        }
    }
}
