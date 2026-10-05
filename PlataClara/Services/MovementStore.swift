import SwiftData
import PlataCore

@MainActor
enum MovementStore {
    /// Borra el movimiento; si estaba enlazado a un gasto fijo, el fijo vuelve a pendiente.
    static func delete(_ movement: Movement, context: ModelContext) {
        if let occurrenceID = movement.occurrenceID,
           let occurrence = context.all(RecurringOccurrence.self).first(where: { $0.id == occurrenceID }) {
            occurrence.status = .pendiente
            occurrence.movementID = nil
        }
        context.delete(movement)
        try? context.save()
    }

    /// Se llama cada vez que un movimiento queda confirmado.
    static func didConfirm(_ movement: Movement, context: ModelContext) {
        RecurringService.linkIfMatches(movement, context: context)
    }
}
