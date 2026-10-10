import SwiftUI

extension View {

    // A screen is composed once and then keeps whatever the calendar said at
    // the time. Coming back to the app and the date rolling over under an open
    // screen are the two moments that answer goes stale without anything being
    // touched.
    func onDayChange(perform action: @escaping () -> Void) -> some View {
        modifier(DayChangeModifier(action: action))
    }
}

private struct DayChangeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                action()
            }
            .onReceive(Self.dayChanged) { _ in action() }
            .onReceive(Self.timeChanged) { _ in action() }
    }

    // Midnight and a time the device itself was told, which the system reports
    // apart.
    private static let dayChanged = NotificationCenter.default
        .publisher(for: .NSCalendarDayChanged)
        .receive(on: DispatchQueue.main)

    private static let timeChanged = NotificationCenter.default
        .publisher(for: UIApplication.significantTimeChangeNotification)
        .receive(on: DispatchQueue.main)
}
