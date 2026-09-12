# 🏋️ Trainr - Personal Training App

Trainr is an iOS fitness application that builds your workout plan on your phone from your answers, and progresses it from the sets you log. Built with Swift and SwiftUI, it keeps a clean separation between its models, services and features to provide users with customized training plans based on their individual fitness goals, experience level, and available equipment.

This is the iOS version of [Trainr for Android](https://github.com/jerichomagallanes/Trainr).

## 📋 Features

- **Personalized Onboarding**: Complete fitness assessment including age, gender, experience level, and body metrics
- **Custom Workout Plans**: Routines built around your fitness goals and available equipment, and progressed week to week from what you actually lifted
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
- **Firebase Crashlytics**: Crash reports with hand-written breadcrumbs and no analytics
- **YouTubePlayerKit**: In-app exercise demonstrations via the IFrame Player API
- **SwiftLint**: Style enforcement locally and in CI

## 🏗️ Architecture

- **Models**: Value types for the profile, the weekly plan and the units logic — pure Swift, no framework imports
- **Services**: Plan generation (the skeleton builder, `WeekPlanGenerator`, the expander and the parser), the SwiftData store, and crash diagnostics
- **Features**: SwiftUI screens and their `@Observable` models, one folder per flow
- **DesignSystem**: The shared components, colors, spacing and typography every screen is built from

Generation runs entirely on the phone: `PlanSkeletonBuilder` lays out the week and ranks the movements each slot could hold, `WeekPlanGenerator` carries last week's movements forward or seeds a choice from the client's answers, `PlanExpander` asks the progression engine for every set, and `GeneratedPlanParser` checks the result against the skeleton's own limits. Nothing is sent anywhere.

## 🚀 Getting Started

1. Open `Trainr.xcodeproj` in Xcode 26 or later.
2. Build and run. Generation needs no credentials; `GoogleService-Info.plist` in `Trainr/Resources/` (gitignored) is only for Crashlytics.

Tests: `xcodebuild test -project Trainr.xcodeproj -scheme Trainr -destination 'platform=iOS Simulator,name=iPhone 17 Pro 27'`

The simulator must run iOS 27: the stock iOS 26.2 simulators crash on SwiftData built against the iOS 27 SDK.

UI tests run on a throwaway clone of the simulator unless you pass `-parallel-testing-enabled NO`, which drives the visible device instead. Debug builds also accept a few launch arguments the UI tests rely on: `-inMemoryStore` for a store that dies with the process, `-seedFixture <noPlan|midWeek|finishedWeek|twoWeeks|freshWeek|missedDay|lastDayLeft>` to start on a known plan, `-generationFails` to make generation fail, `-slowGeneration <seconds>` to answer correctly but slowly, and `-splashSeconds <n>` to hold the splash.

## 🔒 Privacy

Trainr stores your profile and training history on your device. Nothing leaves the device to build a plan; crash reports say what broke, never who you are. The full policy: [Privacy Policy](https://jerichomagallanes.github.io/Trainr/privacy-policy).
