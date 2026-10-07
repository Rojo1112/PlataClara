import SwiftUI
import SwiftData

@main
struct PlataClaraApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
        }
        .modelContainer(Persistence.container)
    }
}
