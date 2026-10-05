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
        Pagaste en NEQUI S.A. -$88.000,00
        COMPAÑÍA DE
        FINANCIAMIENTO
        05 oct - 11:59
        Hicimos un reembolso +$6.906,00
        05 oct - 11:41
        UBER*RIDES -$6.906,00
        05 oct - 11:19
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[0].description, "Pagaste en NEQUI S.A. COMPAÑÍA DE FINANCIAMIENTO")
        XCTAssertEqual(entries[0].amount, 88_000)
        XCTAssertEqual(entries[0].kind, .gasto)
        XCTAssertEqual(cal.component(.hour, from: entries[0].date), 11)
        XCTAssertEqual(entries[1].kind, .ingreso)
        XCTAssertEqual(entries[1].amount, 6_906)
        XCTAssertEqual(entries[2].kind, .gasto)
    }

    func testTarjetaConEncabezadoDeDia() {
        let text = """
        Hoy
        Uber*Rides $3.907,00
        11:03
        a 1 meses
        Sábado
        Uber*Rides $15.612,00
        23:37
        a 1 meses
        ¡Gracias por tu pago!
        Pagaste $100.000,00
        Viernes
        Comisión por servicio $5.000,00
        14:03
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.amount), [3_907, 15_612, 100_000, 5_000])
        XCTAssertEqual(entries[2].kind, .transferencia)
        XCTAssertEqual(entries[3].kind, .gasto)
        XCTAssertEqual(cal.component(.day, from: entries[0].date), 5)
        XCTAssertEqual(cal.component(.day, from: entries[1].date), 3)  // sábado anterior
        XCTAssertEqual(cal.component(.day, from: entries[3].date), 2)  // viernes anterior
    }

    func testCapturasRepetidasNoDuplican() {
        let text = "UBER*RIDES -$6.906,00\n05 oct - 11:19\nUBER*RIDES -$6.906,00\n05 oct - 11:19"
        XCTAssertEqual(ScreenshotParser.parse(text: text, now: now, calendar: cal).count, 1)
    }
}
