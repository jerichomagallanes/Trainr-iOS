# 🏋️ Trainr - Workout Planner

Trainr is an iOS workout planner that writes your week from your goal, your equipment and your days, bends it when life gets in the way, and builds next week from what you actually did. Everything runs on the phone: the plan is generated on-device, and a small language model reads the free-text "Adjust today" note without anything leaving the device. Built with Swift and SwiftUI, it keeps a clean separation between its models, services and features.

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=180x60)](https://apps.apple.com/jp/app/trainr-workout-planner/id6809207852)

Website: [jerichomagallanes.github.io/Trainr](https://jerichomagallanes.github.io/Trainr/) · This is the iOS version of [Trainr for Android](https://github.com/jerichomagallanes/Trainr).

## 📋 Features

- **Personalized Onboarding**: Complete fitness assessment including age, gender, experience level, and body metrics
- **Custom Workout Plans**: Routines built around your fitness goals and available equipment, and progressed week to week from what you actually lifted
- **Equipment Adaptation**: Pick what you own from a pictured list (none, dumbbells, barbells, kettlebells, plates, machines, bands); the week is written with that, and only that
- **Goal-Oriented Training**: Specialized programs for weight loss, muscle gain, strength, endurance, and general fitness
- **Injury Considerations**: Safe workout modifications based on reported limitations
- **Adjust Today**: Change a workout on the day for the reasons people actually stop. Less time keeps the most relevant work; missing equipment finds a suitable alternative; "show me how" opens the how-to; "something hurts" pauses and decides what to do next; or say it in your own words and a language model running on the phone reads the note, shows what it understood, and applies the change only when you say so
- **Session Logging**: Record weight, reps and time per set, with last week's numbers shown beside each one
- **Two Ways to Finish**: Log the whole session at its prescribed numbers, or save what you have done and stop
- **Built-in Timer**: Count down a timed exercise without leaving the session
- **Video Tutorials**: A hand-checked YouTube demonstration for each exercise in the catalog
- **Rescheduling**: Move a session onto another weekday
- **Week by Week**: Generate the next week from what you actually lifted, repeat any past week for free, or rewrite the week you are in
- **Progress Tracking**: Every stored week with its dates, status and completion

## 💳 Trainr Pro

The first week is free. Pro unlocks every week after it, as a monthly or yearly subscription with a 7-day free trial, or a one-time lifetime purchase. Purchases go through RevenueCat on StoreKit 2; the free tier shows one AdMob banner on the plan screen behind Google's consent flow and App Tracking Transparency, and Pro removes it.

## 📚 Tech Stack

- **Swift 6**: Strict-concurrency language mode with main-actor-by-default isolation
- **SwiftUI**: Declarative UI, adopting the system design language on every OS it runs on
- **Observation**: `@Observable` models drive the screens with granular re-rendering
- **SwiftData**: Local persistence with cascading relationships
- **llama.cpp**: Runs LiquidAI LFM2.5-1.2B-Instruct on the device to read the free-text Adjust today note; the model is a one-time 730 MB download, verified by SHA-256
- **RevenueCat**: Subscriptions and the lifetime purchase on StoreKit 2
- **Google Mobile Ads**: One banner on the free tier, behind the User Messaging Platform consent flow
- **Swift Testing**: Unit tests with `#expect`, XCUITest for UI tests
- **Firebase Crashlytics**: Crash reports with hand-written breadcrumbs and no analytics
- **YouTubePlayerKit**: In-app exercise demonstrations via the IFrame Player API
- **SwiftLint**: Style enforcement locally and in CI

## 🏗️ Architecture

- **Models**: Value types for the profile, the weekly plan and the units logic — pure Swift, no framework imports
- **Services**: Plan generation (the skeleton builder, `WeekPlanGenerator`, the expander and the parser), the SwiftData store, purchases, the model installer and intent interpreter behind Adjust today, and crash diagnostics
- **Features**: SwiftUI screens and their `@Observable` models, one folder per flow
- **DesignSystem**: The shared components, colors, spacing and typography every screen is built from

Generation runs entirely on the phone: `PlanSkeletonBuilder` lays out the week and ranks the movements each slot could hold, `WeekPlanGenerator` carries last week's movements forward or seeds a choice from the client's answers, `PlanExpander` asks the progression engine for every set, and `GeneratedPlanParser` checks the result against the skeleton's own limits. Nothing is sent anywhere.

Adjust today's free-text path goes through an intent interpreter that turns the note into one of the structured reasons with evidence quoted from the note itself; the structured reasons never touch the model. A phone without room for the model download is told so, and the other reasons keep working.

## 🚀 Getting Started

1. Open `Trainr.xcodeproj` in Xcode 26 or later.
2. Build and run. Generation needs no credentials; `GoogleService-Info.plist` in `Trainr/Resources/` (gitignored) is only for Crashlytics.

Tests: `xcodebuild test -project Trainr.xcodeproj -scheme Trainr -destination 'platform=iOS Simulator,name=iPhone 17 Pro 27'`

The simulator must run iOS 27: the stock iOS 26.2 simulators crash on SwiftData built against the iOS 27 SDK.

UI tests run on a throwaway clone of the simulator unless you pass `-parallel-testing-enabled NO`, which drives the visible device instead. Debug builds also accept a few launch arguments the UI tests rely on: `-inMemoryStore` for a store that dies with the process, `-seedFixture <noPlan|midWeek|finishedWeek|twoWeeks|freshWeek|missedDay|lastDayLeft>` to start on a known plan, `-startAtStep <setup|bodyMetrics|goals|limitations|review>` to open onboarding part-way, `-generationFails` to make generation fail, `-slowGeneration <seconds>` to answer correctly but slowly, and `-splashSeconds <n>` to hold the splash.

## 🚀 Releases

Candidates are built once by GitHub Actions when `version/X.Y` is fast-forwarded
onto `pre-release` (`Test release` → TestFlight, signed in the cloud with an
Admin-role App Store Connect key), submitted for review by hand or with the
`Promote to production` workflow, and tagged by the `Release` workflow once `main`
carries what the App Store sells. Every tag has a GitHub Release with the shipped
build attached and the pull requests since the previous release.

## 🔒 Privacy

Trainr stores your profile, your training history and anything you type into Adjust today on your device. Nothing leaves the device to build a plan or read a note; crash reports say what broke, never who you are. The full policy: [Privacy Policy](https://jerichomagallanes.github.io/Trainr/privacy-policy).
