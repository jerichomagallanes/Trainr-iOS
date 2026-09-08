import SwiftUI

struct FieldError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.body12)
                .foregroundStyle(Color.dangerInk)
                .padding(.top, Spacing.small)
        }
    }
}
