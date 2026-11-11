import SwiftUI

// The one place the store is opened, and the only thing standing between a
// store that would not open and a person typing a week into it.
struct AppRootView: View {
    @State private var dependencies: AppDependencies?
    @State private var hasOpened = false

    var body: some View {
        Group {
            if let dependencies {
                RootView(dependencies: dependencies)
            } else if hasOpened {
                StoreUnreadableView(onRetry: open)
            } else {
                SplashView()
            }
        }
        .onAppear { if !hasOpened { open() } }
    }

    private func open() {
        dependencies = AppDependencies.live()
        hasOpened = true
    }
}
