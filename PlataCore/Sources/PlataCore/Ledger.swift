import Foundation

public enum Ledger {
    /// Ahorros: dinero disponible. Crédito: deuda (positivo = lo que debes).
    public static func balance(of account: AccountSnapshot, movements: [MovementSnapshot]) -> Int {
        movements
            .filter { $0.status == .confirmado }
            .reduce(account.openingBalance) { $0 + effect(of: $1, on: account) }
    }

    public static func totalCash(accounts: [AccountSnapshot], movements: [MovementSnapshot]) -> Int {
        accounts.filter { $0.kind == .ahorros }.reduce(0) { $0 + balance(of: $1, movements: movements) }
    }

    public static func totalDebt(accounts: [AccountSnapshot], movements: [MovementSnapshot]) -> Int {
        accounts.filter { $0.kind == .credito }.reduce(0) { $0 + balance(of: $1, movements: movements) }
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
