import XCTest
@testable import PlataCore

final class StatementTests: XCTestCase {
    func parse(_ text: String, year: Int? = nil) -> [StatementEntry] {
        StatementParser.parse(text: text, calendar: bogota, defaultYear: year)
    }

    // Ejemplos sintéticos: no son de ningún banco real.
    func testPurchaseWithNegativeAmountAndBalance() {
        let e = parse("04/10/2026 COMPRA EXITO CALLE 80 -50.000,00 1.234.567,00")
        XCTAssertEqual(e, [StatementEntry(date: fecha(2026, 10, 4), description: "COMPRA EXITO CALLE 80",
                                          amount: 50_000, kind: .gasto, balance: 1_234_567)])
    }

    func testIncomeByKeyword() {
        let e = parse("05/10/2026 ABONO NOMINA $ 3.000.000")
        XCTAssertEqual(e.first?.kind, .ingreso)
        XCTAssertEqual(e.first?.amount, 3_000_000)
        XCTAssertNil(e.first?.balance)
    }

    func testDebitMarkerAndDashDate() {
        let e = parse("06-10-2026 PAGO QR TIENDA 12.000 DB")
        XCTAssertEqual(e.first?.kind, .gasto)
        XCTAssertEqual(e.first?.amount, 12_000)
        XCTAssertEqual(e.first?.date, fecha(2026, 10, 6))
    }

    func testParenthesesAndDateWithoutYear() {
        let e = parse("07/10 COMPRA RAPPI (35.900)", year: 2026)
        XCTAssertEqual(e.first?.date, fecha(2026, 10, 7))
        XCTAssertEqual(e.first?.kind, .gasto)
        XCTAssertEqual(e.first?.amount, 35_900)
        XCTAssertTrue(parse("07/10 COMPRA RAPPI (35.900)").isEmpty)
    }

    func testLinesWithoutDateAreSkipped() {
        XCTAssertTrue(parse("SALDO ANTERIOR 1.000.000\nPágina 1 de 3\nTotal débitos 500.000").isEmpty)
    }

    func testStoreNumberIsNotAnAmount() {
        let e = parse("08/10/2026 COMPRA TIENDA 1234 -20.000")
        XCTAssertEqual(e.first?.description, "COMPRA TIENDA 1234")
        XCTAssertEqual(e.first?.amount, 20_000)
    }

    func testSemicolonCsvWithIsoDate() {
        let e = parse("2026-10-09;COMPRA D1;-8.500;1.200.000")
        XCTAssertEqual(e, [StatementEntry(date: fecha(2026, 10, 9), description: "COMPRA D1",
                                          amount: 8_500, kind: .gasto, balance: 1_200_000)])
    }

    func testMultipleLinesKeepOrder() {
        let e = parse("04/10/2026 A -1.000\nbasura\n05/10/2026 ABONO B 2.000")
        XCTAssertEqual(e.map(\.amount), [1_000, 2_000])
    }

    // MARK: extractos con fecha, descripción y monto en renglones separados (formato tipo Nu)
    // Ejemplo sintético con la misma estructura de un extracto real.
    func testStackedLayoutWithPeriodYearAndPageMarkers() {
        let text = """
        Período
        01 - 30 SEP 2026
        Dinero en tu cuenta
        $11.752,29
        Movimientos
        01 sep
        Compra en UBER*RIDES con tarjeta débito
        -$4.300,00
        01 sep
        Reembolso realizado
        +$4.300,00
        02 sep
        Pagaste tu tarjeta
        -$7.500,00
        2 / 13
        03 sep
        Recibiste de Fulano de Tal
        +$250.000,00
        """
        let e = StatementParser.parse(text: text, calendar: bogota, defaultYear: 2025)
        XCTAssertEqual(e.map(\.amount), [4_300, 4_300, 7_500, 250_000])
        XCTAssertEqual(e.map(\.kind), [.gasto, .ingreso, .transferencia, .ingreso])
        XCTAssertEqual(e.first?.description, "Compra en UBER*RIDES con tarjeta débito")
        XCTAssertEqual(e.first?.date, fecha(2026, 9, 1))
    }

    func testSameLineTextualMonthLayout() {
        let e = parse("01 sep Compra en UBER*RIDES con tarjeta débito -$4.300,00\n02 sep Recibiste de Mengano +$250.000,00", year: 2026)
        XCTAssertEqual(e.map(\.amount), [4_300, 250_000])
        XCTAssertEqual(e.map(\.kind), [.gasto, .ingreso])
        XCTAssertEqual(e.first?.description, "Compra en UBER*RIDES con tarjeta débito")
        XCTAssertEqual(e.first?.date, fecha(2026, 9, 1))
    }

    func testCardPaymentInSingleLineIsTransfer() {
        XCTAssertEqual(parse("02/09/2026 PAGASTE TU TARJETA -7.500,00").first?.kind, .transferencia)
    }

    func testStackedWithoutAnyYearIsSkipped() {
        XCTAssertTrue(parse("01 sep\nCompra en X\n-$1.000,00").isEmpty)
    }

    // MARK: conciliación
    func testDuplicateDetection() {
        let cuenta = UUID()
        let existing = [MovementSnapshot(amount: 50_000, date: fecha(2026, 10, 4, 18), kind: .gasto, method: .debito, accountID: cuenta)]
        let same = StatementEntry(date: fecha(2026, 10, 5, 0), description: "X", amount: 50_000, kind: .gasto, balance: nil)
        XCTAssertTrue(StatementReconciler.isDuplicate(same, accountID: cuenta, existing: existing, calendar: bogota))
        let otherAmount = StatementEntry(date: fecha(2026, 10, 4), description: "X", amount: 51_000, kind: .gasto, balance: nil)
        XCTAssertFalse(StatementReconciler.isDuplicate(otherAmount, accountID: cuenta, existing: existing, calendar: bogota))
        let farDate = StatementEntry(date: fecha(2026, 10, 7), description: "X", amount: 50_000, kind: .gasto, balance: nil)
        XCTAssertFalse(StatementReconciler.isDuplicate(farDate, accountID: cuenta, existing: existing, calendar: bogota))
        XCTAssertFalse(StatementReconciler.isDuplicate(same, accountID: UUID(), existing: existing, calendar: bogota))
    }
}
