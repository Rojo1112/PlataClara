import XCTest
@testable import PlataCore

/// 7 capturas de la lista de movimientos de la cuenta Nu, como las entrega el OCR: una fila por renglón, con el
/// buscador arriba, las filas cortadas en los bordes y los movimientos repetidos entre capturas.
/// Nombres y montos inventados.
final class ScreenshotNuTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 13, minute: 30))! }
    static let header = "1:31\n4G 84\nQ Buscar movimiento\n"

    var pages: [String] {
        [
            Self.header + """
            Pagaste en NEQUI S.A. -$75.000,00
            COMPAÑÍA DE
            FINANCIAMIENTO
            05 mar - 11:59
            Hicimos un reembolso +$5.410,00
            05 mar - 11:41
            UBER*RIDES -$6.150,00
            05 mar - 11:41
            UBER*RIDES -$5.410,00
            05 mar - 11:19
            Hicimos un reembolso +$3.120,00
            05 mar - 11:18
            PAYU*UBER -$3.120,00
            05 mar - 11:15
            Hicimos un reembolso +$9.870,00
            03 mar - 22:47
            UBER RIDES -$11.450,00
            03 mar - 22:47
            """,
            Self.header + """
            Hicimos un reembolso +$9.870,00
            03 mar - 22:47
            UBER RIDES -$11.450,00
            03 mar - 22:47
            UBER*RIDES -$9.870,00
            03 mar - 22:24
            Hicimos un reembolso +$7.230,00
            03 mar - 22:19
            Enviaste a LAURA -$3.500,00
            PRUEBA GOMEZ RUIZ
            03 mar - 21:57 • Bre-B
            UBER*RIDES -$7.230,00
            03 mar - 21:56
            Enviaste a ANA DEMO -$6.000,00
            CASTRO
            03 mar - 20:45 • Bre-B
            Enviaste a Pedro Ejemplo -$40.000,00
            Quiñónez Ríos
            03 mar - 14:28 • Bre-B
            """,
            Self.header + """
            Quiñónez Ríos
            03 mar - 14:28 • Bre-B
            Pagaste tu tarjeta -$80.000,00
            03 mar - 09:31
            Recibiste de CARLOS +$250.000,00
            FICTICIO DIAZ
            03 mar - 08:49 • Bre-B
            Enviaste a LUIS TORRES -$8.000,00
            03 mar - 08:32 • Bre-B
            OXXO CENTRO -$2.500,00
            02 mar - 16:38
            Enviaste a ASADERO -$17.000,00
            LA ESQUINA 45
            JOSE PRUEBA
            02 mar - 14:04 • Bre-B
            Enviaste a MARTA -$18.300,00
            ELENA SUAREZ
            VEGA
            02 mar - 12:58 • Bre-B
            Enviaste a JORGE -$12.000,00
            """,
            Self.header + """
            Enviaste a JORGE -$12.000,00
            ANDRES MOLINA
            PEREZ
            02 mar - 02:02 • Bre-B
            Enviaste a Iván Darío -$5.500,00
            Ejemplo Mora
            01 mar - 20:52 • Bre-B
            Enviaste a TIENDA B3 -$4.500,00
            DON PRUEBA
            01 mar - 20:38 • Bre-B
            Hicimos un reembolso +$4.210,00
            01 mar - 18:13
            UBER*RIDES -$4.380,00
            01 mar - 18:13
            UBER*RIDES -$4.210,00
            01 mar - 17:47
            Enviaste a LAURA -$3.000,00
            PRUEBA GOMEZ RUIZ
            01 mar - 15:22 • Bre-B
            Recibiste de ANA +$5.000,00
            """,
            Self.header + """
            Recibiste de ANA +$5.000,00
            DEMO CASTRO
            01 mar - 15:11 • Bre-B
            Enviaste a RAUL -$1.500,00
            FICTICIO LEON
            01 mar - 14:59 • Bre-B
            Hicimos un reembolso +$8.640,00
            01 mar - 14:21
            UBER*RIDES -$8.640,00
            01 mar - 14:05
            NOVAVENTA -$3.500,00
            01 mar - 12:08
            NOVAVENTA -$3.500,00
            01 mar - 11:53
            Hicimos un reembolso +$6.790,00
            01 mar - 11:07
            UBER*RIDES -$7.920,00
            01 mar - 11:07
            """,
            Self.header + """
            NOVAVENTA -$3.500,00
            01 mar - 12:08
            NOVAVENTA -$3.500,00
            01 mar - 11:53
            Hicimos un reembolso +$6.790,00
            01 mar - 11:07
            UBER*RIDES -$7.920,00
            01 mar - 11:07
            UBER*RIDES -$6.790,00
            01 mar - 10:41
            Enviaste a TOMAS -$15.000,00
            PRUEBA LOPEZ
            ROJAS
            01 mar - 10:26 • Bre-B
            Recibiste de MATEO +$60.000,00
            DE LA PRUEBA
            VIDAL
            01 mar - 10:24 • Bre-B
            """,
        ]
    }

    func testLeeLas7CapturasSinPerderNiInventarMovimientos() {
        let text = pages.joined(separator: "\n\(ScreenshotParser.pageBreak)\n")
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        func total(_ kind: MovementKind) -> Int { entries.filter { $0.kind == kind }.reduce(0) { $0 + $1.amount } }
        XCTAssertEqual(entries.count, 38)
        XCTAssertEqual(total(.ingreso), 360_270)        // 315.000 de ingresos + 45.270 de reembolsos
        XCTAssertEqual(total(.transferencia), 80_000)   // «Pagaste tu tarjeta»
        XCTAssertEqual(total(.gasto), 293_970)          // incluye las 2 retenciones del reloj, que se desmarcan a mano
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
        XCTAssertEqual(s.income, 315_000)
        XCTAssertEqual(s.refunds, 45_270)
        XCTAssertEqual(s.totalIn, 360_270)
        XCTAssertEqual(s.grossExpenses, 293_970)
        XCTAssertEqual(s.totalOut, 373_970)
        XCTAssertEqual(s.totalIn - s.totalOut, -13_700)
        XCTAssertEqual(s.saved, -13_700)
    }
}
