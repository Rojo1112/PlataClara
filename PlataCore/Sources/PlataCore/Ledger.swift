import Foundation

public enum Ledger {
    /// Ahorros: dinero disponible. Crédito: deuda (positivo = lo que debes).
    public static func balance(of account: AccountSnapshot, movements: [MovementSnapshot]) -> Int {
        movements
            .filter { $0.status == .confirmado }
            .reduce(account.openingBalance) { $0 + effect(of: $1, on: account) }
    }

    /// Saldo anclado al banco: el último punto de cuadre (hasta `date`) más los movimientos posteriores.
    /// Un movimiento con la misma hora que el punto ya está dentro de él. Sin puntos, se usa el saldo inicial.
    public static func balance(of account: AccountSnapshot, movements: [MovementSnapshot],
                               checkpoints: [CheckpointSnapshot], at date: Date = .distantFuture) -> Int {
        let anchor = latestCheckpoint(for: account.id, in: checkpoints, at: date)
        return movements
            .filter { m in m.status == .confirmado && m.date <= date && (anchor.map { m.date > $0.date } ?? true) }
            .reduce(anchor?.balance ?? account.openingBalance) { $0 + effect(of: $1, on: account) }
    }

    public static func latestCheckpoint(for accountID: UUID, in checkpoints: [CheckpointSnapshot],
                                        at date: Date = .distantFuture) -> CheckpointSnapshot? {
        checkpoints.filter { $0.accountID == accountID && $0.date <= date }.max { $0.date < $1.date }
    }

    public static func totalCash(accounts: [AccountSnapshot], movements: [MovementSnapshot],
                                 checkpoints: [CheckpointSnapshot] = []) -> Int {
        accounts.filter { $0.kind == .ahorros }
            .reduce(0) { $0 + balance(of: $1, movements: movements, checkpoints: checkpoints) }
    }

    public static func totalDebt(accounts: [AccountSnapshot], movements: [MovementSnapshot],
                                 checkpoints: [CheckpointSnapshot] = []) -> Int {
        accounts.filter { $0.kind == .credito }
            .reduce(0) { $0 + balance(of: $1, movements: movements, checkpoints: checkpoints) }
    }

    /// Cambio en el dinero de la cuenta; en tarjetas de crédito se invierte el signo para expresar deuda.
    static func effect(of movement: MovementSnapshot, on account: AccountSnapshot) -> Int {
        var delta = 0
        if movement.accountID == account.id {
            delta += movement.kind == .ingreso ? movement.amount : -movement.amount
        }
        if movement.kind == .transferencia, movement.destinationAccountID == account.id {
            delta += movement.amount
        }
        return account.kind == .ahorros ? delta : -delta
    }
}
