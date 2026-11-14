import Foundation

/// Movimientos de cajita que las versiones anteriores a la 0.7.2 guardaron como ingreso o gasto. Son traslados:
/// la plata no entró ni salió, solo cambió de lugar.
public enum PocketRepair {
    public struct Candidate: Equatable, Sendable {
        public let id: UUID
        public let direction: PocketDirection
        public let amount: Int
    }

    /// Ingresos que dicen «Retiraste dinero de tu Cajita…» y gastos que dicen «Agregaste dinero a tu Cajita…».
    /// Solo los que tienen cuenta: sin ella no se sabe de qué cuenta son las cajitas.
    public static func legacy(_ movements: [MovementSnapshot]) -> [Candidate] {
        movements.compactMap { m in
            guard m.accountID != nil, m.kind != .transferencia,
                  let direction = MovementClassifier.pocketDirection(m.merchant ?? "") else { return nil }
            guard (m.kind == .ingreso) == (direction == .fromPocket) else { return nil }
            return Candidate(id: m.id, direction: direction, amount: m.amount)
        }
    }
}
