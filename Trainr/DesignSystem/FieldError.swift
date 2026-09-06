import SwiftUI

// Why a value was not accepted, under the field it belongs to. Nil draws
// nothing, so a caller can pass its check straight in and an untouched field
// stays quiet: a form that opens already complaining has told the client they
// are wrong before they have done anything.
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
