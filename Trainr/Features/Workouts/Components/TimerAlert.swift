import AudioToolbox
import UIKit

// A countdown that ends while the phone is in a pocket has to be felt as well
// as heard, and the tone is the alarm the system already plays for a finished
// timer, so a silenced phone stays silent.
enum TimerAlert {

    private static let alarm: SystemSoundID = 1005

    static func fire() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(alarm)
        // The row changes where nobody is looking, so VoiceOver is told rather
        // than left to find it.
        UIAccessibility.post(notification: .announcement, argument: L10n.timerFinished)
    }
}
