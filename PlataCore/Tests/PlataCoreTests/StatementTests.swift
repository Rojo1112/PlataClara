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

    // MARK: texto de PDF con filas partidas de distintas maneras
    // Ejemplo sintético: una fila entera, una con el monto en la línea siguiente, una en tres líneas y una con descripción larga.
    func testStreamHandlesMixedRowLayoutsAndIgnoresSummary() {
        let text = """
        Período
        01 - 30 SEP 2026
        Dinero en tu Cuenta Nu
        $11.752,29
        Rendimientos | 0,10% Efectivo Anual
        +$3,44
        Resumen de tus movimientos
        Lo que entró a tu cuenta
        +$250.000,00
        Lo que salió de tu cuenta
        -$100.000,00
        Movimientos
        01 sep Compra en UBER*RIDES con tarjeta débito
        -$4.300,00
        01 sep Reembolso realizado +$4.300,00
        02 sep
        Enviaste a PERSONA CON UN NOMBRE MUY LARGO
        QUE SE PARTE EN DOS LINEAS
        -$8.000,00
        2 / 13
        03 sep
        Recibiste de Mengano
        +$250.000,00
        """
        let e = StatementParser.parse(text: text, calendar: bogota, defaultYear: 2025)
        XCTAssertEqual(e.map(\.amount), [4_300, 4_300, 8_000, 250_000])
        XCTAssertEqual(e.map(\.kind), [.gasto, .ingreso, .gasto, .ingreso])
        XCTAssertEqual(e[2].description, "Enviaste a PERSONA CON UN NOMBRE MUY LARGO QUE SE PARTE EN DOS LINEAS")
        XCTAssertEqual(e[0].date, fecha(2026, 9, 1))
    }

    func testDeclaredTotalsAndCheck() {
        let totals = StatementParser.declaredTotals(in: "Resumen
Lo que entró a tu cuenta
+$250.000,00
Lo que salió de tu cuenta
-$400.000,50
")
        XCTAssertEqual(totals, StatementTotals(income: 250_000, outflow: 400_000))
        XCTAssertEqual(StatementParser.declaredTotals(in: "nada"), StatementTotals(income: nil, outflow: nil))

        let entries = [
            StatementEntry(date: fecha(2026, 9, 1), description: "a", amount: 250_000, kind: .ingreso, balance: nil),
            StatementEntry(date: fecha(2026, 9, 2), description: "b", amount: 99_999, kind: .gasto, balance: nil),
            StatementEntry(date: fecha(2026, 9, 3), description: "c", amount: 1, kind: .transferencia, balance: nil)
        ]
        let ok = StatementReconciler.check(entries: entries, against: StatementTotals(income: 250_000, outflow: 100_000))
        XCTAssertEqual(ok, TotalsCheck(incomeMatches: true, outflowMatches: true, readIncome: 250_000, readOutflow: 100_000))
        let bad = StatementReconciler.check(entries: entries, against: StatementTotals(income: 250_000, outflow: 150_000))
        XCTAssertEqual(bad.outflowMatches, false)
        XCTAssertNil(StatementReconciler.check(entries: entries, against: StatementTotals(income: nil, outflow: nil)).incomeMatches)
    }

    func testJapaneseCalendarPhoneStillGetsGregorianDates() {
        // Un teléfono con calendario japonés no debe convertir 2026 en el año 2026 de la era Reiwa.
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = TimeZone(identifier: "America/Bogota")!
        let e = StatementParser.parse(text: "01 sep Compra en X -$4.300,00", calendar: japanese, defaultYear: 2026)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(bogota.component(.year, from: e[0].date), 2026)
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
