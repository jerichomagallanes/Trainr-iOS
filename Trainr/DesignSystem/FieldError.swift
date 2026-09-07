import SwiftUI

struct FieldError: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.body12)
                .foregroundStyle(Color.redError)
                .padding(.top, Spacing.small)
        }
    }
}
