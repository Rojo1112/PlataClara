import SwiftUI
import SwiftData

@main
struct PlataClaraApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Persistence.container)
    }
}
