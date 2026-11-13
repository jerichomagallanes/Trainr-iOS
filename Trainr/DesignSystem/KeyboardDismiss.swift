import SwiftUI
import UIKit

extension View {

    // A number pad has no Return key, so a tap on anything that is not a
    // control is the other way out of it. A child that takes the tap still wins.
    func dismissesKeyboardOnTap() -> some View {
        contentShape(.rect).onTapGesture { KeyboardDismiss.now() }
    }

    // Only the focused field carries the bar, so two fields on one screen never
    // put up two of them.
    func keyboardDone(whenFocused isFocused: Bool, onDone: @escaping () -> Void) -> some View {
        toolbar {
            if isFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.done, action: onDone).font(.labelLarge)
                }
            }
        }
    }
}

enum KeyboardDismiss {

    static func now() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }
}

extension UIKeyboardType {

    var isNumeric: Bool { self == .numberPad || self == .decimalPad }
}
