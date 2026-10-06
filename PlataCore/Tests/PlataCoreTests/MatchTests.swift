import XCTest
@testable import PlataCore

final class MatchTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let nu = UUID()

    func at(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func snap(_ amount: Int, _ date: Date, kind: MovementKind = .gasto, account: UUID? = nil) -> MovementSnapshot {
        MovementSnapshot(amount: amount, date: date, kind: kind, method: .debito, accountID: account)
    }

    func entry(_ amount: Int, _ date: Date, time: Bool, kind: MovementKind = .gasto) -> StatementEntry {
        StatementEntry(date: date, description: "X", amount: amount, kind: kind, balance: nil, hasTime: time)
    }

    func testSubirDosVecesLaMismaCapturaNoDuplica() {
        let entries = [entry(4_000, at(1, 12, 8), time: true), entry(4_000, at(1, 11, 53), time: true)]
        // Primera subida: el usuario importó ambos. Segunda subida: los dos emparejan con su propio movimiento.
        let existing = [snap(4_000, at(1, 12, 8), account: nu), snap(4_000, at(1, 11, 53), account: nu)]
        let matches = StatementReconciler.match(entries, accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(Set(matches.values).count, 2)
        XCTAssertEqual(matches[0], existing[0].id)
        XCTAssertEqual(matches[1], existing[1].id)
    }

    func testDosComprasIgualesYUnaSolaRegistrada() {
        let existing = [snap(4_000, at(1, 12, 8), account: nu)]
        let entries = [entry(4_000, at(1, 11, 53), time: true), entry(4_000, at(1, 12, 8), time: true)]
        let matches = StatementReconciler.match(entries, accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[1], existing[0].id)  // la que coincide en hora; la otra es nueva
    }

    func testApplePayYBancoConMinutosDeDiferencia() {
        let existing = [snap(25_000, at(3, 14, 2))]
        let ok = StatementReconciler.match([entry(25_000, at(3, 14, 10), time: true)], accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(ok.count, 1)
        let far = StatementReconciler.match([entry(25_000, at(3, 16, 30), time: true)], accountID: nu, existing: existing, calendar: cal)
        XCTAssertTrue(far.isEmpty)
    }

    func testExtractoSoloConDiaEmparejaPorDia() {
        let existing = [snap(25_000, at(3, 14, 2))]
        let matches = StatementReconciler.match([entry(25_000, at(3), time: false)], accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(matches.count, 1)
        let other = StatementReconciler.match([entry(25_000, at(6), time: false)], accountID: nu, existing: existing, calendar: cal)
        XCTAssertTrue(other.isEmpty)
    }

    func testOtraCuentaOTipoNoEmpareja() {
        let existing = [snap(10_000, at(3, 9), account: UUID())]
        XCTAssertTrue(StatementReconciler.match([entry(10_000, at(3, 9), time: true)], accountID: nu, existing: existing, calendar: cal).isEmpty)
        XCTAssertTrue(StatementReconciler.match([entry(10_000, at(3, 9), time: true, kind: .ingreso)], accountID: nil, existing: existing, calendar: cal).isEmpty)
    }
}
