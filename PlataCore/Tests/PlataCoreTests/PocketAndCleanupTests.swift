import XCTest
@testable import PlataCore

/// Nombres y montos inventados.
final class OCRLayoutTests: XCTestCase {
    func piece(_ minX: Double, _ maxX: Double, _ y: Double, _ text: String) -> OCRPiece {
        OCRPiece(minX: minX, maxX: maxX, midY: y, text: text)
    }

    func testUneLosTrozosDeLaMismaFilaDeIzquierdaADerecha() {
        let pieces = [piece(0.75, 0.95, 0.301, "+$125.000,00"), piece(0.21, 0.55, 0.300, "Recibiste de ANA"),
                      piece(0.21, 0.60, 0.360, "04 oct - 12:09 • Bre-B"), piece(0.21, 0.50, 0.330, "DEMO PRUEBA")]
        XCTAssertEqual(OCRLayout.lines(from: pieces), "Recibiste de ANA +$125.000,00\nDEMO PRUEBA\n04 oct - 12:09 • Bre-B")
    }

    func testDescartaLoLeidoEnElIconoDeLaFila() {
        let pieces = [piece(0.21, 0.55, 0.300, "Recibiste de ANA"), piece(0.75, 0.95, 0.300, "+$125.000,00"),
                      piece(0.07, 0.15, 0.315, "·3"), piece(0.21, 0.50, 0.330, "DEMO PRUEBA"),
                      piece(0.07, 0.16, 0.400, "Ez"), piece(0.21, 0.50, 0.400, "Enviaste a LUIS"),
                      piece(0.75, 0.95, 0.400, "-$20.000,00")]
        XCTAssertEqual(OCRLayout.lines(from: pieces),
                       "Recibiste de ANA +$125.000,00\n·3\nDEMO PRUEBA\nEz Enviaste a LUIS -$20.000,00")
        XCTAssertEqual(OCRLayout.lines(from: pieces, dropIconColumn: true),
                       "Recibiste de ANA +$125.000,00\nDEMO PRUEBA\nEnviaste a LUIS -$20.000,00")
    }

    func testEncabezadoDeDiaYTextoAnchoQueEmpiezaEnElMargenSeConservan() {
        // La hora de la barra de estado cabe en la columna del ícono, pero está arriba: se conserva.
        let pieces = [piece(0.05, 0.13, 0.20, "Hoy"), piece(0.06, 0.45, 0.14, "$45.678,90"),
                      piece(0.09, 0.18, 0.02, "12:44"), piece(0.07, 0.10, 0.09, "<")]
        XCTAssertEqual(OCRLayout.lines(from: pieces, dropIconColumn: true), "12:44\n$45.678,90\nHoy")
    }
}

final class OCRCleanupTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    var now: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 13, minute: 10))! }

    func testRestosDelReconocimientoNoEntranEnElNombre() {
        let text = """
        Recibiste de ANA +$125.000,00
        ·3
        DEMO PRUEBA
        04 oct - 12:09 • Bre-B
        UBER*RIDES ” -$4.916,00
        04 oct - 08:32
        Enviaste a LUIS — -$20.000,00
        DEMO
        04 oct - 07:00 » Bre-B
        """
        let entries = ScreenshotParser.parse(text: text, now: now, calendar: cal)
        XCTAssertEqual(entries.map(\.description), ["Recibiste de ANA DEMO PRUEBA", "UBER*RIDES", "Enviaste a LUIS DEMO"])
        XCTAssertEqual(entries.map(\.amount), [125_000, 4_916, 20_000])
    }
}

final class GroupingStatsTests: XCTestCase {
    let nu = UUID()
    var octubre: DateInterval { Stats.monthInterval(containing: fecha(2026, 10, 15), calendar: bogota) }

    func move(_ amount: Int, _ kind: MovementKind, _ merchant: String, day: Int = 5) -> MovementSnapshot {
        MovementSnapshot(amount: amount, date: fecha(2026, 10, day), kind: kind, method: .llave, accountID: nu, merchant: merchant)
    }

    func testLaMismaPersonaOComercioConOtraEscrituraSeSuman() {
        let ms = [
            move(56_000, .ingreso, "Recibiste de Juan Demo Quiñónez"),
            move(130_000, .ingreso, "Recibiste de JUAN DEMO QUINONEZ"),
            move(20_000, .ingreso, "Recibiste de JUAN DEMO QUINONEZ"),
            move(40_000, .ingreso, "Recibiste de ANA DEMO"),
            move(5_000, .gasto, "UBER*RIDES"), move(7_000, .gasto, "UBER RIDES"), move(3_000, .gasto, "UBER*RIDES"),
            move(9_000, .gasto, "PAYU*UBER")
        ]
        XCTAssertEqual(Stats.incomeBySource(movements: ms, in: octubre),
                       [CategoryTotal(name: "JUAN DEMO QUINONEZ", amount: 206_000), CategoryTotal(name: "ANA DEMO", amount: 40_000)])
        XCTAssertEqual(Stats.topSpending(movements: ms, in: octubre),
                       [CategoryTotal(name: "UBER*RIDES", amount: 15_000), CategoryTotal(name: "PAYU*UBER", amount: 9_000)])
        // Los totales no cambian por agrupar.
        let s = Stats.summary(movements: ms, in: octubre, pendingFixed: 0, ownSavingsAccounts: [nu])
        XCTAssertEqual(s.income, 246_000)
        XCTAssertEqual(s.grossExpenses, 24_000)
    }

    func testAhorroSeparadoPorCajita() {
        let cajitas = UUID(), tarjeta = UUID()
        func transfer(_ amount: Int, from: UUID, to: UUID, _ merchant: String) -> MovementSnapshot {
            MovementSnapshot(amount: amount, date: fecha(2026, 10, 8), kind: .transferencia, method: .transferencia,
                             accountID: from, destinationAccountID: to, merchant: merchant)
        }
        let ms = [
            transfer(300_000, from: nu, to: cajitas, "Agregaste dinero a tu Cajita Mi primera Cajita"),
            transfer(100_000, from: cajitas, to: nu, "Retiraste dinero de tu Cajita Mi primera Cajita"),
            transfer(60_000, from: nu, to: cajitas, "Agregaste dinero a tu Cajita viaje"),
            transfer(30_000, from: cajitas, to: nu, "Retiraste dinero de tu Cajita viaje"),
            transfer(5_000, from: cajitas, to: nu, "Traslado desde cajitas"),
            transfer(200_000, from: nu, to: tarjeta, "Pagaste tu tarjeta")
        ]
        let byName = Stats.pocketFlowsByName(movements: ms, in: octubre, pocketAccounts: [cajitas])
        XCTAssertEqual(byName, [PocketTotal(name: "Mi primera Cajita", saved: 300_000, withdrawn: 100_000),
                                PocketTotal(name: "viaje", saved: 60_000, withdrawn: 30_000),
                                PocketTotal(name: "Cajitas", saved: 0, withdrawn: 5_000)])
        XCTAssertEqual(byName.map(\.net), [200_000, 30_000, -5_000])
        // Suma lo mismo que el total de cajitas.
        let total = Stats.pocketFlows(movements: ms, in: octubre, pocketAccounts: [cajitas])
        XCTAssertEqual(byName.reduce(0) { $0 + $1.saved }, total.saved)
        XCTAssertEqual(byName.reduce(0) { $0 + $1.withdrawn }, total.withdrawn)
    }
}

final class PocketMatchTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let nu = UUID(), cajitas = UUID(), tarjeta = UUID()
    let retiro = "Retiraste dinero de tu Cajita ahorro"
    let deposito = "Agregaste dinero a tu Cajita ahorro"

    func at(_ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: minute))!
    }

    func entry(_ amount: Int, _ date: Date, _ direction: PocketDirection) -> StatementEntry {
        StatementEntry(date: date, description: direction == .fromPocket ? retiro : deposito, amount: amount,
                       kind: .transferencia, balance: nil, hasTime: true, pocket: direction)
    }

    func stored(_ amount: Int, _ date: Date, _ kind: MovementKind, from: UUID?, to: UUID? = nil, _ merchant: String?) -> MovementSnapshot {
        MovementSnapshot(amount: amount, date: date, kind: kind, method: .transferencia, accountID: from,
                         destinationAccountID: to, merchant: merchant)
    }

    func testVolverAImportarCajitasNoDuplica() {
        let existing = [stored(30_000, at(23, 14), .transferencia, from: cajitas, to: nu, retiro),
                        stored(60_000, at(20, 39), .transferencia, from: nu, to: cajitas, deposito)]
        let entries = [entry(30_000, at(23, 14), .fromPocket), entry(60_000, at(20, 39), .toPocket)]
        let matches = StatementReconciler.match(entries, accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(matches, [0: existing[0].id, 1: existing[1].id])
    }

    func testCajitaEnSentidoContrarioYPagoATarjetaNoSeConfunden() {
        // Está registrado el retiro de las 20:38 y un pago a tarjeta; el depósito de las 20:39 por el mismo monto es nuevo.
        let existing = [stored(60_000, at(20, 38), .transferencia, from: cajitas, to: nu, retiro),
                        stored(60_000, at(20, 30), .transferencia, from: nu, to: tarjeta, "Pagaste tu tarjeta")]
        let cardPayment = StatementEntry(date: at(20, 30), description: "Pagaste tu tarjeta", amount: 60_000,
                                         kind: .transferencia, balance: nil, hasTime: true)
        let matches = StatementReconciler.match([entry(60_000, at(20, 39), .toPocket), cardPayment], accountID: nu,
                                                existing: existing, calendar: cal)
        XCTAssertEqual(matches, [1: existing[1].id])
    }

    func testCajitaGuardadaComoIngresoOGastoPorUnaVersionAnteriorNoSeDuplica() {
        let existing = [stored(30_000, at(23, 14), .ingreso, from: nu, retiro),
                        stored(60_000, at(20, 39), .gasto, from: nu, deposito)]
        let entries = [entry(30_000, at(23, 14), .fromPocket), entry(60_000, at(20, 39), .toPocket)]
        let matches = StatementReconciler.match(entries, accountID: nu, existing: existing, calendar: cal)
        XCTAssertEqual(matches, [0: existing[0].id, 1: existing[1].id])
        // Y se pueden corregir: son traslados, no ingreso ni gasto.
        XCTAssertEqual(PocketRepair.legacy(existing).map(\.direction), [.fromPocket, .toPocket])
    }

    func testRenglonDeExtractoDeCajitaCoincideConElTrasladoYaRegistrado() {
        let existing = [stored(30_000, at(23, 14), .transferencia, from: cajitas, to: nu, retiro)]
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 8))!
        let row = StatementEntry(date: day, description: retiro, amount: 30_000, kind: .ingreso, balance: nil)
        XCTAssertEqual(StatementReconciler.match([row], accountID: nu, existing: existing, calendar: cal), [0: existing[0].id])
        // Un ingreso cualquiera por el mismo monto no es ese traslado.
        let income = StatementEntry(date: day, description: "Recibiste de ANA DEMO", amount: 30_000, kind: .ingreso, balance: nil)
        XCTAssertTrue(StatementReconciler.match([income], accountID: nu, existing: existing, calendar: cal).isEmpty)
    }
}

final class PocketCaptureTests: XCTestCase {
    func hint(_ id: UUID = UUID(), pocket: Bool = false) -> AccountHint {
        AccountHint(id: id, bank: .nu, kind: .ahorros, last4: [], walletCardName: pocket ? nil : "Nu Débito",
                    emailSenders: [], isPocket: pocket)
    }

    func testLasCajitasNoCompitenPorLosAvisosDelBanco() {
        let nu = hint(), cajitas = hint(pocket: true)
        XCTAssertEqual(AccountMatcher.match(bank: .nu, last4: nil, method: .debito, sender: nil, hints: [nu, cajitas]), nu.id)
        XCTAssertEqual(AccountMatcher.match(walletCardName: "Nu Débito", hints: [cajitas, nu])?.id, nu.id)
        // Sin la marca son dos cuentas de ahorros del mismo banco y ningún aviso encuentra la suya.
        XCTAssertNil(AccountMatcher.match(bank: .nu, last4: nil, method: .debito, sender: nil, hints: [nu, hint()]))
    }

    func testAvisoDeCajitaEsUnTrasladoPorRevisar() throws {
        let out = try XCTUnwrap(GenericParser.parse(text: "Retiraste $30.000 de tu Cajita viaje"))
        XCTAssertEqual(out.kind, .transferencia)
        XCTAssertEqual(out.pocket, .fromPocket)
        XCTAssertEqual(out.amount, 30_000)
        XCTAssertEqual(out.merchant, "Retiraste dinero de tu Cajita viaje")
        XCTAssertFalse(out.isExplicit)
        // El texto guardado sirve después para reconocer el sentido y la cajita.
        XCTAssertEqual(MovementClassifier.pocketDirection(out.merchant ?? ""), .fromPocket)
        XCTAssertEqual(MovementClassifier.pocketName(out.merchant ?? ""), "viaje")

        let into = try XCTUnwrap(GenericParser.parse(text: "Agregaste $60.000 a tu Cajita Mi primera Cajita"))
        XCTAssertEqual(into.pocket, .toPocket)
        XCTAssertEqual(into.merchant, "Agregaste dinero a tu Cajita Mi primera Cajita")

        // Un comercio que se llama «cajita» sigue siendo una compra.
        let shop = try XCTUnwrap(GenericParser.parse(text: "Pagaste $20.000 en LA CAJITA FELIZ con tu tarjeta débito"))
        XCTAssertEqual(shop.kind, .gasto)
        XCTAssertNil(shop.pocket)
    }

    func testSoloSeCorrigenLosMovimientosDeCajitaGuardadosComoIngresoOGasto() {
        let nu = UUID(), cajitas = UUID()
        func m(_ amount: Int, _ kind: MovementKind, _ account: UUID?, _ merchant: String, to: UUID? = nil) -> MovementSnapshot {
            MovementSnapshot(amount: amount, date: fecha(2026, 10, 8), kind: kind, method: .debito, accountID: account,
                             destinationAccountID: to, merchant: merchant)
        }
        let ms = [m(30_000, .ingreso, nu, "Retiraste dinero de tu Cajita ahorro"),
                  m(60_000, .gasto, nu, "Agregaste dinero a tu Cajita ahorro"),
                  m(10_000, .ingreso, nu, "Recibiste de ANA DEMO"),
                  m(20_000, .gasto, nu, "LA CAJITA FELIZ"),
                  m(40_000, .transferencia, cajitas, "Retiraste dinero de tu Cajita ahorro", to: nu),
                  m(50_000, .ingreso, nil, "Retiraste dinero de tu Cajita ahorro"),
                  m(5_000, .gasto, nu, "Retiraste dinero de tu Cajita ahorro")]
        XCTAssertEqual(PocketRepair.legacy(ms), [
            PocketRepair.Candidate(id: ms[0].id, direction: .fromPocket, amount: 30_000),
            PocketRepair.Candidate(id: ms[1].id, direction: .toPocket, amount: 60_000)])
    }
}

final class MovementSearchTests: XCTestCase {
    func testBuscaPorNombreSinTildesNiMayusculasYPorMonto() {
        XCTAssertTrue(MovementSearch.matches(query: "  ", texts: ["UBER"], amount: 1))
        XCTAssertTrue(MovementSearch.matches(query: "uber", texts: ["UBER*RIDES", nil], amount: 4_916))
        XCTAssertTrue(MovementSearch.matches(query: "quiñonez", texts: ["Recibiste de JUAN QUINONEZ"], amount: 1))
        XCTAssertTrue(MovementSearch.matches(query: "uber 4916", texts: ["UBER*RIDES"], amount: 4_916))
        XCTAssertFalse(MovementSearch.matches(query: "uber 9999", texts: ["UBER*RIDES"], amount: 4_916))
        XCTAssertTrue(MovementSearch.matches(query: "$4.916", texts: ["UBER"], amount: 4_916))
        XCTAssertTrue(MovementSearch.matches(query: "nu transporte", texts: ["UBER", "Transporte", "Ahorro Nu"], amount: 1))
        XCTAssertFalse(MovementSearch.matches(query: "rappi", texts: ["UBER", "Transporte"], amount: 4_916))
        // Un número que aparece en el texto también vale.
        XCTAssertTrue(MovementSearch.matches(query: "127", texts: ["PARRILLA 127"], amount: 19_000))
    }
}
