import XCTest
@testable import PlataCore

final class ScreenshotTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    // Lunes 5 de octubre de 2026, 13:10
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13, minute: 10))! }

    func testListaConFechaYMonto() {
        let text = """
        1:08
        4G 75
        Buscar movimiento
        Pagaste en NEQUI S.A. -$75.000,00
        COMPAÑÍA DE
        FINANCIAMIENTO
        05 oct - 11:59
        Hicimos un reembolso +$5.410,00
        05 oct - 11:41
        UBER*RIDES -$5.410,00
        05 oct - 11:19
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].description, "Pagaste en NEQUI S.A. COMPAÑÍA DE FINANCIAMIENTO")
        XCTAssertEqual(entries[0].amount, 75_000)
        XCTAssertEqual(entries[0].kind, .gasto)
        XCTAssertEqual(cal.component(.hour, from: entries[0].date), 11)
        XCTAssertEqual(entries[1].kind, .ingreso)
        XCTAssertEqual(entries[1].amount, 5_410)
        XCTAssertEqual(entries[2].kind, .gasto)
    }

    func testTarjetaConEncabezadoDeDia() {
        let text = """
        Hoy
        Uber*Rides $4.250,00
        11:03
        a 1 meses
        Sábado
        Uber*Rides $13.480,00
        23:37
        a 1 meses
        ¡Gracias por tu pago!
        Pagaste $80.000,00
        Viernes
        Comisión por servicio $6.500,00
        14:03
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [4_250, 13_480, 80_000, 6_500])
        XCTAssertEqual(entries[2].kind, .transferencia)
        XCTAssertEqual(entries[3].kind, .gasto)
        XCTAssertEqual(cal.component(.day, from: entries[0].date), 5)
        XCTAssertEqual(cal.component(.day, from: entries[1].date), 3)  // sábado anterior
        XCTAssertEqual(cal.component(.day, from: entries[3].date), 2)  // viernes anterior
    }

    func testCapturasRepetidasNoDuplican() {
        let text = "UBER*RIDES -$5.410,00\n05 oct - 11:19\nUBER*RIDES -$5.410,00\n05 oct - 11:19"
        XCTAssertEqual(ScreenshotParser.parse(text: text, now: now, calendar: cal).count, 1)
    }
}

final class ScreenshotOverlapTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func testFilasCortadasYBuscadorNoCreanMovimientos() {
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13))!
        let first = """
        1:31
        4G 84
        Q Buscar movimiento
        Recibiste de CARLOS +$250.000,00
        03 oct - 08:49 • Bre-B
        Enviaste a JORGE -$12.000,00
        """
        let second = """
        Q Buscar movimiento
        Enviaste a JORGE ANDRES -$12.000,00
        02 oct - 02:02 • Bre-B
        NOVAVENTA -$3.500,00
        01 oct - 12:08
        Recibiste de ANA +$5.000,00
        """
        let third = """
        Recibiste de ANA DEMO +$5.000,00
        01 oct - 15:11 • Bre-B
        NOVAVENTA -$3.500,00
        01 oct - 12:08
        """
        let text = [first, second, third].joined(separator: "\n\(ScreenshotParser.pageBreak)\n")
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(entries[0].description, "Recibiste de CARLOS")
        XCTAssertFalse(entries.contains { $0.description.contains("Buscar") })
        XCTAssertEqual(entries.filter { $0.amount == 3_500 && $0.kind == .gasto }.count, 1)
    }
}
