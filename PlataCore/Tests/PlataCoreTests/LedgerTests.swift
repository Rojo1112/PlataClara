import XCTest
@testable import PlataCore

final class LedgerTests: XCTestCase {
    let nu = AccountSnapshot(kind: .ahorros, openingBalance: 100_000)
    let lulo = AccountSnapshot(kind: .ahorros, openingBalance: 0)
    let tarjeta = AccountSnapshot(kind: .credito, openingBalance: 0)

    func mov(_ amount: Int, _ kind: MovementKind, _ method: PaymentMethod, from: UUID?, to: UUID? = nil,
             status: MovementStatus = .confirmado) -> MovementSnapshot {
        MovementSnapshot(amount: amount, date: fecha(2026, 10, 4), kind: kind, method: method,
                         accountID: from, destinationAccountID: to, status: status)
    }

    func testIncomeDebitAndQrChangeSavingsBalance() {
        let ms = [mov(50_000, .ingreso, .transferencia, from: nu.id),
                  mov(20_000, .gasto, .debito, from: nu.id),
                  mov(5_000, .gasto, .qr, from: nu.id)]
        XCTAssertEqual(Ledger.balance(of: nu, movements: ms), 125_000)
    }

    func testCreditPurchaseRaisesDebtAndDoesNotTouchCash() {
        let ms = [mov(80_000, .gasto, .credito, from: tarjeta.id)]
        XCTAssertEqual(Ledger.balance(of: tarjeta, movements: ms), 80_000)
        XCTAssertEqual(Ledger.totalCash(accounts: [nu, tarjeta], movements: ms), 100_000)
        XCTAssertEqual(Ledger.totalDebt(accounts: [nu, tarjeta], movements: ms), 80_000)
    }

    func testPayingTheCardReducesCashAndDebt() {
        let ms = [mov(80_000, .gasto, .credito, from: tarjeta.id),
                  mov(50_000, .transferencia, .transferencia, from: nu.id, to: tarjeta.id)]
        XCTAssertEqual(Ledger.totalCash(accounts: [nu, tarjeta], movements: ms), 50_000)
        XCTAssertEqual(Ledger.totalDebt(accounts: [nu, tarjeta], movements: ms), 30_000)
    }

    func testTransferBetweenOwnAccountsKeepsTotal() {
        let ms = [mov(30_000, .transferencia, .transferencia, from: nu.id, to: lulo.id)]
        XCTAssertEqual(Ledger.balance(of: nu, movements: ms), 70_000)
        XCTAssertEqual(Ledger.balance(of: lulo, movements: ms), 30_000)
        XCTAssertEqual(Ledger.totalCash(accounts: [nu, lulo], movements: ms), 100_000)
    }

    func testRefundOnCreditCardLowersDebt() {
        let ms = [mov(80_000, .gasto, .credito, from: tarjeta.id),
                  mov(20_000, .ingreso, .credito, from: tarjeta.id)]
        XCTAssertEqual(Ledger.balance(of: tarjeta, movements: ms), 60_000)
    }

    func testMovementsToReviewAreIgnored() {
        let ms = [mov(10_000, .gasto, .debito, from: nu.id, status: .porRevisar)]
        XCTAssertEqual(Ledger.balance(of: nu, movements: ms), 100_000)
    }
}
