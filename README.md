# 🏋️ Trainr - AI-Powered Personal Training App

Trainr is an iOS fitness application that creates personalized workout routines using AI. Built with Swift and SwiftUI, it keeps a clean separation between its models, services and features to provide users with customized training plans based on their individual fitness goals, experience level, and available equipment.

This is the iOS version of [Trainr for Android](https://github.com/jerichomagallanes/Trainr).

## 📋 Features

- **Personalized Onboarding**: Complete fitness assessment including age, gender, experience level, and body metrics
- **Custom Workout Plans**: AI-generated routines tailored to your fitness goals and available equipment
- **Flexible Setup**: Support for home, gym, or hybrid workout environments
- **Equipment Adaptation**: Workouts adapt to your available equipment (bodyweight, dumbbells, barbells, etc.)
- **Goal-Oriented Training**: Specialized programs for weight loss, muscle gain, strength, endurance, and general fitness
- **Injury Considerations**: Safe workout modifications based on reported limitations
- **Session Logging**: Record weight, reps and time per set, with last week's numbers shown beside each one
- **Built-in Timer**: Count down a timed exercise without leaving the session
- **Video Tutorials**: A hand-checked YouTube demonstration for each exercise in the catalog
- **Rescheduling**: Move a session onto another weekday
- **Week by Week**: Generate the next week from what you actually lifted, run any past week again, or rebuild the week you are in
- **Progress Tracking**: Every stored week with its dates, status and completion

## 📚 Tech Stack

- **Swift 6**: Strict-concurrency language mode with main-actor-by-default isolation
- **SwiftUI**: Declarative UI, adopting the system design language on every OS it runs on
- **Observation**: `@Observable` models drive the screens with granular re-rendering
- **SwiftData**: Local persistence with cascading relationships
- **Swift Testing**: Unit tests with `#expect`, XCUITest for UI tests
- **Firebase AI Logic**: Gemini generation without an API key in the app
- **Firebase App Check**: App Attest attestation for every generation request
- **Firebase Crashlytics**: Crash reports with hand-written breadcrumbs and no analytics
- **YouTubePlayerKit**: In-app exercise demonstrations via the IFrame Player API
- **SwiftLint**: Style enforcement locally and in CI

## 🏗️ Architecture

- **Models**: Value types for the profile, the weekly plan and the units logic — pure Swift, no framework imports
- **Services**: Plan generation (the Gemini model chain, prompt, schema, parser and validation), the SwiftData store, and crash diagnostics
- **Features**: SwiftUI screens and their `@Observable` models, one folder per flow
- **DesignSystem**: The shared components, colors, spacing and typography every screen is built from

Generation is a conversation with a deadline: the app asks a chain of Gemini models in order, validates every answer against the plan contract, retries with the validation errors quoted back, skips models whose free daily allowance is already spent, and reports honestly — offline, failed, or daily limit reached — when it cannot deliver. A development run answers from a canned coach instead and never spends the allowance.

## 🚀 Getting Started

1. Open `Trainr.xcodeproj` in Xcode 26 or later.
2. Build and run. Without Firebase credentials the app runs fully offline against the canned coach.
3. For live generation, register an iOS app on the Firebase project and drop its `GoogleService-Info.plist` into `Trainr/Resources/` (it is gitignored).

Tests: `xcodebuild test -project Trainr.xcodeproj -scheme Trainr -destination 'platform=iOS Simulator,name=iPhone 17 Pro 27'`

The simulator must run iOS 27: the stock iOS 26.2 simulators crash on SwiftData built against the iOS 27 SDK.

How the work is branched, committed, checked and merged: [CONTRIBUTING.md](CONTRIBUTING.md).

## 🔒 Privacy

Trainr stores your profile and training history on your device. Generation requests carry the profile to Gemini through Firebase AI Logic; crash reports say what broke, never who you are. The full policy: [Privacy Policy](https://jerichomagallanes.github.io/Trainr/privacy-policy).
