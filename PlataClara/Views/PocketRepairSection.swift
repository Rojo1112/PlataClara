import SwiftUI
import SwiftData
import PlataCore

/// Aparece solo si quedan movimientos de cajita guardados como ingreso o gasto por una versión anterior:
/// ofrece convertirlos en traslados, que es lo que son.
struct PocketRepairSection: View {
    @Environment(\.modelContext) private var context
    @Query private var movements: [Movement]
    @State private var confirming = false
    @State private var message: String?

    private var candidates: [PocketRepair.Candidate] {
        PocketRepair.legacy(movements.map { $0.snapshot(categoryName: nil) })
    }

    var body: some View {
        let found = candidates
        if !found.isEmpty || message != nil {
            Section {
                if !found.isEmpty {
                    LabeledContent("Movimientos de cajita como ingreso o gasto", value: "\(found.count)")
                    Button("Convertirlos en traslados") { confirming = true }
                        .confirmationDialog("Se convierten \(found.count) movimientos por \(Money.format(found.reduce(0) { $0 + $1.amount })) en traslados entre tu cuenta y sus cajitas. Dejan de contar como ingreso o gasto.",
                                            isPresented: $confirming, titleVisibility: .visible) {
                            Button("Convertir") {
                                let changed = ReconciliationService.repairLegacyPockets(context: context)
                                message = "\(changed) movimientos convertidos en traslados."
                            }
                            Button("Cancelar", role: .cancel) {}
                        }
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary) }
            } header: {
                Text("Cajitas de versiones anteriores")
            } footer: {
                Text("Antes de la versión 0.7.2, guardar plata en una cajita o sacarla quedaba como gasto o ingreso e inflaba las estadísticas. El saldo de tu cuenta no cambia; el de las cajitas pasa a incluir esos traslados.")
            }
        }
    }
}
