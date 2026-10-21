import XCTest
@testable import PlataCore

/// Cuadre automático con el banco. Todos los montos y nombres son inventados.
final class BalanceAuditTests: XCTestCase {
    let cuenta = AccountSnapshot(kind: .ahorros, openingBalance: 0)
    let tarjeta = AccountSnapshot(kind: .credito, openingBalance: 0)

    func finDelDia(_ y: Int, _ m: Int, _ d: Int) -> Date {
        bogota.date(from: DateComponents(year: y, month: m, day: d, hour: 23, minute: 59, second: 59))!
    }

    func cuadre(_ balance: Int, _ date: Date, _ account: AccountSnapshot? = nil) -> CheckpointSnapshot {
        CheckpointSnapshot(accountID: (account ?? cuenta).id, date: date, balance: balance, source: .manual)
    }

    func mov(_ amount: Int, _ kind: MovementKind, _ date: Date, hold: Bool = false, status: MovementStatus = .confirmado,
             merchant: String = "Comercio de prueba", account: AccountSnapshot? = nil) -> MovementSnapshot {
        MovementSnapshot(amount: amount, date: date, kind: kind, method: .debito, accountID: (account ?? cuenta).id,
                         status: status, merchant: merchant, isHold: hold)
    }

    func audit(_ ms: [MovementSnapshot], _ cps: [CheckpointSnapshot], now: Date = fecha(2026, 3, 10)) -> AccountAudit {
        BalanceAudit.audit(account: cuenta, movements: ms, checkpoints: cps, now: now, calendar: bogota)
    }

    // MARK: saldo anclado al banco

    func testSaldoPartedelUltimoCuadreYSoloSumaLoPosterior() {
        let ms = [mov(40_000, .gasto, fecha(2026, 3, 1, 9)),        // antes del cuadre: ya está dentro del saldo del banco
                  mov(10_000, .gasto, fecha(2026, 3, 2, 10)),       // misma hora que el cuadre: cuenta antes
                  mov(25_000, .ingreso, fecha(2026, 3, 3, 8))]
        let cps = [cuadre(100_000, fecha(2026, 3, 2, 10))]
        XCTAssertEqual(Ledger.balance(of: cuenta, movements: ms, checkpoints: cps), 125_000)
        XCTAssertEqual(Ledger.balance(of: cuenta, movements: ms, checkpoints: []), -25_000)
        XCTAssertEqual(Ledger.balance(of: cuenta, movements: ms, checkpoints: cps, at: fecha(2026, 3, 2, 23)), 100_000)
    }

    func testCuadreDeTarjetaEsLaDeuda() {
        let ms = [mov(30_000, .gasto, fecha(2026, 3, 5), account: tarjeta)]
        let cps = [cuadre(200_000, fecha(2026, 3, 4), tarjeta)]
        XCTAssertEqual(Ledger.balance(of: tarjeta, movements: ms, checkpoints: cps), 230_000)
        XCTAssertEqual(Ledger.totalDebt(accounts: [cuenta, tarjeta], movements: ms, checkpoints: cps), 230_000)
    }

    // MARK: confianza

    func testCuadreDeHoySinMovimientosDespuesEsVerificado() {
        let result = audit([], [cuadre(50_000, fecha(2026, 3, 10, 8))], now: fecha(2026, 3, 10, 18))
        XCTAssertEqual(result.confidence, .verificado)
        XCTAssertEqual(result.balance, 50_000)
    }

    func testTramoQueCuadraDaConfianzaAlta() {
        let ms = [mov(20_000, .gasto, fecha(2026, 3, 3)), mov(5_000, .ingreso, fecha(2026, 3, 4))]
        let result = audit(ms, [cuadre(100_000, finDelDia(2026, 3, 1)), cuadre(85_000, finDelDia(2026, 3, 5))])
        XCTAssertEqual(result.confidence, .alto)
        XCTAssertEqual(result.segments.count, 2)
        XCTAssertTrue(result.segments[1].matches)
        XCTAssertEqual(result.unexplained, 0)
    }

    func testSinCuadresEsConfianzaMedia() {
        let result = audit([mov(5_000, .ingreso, fecha(2026, 3, 4))], [])
        XCTAssertEqual(result.confidence, .medio)
        XCTAssertEqual(result.balance, 5_000)
    }

    // MARK: diagnóstico

    func testSaldoNegativoMarcaDondeFaltaPlata() {
        let ms = [mov(30_000, .gasto, fecha(2026, 3, 2, 8)),
                  mov(5_000, .ingreso, fecha(2026, 3, 2, 9)),
                  mov(1_000, .gasto, fecha(2026, 3, 2, 10))]
        let result = audit(ms, [cuadre(10_000, finDelDia(2026, 3, 1))])
        let open = result.segments[0]
        XCTAssertEqual(open.dip, NegativeDip(firstNegative: fecha(2026, 3, 2, 8), shortfall: 20_000))
        XCTAssertEqual(result.confidence, .bajo)
        XCTAssertEqual(result.unexplained, 20_000)
        XCTAssertEqual(open.pocketFix?.action, .pocketTransfer(amount: 20_000, date: fecha(2026, 3, 2, 7, 59)))
        // Entre el cuadre (23:59:59) y el primer movimiento (8:00) no hay nada registrado.
        XCTAssertEqual(open.gaps, [TimeGap(start: finDelDia(2026, 3, 1), end: fecha(2026, 3, 2, 8))])
    }

    func testReembolsoYCobroEnElMismoMinutoNoDanFalsoNegativo() {
        let ms = [mov(9_000, .gasto, fecha(2026, 3, 2, 8)), mov(9_000, .ingreso, fecha(2026, 3, 2, 8))]
        XCTAssertNil(audit(ms, [cuadre(1_000, finDelDia(2026, 3, 1))]).segments[0].dip)
    }

    func testRetencionesLiberadasExplicanLaDiferencia() {
        let a = mov(7_000, .gasto, fecha(2026, 3, 2, 9), hold: true)
        let b = mov(12_000, .gasto, fecha(2026, 3, 3, 9), hold: true)
        let c = mov(3_000, .gasto, fecha(2026, 3, 4, 9), hold: true)
        let ms = [a, b, c, mov(50_000, .gasto, fecha(2026, 3, 4, 12))]
        // Calculado: 100.000 − 72.000 = 28.000. El banco dice 47.000: se liberaron 7.000 y 12.000.
        let result = audit(ms, [cuadre(100_000, finDelDia(2026, 3, 1)), cuadre(47_000, finDelDia(2026, 3, 5))])
        let closed = result.segments[1]
        XCTAssertEqual(closed.difference, 19_000)
        XCTAssertEqual(Set(closed.explanation?.map(\.action) ?? []), [.releaseHold(a.id), .releaseHold(b.id)])
        XCTAssertEqual(closed.unexplained, 0)
        XCTAssertEqual(result.confidence, .medio)
    }

    func testMovimientoRepetidoExplicaLaDiferencia() {
        let first = mov(4_000, .gasto, fecha(2026, 3, 2, 9, 0))
        let copy = mov(4_000, .gasto, fecha(2026, 3, 2, 9, 5))
        let result = audit([first, copy, mov(60_000, .gasto, fecha(2026, 3, 3))],
                           [cuadre(100_000, finDelDia(2026, 3, 1)), cuadre(36_000, finDelDia(2026, 3, 5))])
        XCTAssertEqual(result.segments[1].explanation?.map(\.action), [.removeDuplicate(copy.id)])
    }

    func testMovimientoPorRevisarExplicaLaDiferencia() {
        let pending = mov(8_000, .ingreso, fecha(2026, 3, 3), status: .porRevisar)
        let result = audit([pending, mov(60_000, .gasto, fecha(2026, 3, 2))],
                           [cuadre(100_000, finDelDia(2026, 3, 1)), cuadre(48_000, finDelDia(2026, 3, 5))])
        XCTAssertEqual(result.segments[1].explanation?.map(\.action), [.confirmPending(pending.id)])
    }

    func testDiferenciaSinExplicarQuedaALaVista() {
        let result = audit([mov(10_000, .gasto, fecha(2026, 3, 3))],
                           [cuadre(100_000, finDelDia(2026, 3, 1)), cuadre(423_333, finDelDia(2026, 3, 5))])
        let closed = result.segments[1]
        XCTAssertNil(closed.explanation)
        XCTAssertEqual(closed.unexplained, 333_333)
        XCTAssertEqual(result.unexplained, 333_333)
        XCTAssertEqual(closed.pocketFix?.action, .pocketTransfer(amount: 333_333, date: finDelDia(2026, 3, 5)))
        XCTAssertEqual(result.confidence, .medio)
    }

    func testTarjetaNoUsaSaldoNegativoNiCajitas() {
        let ms = [mov(30_000, .ingreso, fecha(2026, 3, 2), account: tarjeta)]   // pagaste más de lo que debías
        let result = BalanceAudit.audit(account: tarjeta, movements: ms, checkpoints: [cuadre(10_000, finDelDia(2026, 3, 1), tarjeta)],
                                        now: fecha(2026, 3, 10), calendar: bogota)
        XCTAssertNil(result.segments[0].dip)
        XCTAssertNil(result.segments[0].pocketFix)
    }

    func testBusquedaDeCombinacionPrefiereLaMasPequena() {
        let fixes: [(date: Date, fix: Fix)] = [5_000, 2_000, 3_000].enumerated().map { i, amount in
            (fecha(2026, 3, 10 - i), Fix(action: .confirmPending(UUID()), effect: amount, summary: ""))
        }
        XCTAssertEqual(BalanceAudit.combination(for: 5_000, among: fixes)?.map(\.effect), [5_000])
        XCTAssertEqual(BalanceAudit.combination(for: 10_001, among: fixes)?.count, 3)
        XCTAssertNil(BalanceAudit.combination(for: 4_000, among: fixes))
    }

    // MARK: resumen del extracto y captura de inicio

    static let resumen = """
    Período
    01 - 30 MAR 2026
    Dinero en tu Cuenta Nu
    $61.234,50
    Rendimientos | 1,00% Efectivo Anual
    +$12,00
    Dinero en tus cajitas
    $150.000,00
    Resumen de tus movimientos
    Tu dinero al inicio del mes $50.000,00
    Lo que entró a tu cuenta +$1.200.000,00
    Lo que salió de tu cuenta -$1.388.990,50
    Impuesto del 4x1000 $1.000,00
    Costos por retiro $0,00
    Rendimiento total de tu cuenta +$225,00
    Tu dinero a final del mes $60.234,50
    """

    func testResumenDelExtractoYContinuidad() {
        let s = StatementParser.summary(in: Self.resumen, calendar: bogota)
        XCTAssertEqual(s.opening, 5_000_000)
        XCTAssertEqual(s.income, 120_000_000)
        XCTAssertEqual(s.outflow, 138_899_050)
        XCTAssertEqual(s.tax, 100_000)
        XCTAssertEqual(s.withdrawalCosts, 0)
        XCTAssertEqual(s.yield, 22_500)
        XCTAssertEqual(s.closing, 6_023_450)
        XCTAssertEqual(s.pockets, 15_000_000)
        XCTAssertEqual(s.periodEnd, finDelDia(2026, 3, 30))
        XCTAssertEqual(s.openingDate, finDelDia(2026, 2, 28))
        // 50.000 + 1.200.000 − 1.388.990,50 + 225 − 1.000 = −139.765,50; el banco dice 60.234,50: entraron 200.000 sin listar.
        XCTAssertEqual(s.continuityGap, 200_000)
        XCTAssertEqual(StatementSummary.pesos(s.closing), 60_234)
    }

    func testResumenIncompletoNoInventaContinuidad() {
        XCTAssertNil(StatementParser.summary(in: "Lo que entró a tu cuenta +$10.000,00", calendar: bogota).continuityGap)
    }

    func testLeeElSaldoDeLaPantallaDeInicio() {
        let text = """
        9:41
        Hola, Ana
        Cuenta
        $ 84.250,30
        Dinero en tus cajitas
        $ 1.500.000
        Tarjeta de crédito
        """
        XCTAssertEqual(HomeBalanceParser.parse(text: text), HomeBalance(account: 84_250, pockets: 1_500_000))
        XCTAssertEqual(HomeBalanceParser.parse(text: "Dinero disponible $12.000")?.account, 12_000)
        XCTAssertNil(HomeBalanceParser.parse(text: "Sin montos aquí"))
    }

    // MARK: estadísticas y respaldo

    func testIngresosPorOrigenYPlataDeTerceros() {
        let month = Stats.monthInterval(containing: fecha(2026, 3, 10), calendar: bogota)
        let ms = [mov(300_000, .ingreso, fecha(2026, 3, 2), merchant: "Recibiste de ANA PRUEBA"),
                  mov(100_000, .ingreso, fecha(2026, 3, 3), merchant: "Recibiste de ANA PRUEBA"),
                  mov(50_000, .ingreso, fecha(2026, 3, 4), merchant: "Te enviaron Empresa Demo"),
                  MovementSnapshot(amount: 9_000, date: fecha(2026, 3, 5), kind: .ingreso, method: .debito, accountID: cuenta.id,
                                   isRefund: true, merchant: "Hicimos un reembolso"),
                  MovementSnapshot(amount: 80_000, date: fecha(2026, 3, 6), kind: .gasto, method: .debito, accountID: cuenta.id,
                                   merchant: "Pago por un amigo", isExternal: true),
                  MovementSnapshot(amount: 100_000, date: fecha(2026, 3, 7), kind: .ingreso, method: .debito, accountID: cuenta.id,
                                   merchant: "Recibiste de Amigo", isExternal: true)]
        XCTAssertEqual(Stats.incomeBySource(movements: ms, in: month),
                       [CategoryTotal(name: "ANA PRUEBA", amount: 400_000), CategoryTotal(name: "Empresa Demo", amount: 50_000)])
        XCTAssertEqual(Stats.thirdPartyNet(movements: ms, in: month), 20_000)
    }

    func testRespaldoAnteriorSinPuntosDeCuadreSeSigueLeyendo() throws {
        let old = """
        {"formatVersion":1,"exportedAt":"2026-03-01T12:00:00Z","accounts":[],"categories":[],"movements":[],
         "recurring":[],"occurrences":[]}
        """
        XCTAssertNil(try BackupCodec.decode(Data(old.utf8)).checkpoints)

        let cp = CheckpointDTO(id: UUID(), accountID: UUID(), date: Date(timeIntervalSince1970: 1_770_000_000),
                               balance: 12_345, source: .captura)
        let file = BackupFile(exportedAt: Date(timeIntervalSince1970: 1_770_000_000), accounts: [], categories: [],
                              movements: [], recurring: [], occurrences: [], checkpoints: [cp])
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode(file)).checkpoints, [cp])
    }
}
