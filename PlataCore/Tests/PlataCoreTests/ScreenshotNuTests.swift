import XCTest
@testable import PlataCore

/// Las 7 capturas de la cuenta Nu de octubre, como las entrega el OCR: una fila por renglón, con el buscador
/// arriba, las filas cortadas en los bordes y los movimientos repetidos entre capturas.
final class ScreenshotNuTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13, minute: 30))! }
    static let header = "1:31\n4G 84\nQ Buscar movimiento\n"

    var pages: [String] {
        [
            Self.header + """
            Pagaste en NEQUI S.A. -$88.000,00
            COMPAÑÍA DE
            FINANCIAMIENTO
            05 oct - 11:59
            Hicimos un reembolso +$6.906,00
            05 oct - 11:41
            UBER*RIDES -$7.280,00
            05 oct - 11:41
            UBER*RIDES -$6.906,00
            05 oct - 11:19
            Hicimos un reembolso +$2.914,00
            05 oct - 11:18
            PAYU*UBER -$2.914,00
            05 oct - 11:15
            Hicimos un reembolso +$10.900,00
            03 oct - 22:47
            UBER RIDES -$12.233,00
            03 oct - 22:47
            """,
            Self.header + """
            Hicimos un reembolso +$10.900,00
            03 oct - 22:47
            UBER RIDES -$12.233,00
            03 oct - 22:47
            UBER*RIDES -$10.900,00
            03 oct - 22:24
            Hicimos un reembolso +$6.916,00
            03 oct - 22:19
            Enviaste a MARIA -$4.500,00
            ANGELICA PARRA GRAZT
            03 oct - 21:57 • Bre-B
            UBER*RIDES -$6.916,00
            03 oct - 21:56
            Enviaste a SOFIA SANTIS -$5.500,00
            SILVA
            03 oct - 20:45 • Bre-B
            Enviaste a Juan Sebastian -$50.000,00
            Giraldo Quiñónez
            03 oct - 14:28 • Bre-B
            """,
            Self.header + """
            Giraldo Quiñónez
            03 oct - 14:28 • Bre-B
            Pagaste tu tarjeta -$100.000,00
            03 oct - 09:31
            Recibiste de LIDY +$270.000,00
            OSORIO CARRENO
            03 oct - 08:49 • Bre-B
            Enviaste a DANIEL SUAREZ -$9.000,00
            03 oct - 08:32 • Bre-B
            OXXO MENSULI HIC -$3.000,00
            02 oct - 16:38
            Enviaste a PARRILLA -$19.000,00
            SANTANDERENANA 127
            ELVER PICO
            02 oct - 14:04 • Bre-B
            Enviaste a ORLANDO -$20.100,00
            ENRIQUE ANGARITA
            PINZON
            02 oct - 12:58 • Bre-B
            Enviaste a MANUEL -$10.000,00
            """,
            Self.header + """
            Enviaste a MANUEL -$10.000,00
            ALEJANDRO ACERO
            MALDONADO
            02 oct - 02:02 • Bre-B
            Enviaste a Iván Darío -$6.000,00
            Florez Carvajal
            01 oct - 20:52 • Bre-B
            Enviaste a TIENDA P2 -$5.000,00
            LIBARDO LOZANO
            01 oct - 20:38 • Bre-B
            Hicimos un reembolso +$3.904,00
            01 oct - 18:13
            UBER*RIDES -$4.047,00
            01 oct - 18:13
            UBER*RIDES -$3.904,00
            01 oct - 17:47
            Enviaste a MARIA -$4.000,00
            ANGELICA PARRA GRAZT
            01 oct - 15:22 • Bre-B
            Recibiste de SOFIA +$4.000,00
            """,
            Self.header + """
            Recibiste de SOFIA +$4.000,00
            SANTIS SILVA
            01 oct - 15:11 • Bre-B
            Enviaste a ADRIANO -$2.000,00
            PEARANDA CALDERON
            01 oct - 14:59 • Bre-B
            Hicimos un reembolso +$7.913,00
            01 oct - 14:21
            UBER*RIDES -$7.913,00
            01 oct - 14:05
            NOVAVENTA -$4.000,00
            01 oct - 12:08
            NOVAVENTA -$4.000,00
            01 oct - 11:53
            Hicimos un reembolso +$7.908,00
            01 oct - 11:07
            UBER*RIDES -$8.916,00
            01 oct - 11:07
            """,
            Self.header + """
            NOVAVENTA -$4.000,00
            01 oct - 12:08
            NOVAVENTA -$4.000,00
            01 oct - 11:53
            Hicimos un reembolso +$7.908,00
            01 oct - 11:07
            UBER*RIDES -$8.916,00
            01 oct - 11:07
            UBER*RIDES -$7.908,00
            01 oct - 10:41
            Enviaste a SANTIAGO -$20.000,00
            ANDRES FONSECA
            VARGAS
            01 oct - 10:26 • Bre-B
            Recibiste de SANTIAGO +$55.000,00
            DAVID DE LA HOZ
            SIERRA
            01 oct - 10:24 • Bre-B
            """,
        ]
    }

    func testLeeLas7CapturasSinPerderNiInventarMovimientos() {
        let text = pages.joined(separator: "\n\(ScreenshotParser.pageBreak)\n")
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        func total(_ kind: MovementKind) -> Int { entries.filter { $0.kind == kind }.reduce(0) { $0 + $1.amount } }
        XCTAssertEqual(entries.count, 38)
        XCTAssertEqual(total(.ingreso), 376_361)        // 329.000 de ingresos + 47.361 de reembolsos
        XCTAssertEqual(total(.transferencia), 100_000)  // «Pagaste tu tarjeta»
        XCTAssertEqual(total(.gasto), 333_937)          // incluye las 2 retenciones del reloj, que se desmarcan a mano
        XCTAssertFalse(entries.contains { $0.description.lowercased().contains("buscar") })
    }

    func testEstadisticasMuestranLoQueEntroYSalioComoElBanco() {
        let text = pages.joined(separator: "\n\(ScreenshotParser.pageBreak)\n")
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        let nu = UUID()
        let ms = entries.map {
            MovementSnapshot(amount: $0.amount, date: $0.date, kind: $0.kind, method: .transferencia, accountID: nu,
                             isRefund: $0.kind == .ingreso && MovementClassifier.isRefund($0.description),
                             merchant: $0.description)
        }
        let month = Stats.monthInterval(containing: now, calendar: cal)
        let s = Stats.summary(movements: ms, in: month, pendingFixed: 0, ownSavingsAccounts: [nu])
        XCTAssertEqual(s.income, 329_000)
        XCTAssertEqual(s.refunds, 47_361)
        XCTAssertEqual(s.totalIn, 376_361)
        XCTAssertEqual(s.grossExpenses, 333_937)
        XCTAssertEqual(s.totalOut, 433_937)
        XCTAssertEqual(s.totalIn - s.totalOut, -57_576)
        XCTAssertEqual(s.saved, -57_576)
    }
}
