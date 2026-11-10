import SwiftUI
import SwiftData

@main
struct PlataClaraApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppLock.enabledKey) private var lockEnabled = false
    @State private var showSplash = true
    /// Con el bloqueo activo la app arranca cerrada.
    @State private var locked = AppLock.isEnabled
    @State private var backgroundedAt: Date?
    @State private var unlocking = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Bloqueada, la interfaz no existe: así también se cierran las hojas que estuvieran abiertas.
                if locked {
                    LockView(unlock: unlock)
                } else {
                    RootView()
                }
                // Tapa el contenido en el selector de apps y mientras la app no está al frente.
                if lockEnabled, !locked, scenePhase != .active {
                    PrivacyCover().zIndex(2)
                }
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
            }
            .task { if locked { unlock() } }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if backgroundedAt == nil { backgroundedAt = .now }
                case .active:
                    // Solo al volver del fondo: el aviso de Face ID también pasa por «inactiva» y volvería a pedirlo sin fin.
                    guard let since = backgroundedAt else { return }
                    backgroundedAt = nil
                    if lockEnabled, Date.now.timeIntervalSince(since) > AppLock.graceSeconds { locked = true }
                    if locked { unlock() }
                default:
                    break
                }
            }
        }
        .modelContainer(Persistence.container)
    }

    private func unlock() {
        guard !unlocking else { return }
        unlocking = true
        Task {
            if await AppLock.authenticate(reason: "Abrir PlataClara") { locked = false }
            unlocking = false
        }
    }
}

/// Pantalla de la app bloqueada. Face ID se pide solo al abrir; el botón es para reintentar.
private struct LockView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.tint)
            Text("PlataClara está bloqueada").font(.headline)
            Button("Desbloquear", action: unlock).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct PrivacyCover: View {
    var body: some View {
        Color(.systemBackground)
            .overlay { Image(systemName: "lock.fill").font(.system(size: 44)).foregroundStyle(.tint) }
            .ignoresSafeArea()
    }
}
