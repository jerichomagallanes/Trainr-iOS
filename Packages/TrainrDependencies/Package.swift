// swift-tools-version: 6.0

// Every third-party package the app uses is declared here rather than in the
// Xcode project, because Dependabot can read a Package.swift and cannot read
// a pbxproj. The versions are exact, as they are in the Android repo's
// libs.versions.toml, so a bump is always a deliberate, reviewed pull request.
import PackageDescription

let package = Package(
    name: "TrainrDependencies",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "TrainrDependencies", targets: ["TrainrDependencies"])
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: "12.18.0"),
        .package(url: "https://github.com/SvenTiigi/YouTubePlayerKit", exact: "2.0.5"),
        .package(url: "https://github.com/RevenueCat/purchases-ios-spm", exact: "5.88.0")
    ],
    targets: [
        .target(
            name: "TrainrDependencies",
            dependencies: [
                // Re-exported by Exports.swift and imported by name in the app.
                // It resolved transitively before, so a restructuring upstream
                // would have broken the app with nothing here to point at.
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "YouTubePlayerKit", package: "YouTubePlayerKit"),
                .product(name: "RevenueCat", package: "purchases-ios-spm")
            ]
        )
    ]
)
