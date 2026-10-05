import XCTest
@testable import PlataCore

final class MovementValidatorTests: XCTestCase {
    func testValidExpense() {
        XCTAssertEqual(MovementValidator.validate(amount: 10_000, kind: .gasto, accountID: UUID(), destinationAccountID: nil), [])
    }

    func testMissingAmountAndAccount() {
        XCTAssertEqual(MovementValidator.validate(amount: 0, kind: .gasto, accountID: nil, destinationAccountID: nil),
                       [.montoInvalido, .faltaCuenta])
    }

    func testTransferNeedsDestination() {
        XCTAssertEqual(MovementValidator.validate(amount: 5_000, kind: .transferencia, accountID: UUID(), destinationAccountID: nil),
                       [.faltaDestino])
    }

    func testTransferToSameAccount() {
        let id = UUID()
        XCTAssertEqual(MovementValidator.validate(amount: 5_000, kind: .transferencia, accountID: id, destinationAccountID: id),
                       [.mismaCuenta])
    }
}
