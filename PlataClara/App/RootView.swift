import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("abrirNuevoMovimiento") private var openNewMovement = false
    @AppStorage("onboardingDone") private var onboardingDone = false
    @State private var showOnboarding = false
    @Query private var allAccounts: [Account]
    @Query(filter: #Predicate<Movement> { $0.statusRaw == "porRevisar" }) private var toReview: [Movement]

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Inicio", systemImage: "house") }
            MovementsView().tabItem { Label("Movimientos", systemImage: "list.bullet") }
            ReviewInboxView().tabItem { Label("Por revisar", systemImage: "tray") }.badge(toReview.count)
            RecurringView().tabItem { Label("Fijos", systemImage: "calendar") }
            StatsView().tabItem { Label("Estadísticas", systemImage: "chart.pie") }
        }
        .sheet(isPresented: $openNewMovement) { MovementFormView(movement: nil) }
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView() }
        .task {
            SeedData.seedIfNeeded(context)
            // Quien ya tiene cuentas no necesita el recorrido; quien empieza de cero lo ve una vez.
            if !onboardingDone {
                if allAccounts.isEmpty { showOnboarding = true } else { onboardingDone = true }
            }
            RecurringService.refresh(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { RecurringService.refresh(context: context) }
            if phase == .background { BackupFolderService.autoBackup(context: context) }
        }
    }
}
