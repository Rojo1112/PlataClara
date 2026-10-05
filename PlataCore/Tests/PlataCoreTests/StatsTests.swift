import XCTest
@testable import PlataCore

final class StatsTests: XCTestCase {
    let nu = UUID()
    let tarjeta = UUID()
    var octubre: DateInterval { Stats.monthInterval(containing: fecha(2026, 10, 15), calendar: bogota) }

    var movimientos: [MovementSnapshot] {
        [
            MovementSnapshot(amount: 3_000_000, date: fecha(2026, 10, 1), kind: .ingreso, method: .transferencia, accountID: nu, categoryName: "Salario"),
            MovementSnapshot(amount: 200_000, date: fecha(2026, 10, 5), kind: .gasto, method: .credito, accountID: tarjeta, categoryName: "Mercado"),
            MovementSnapshot(amount: 50_000, date: fecha(2026, 10, 6), kind: .gasto, method: .qr, accountID: nu, categoryName: "Restaurantes"),
            MovementSnapshot(amount: 10_000, date: fecha(2026, 10, 7), kind: .gasto, method: .llave, accountID: nu),
            MovementSnapshot(amount: 200_000, date: fecha(2026, 10, 20), kind: .transferencia, method: .transferencia, accountID: nu, destinationAccountID: tarjeta),
            MovementSnapshot(amount: 999, date: fecha(2026, 10, 8), kind: .gasto, method: .debito, accountID: nu, status: .porRevisar),
            MovementSnapshot(amount: 70_000, date: fecha(2026, 9, 30, 23), kind: .gasto, method: .debito, accountID: nu)
        ]
    }

    func testSummaryCountsCardPurchasesButNotCardPayments() {
        let s = Stats.summary(movements: movimientos, in: octubre, pendingFixed: 1_000_000)
        XCTAssertEqual(s.income, 3_000_000)
        XCTAssertEqual(s.expenses, 260_000)
        XCTAssertEqual(s.saved, 2_740_000)
        XCTAssertEqual(s.possibleSaving, 1_740_000)
        XCTAssertEqual(s.savingsRate, 2_740_000.0 / 3_000_000.0, accuracy: 0.0001)
    }

    func testSavingsRateIsZeroWithoutIncome() {
        XCTAssertEqual(MonthSummary(income: 0, expenses: 5_000, pendingFixed: 0).savingsRate, 0)
    }

    func testExpensesByCategorySortedByAmount() {
        XCTAssertEqual(Stats.expensesByCategory(movements: movimientos, in: octubre), [
            CategoryTotal(name: "Mercado", amount: 200_000),
            CategoryTotal(name: "Restaurantes", amount: 50_000),
            CategoryTotal(name: "Sin categoría", amount: 10_000)
        ])
    }

    func testExpensesByMethod() {
        XCTAssertEqual(Stats.expensesByMethod(movements: movimientos, in: octubre), [
            MethodTotal(method: .credito, amount: 200_000),
            MethodTotal(method: .qr, amount: 50_000),
            MethodTotal(method: .llave, amount: 10_000)
        ])
    }

    func testAverageDailyExpense() {
        XCTAssertEqual(Stats.averageDailyExpense(expenses: 310_000, interval: octubre, today: fecha(2026, 10, 10), calendar: bogota), 31_000)
        XCTAssertEqual(Stats.averageDailyExpense(expenses: 310_000, interval: octubre, today: fecha(2026, 11, 5), calendar: bogota), 10_000)
    }
}

final class RefundStatsTests: XCTestCase {
    func testReembolsoRestaDelGastoYNoEsIngreso() {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 5))!
        let interval = Stats.monthInterval(containing: day, calendar: cal)
        let ms = [
            MovementSnapshot(amount: 10_000, date: day, kind: .gasto, method: .debito, accountID: nil),
            MovementSnapshot(amount: 4_000, date: day, kind: .ingreso, method: .transferencia, accountID: nil, isRefund: true),
            MovementSnapshot(amount: 50_000, date: day, kind: .ingreso, method: .transferencia, accountID: nil),
        ]
        let s = Stats.summary(movements: ms, in: interval, pendingFixed: 0)
        XCTAssertEqual(s.income, 50_000)
        XCTAssertEqual(s.expenses, 6_000)
    }

    func testDetectaReembolsos() {
        XCTAssertTrue(MovementClassifier.isRefund("Hicimos un reembolso"))
        XCTAssertTrue(MovementClassifier.isRefund("Reversión compra"))
        XCTAssertFalse(MovementClassifier.isRefund("Compra en UBER*RIDES"))
    }
}

final class CashFlowStatsTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let nu = UUID()

    /// Como el mes de octubre de las capturas: los ingresos no alcanzan para gastos más el pago de la tarjeta.
    func testPagoATarjetaSinComprasRegistradasCuentaComoSalida() {
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let interval = Stats.monthInterval(containing: day, calendar: cal)
        let ms = [
            MovementSnapshot(amount: 329_000, date: day, kind: .ingreso, method: .llave, accountID: nu),
            MovementSnapshot(amount: 333_937, date: day, kind: .gasto, method: .debito, accountID: nu),
            MovementSnapshot(amount: 47_361, date: day, kind: .ingreso, method: .transferencia, accountID: nu, isRefund: true),
            MovementSnapshot(amount: 100_000, date: day, kind: .transferencia, method: .transferencia, accountID: nu),
        ]
        let s = Stats.summary(movements: ms, in: interval, pendingFixed: 0, ownSavingsAccounts: [nu])
        XCTAssertEqual(s.income, 329_000)
        XCTAssertEqual(s.expenses, 286_576)
        XCTAssertEqual(s.cardPayments, 100_000)
        XCTAssertEqual(s.outflow, 386_576)
        XCTAssertTrue(s.overspent)
        XCTAssertEqual(s.deficit, 57_576)
    }

    func testTransferenciaEntreCuentasPropiasNoEsSalida() {
        let lulo = UUID()
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        let interval = Stats.monthInterval(containing: day, calendar: cal)
        let ms = [MovementSnapshot(amount: 50_000, date: day, kind: .transferencia, method: .transferencia,
                                   accountID: nu, destinationAccountID: lulo)]
        let s = Stats.summary(movements: ms, in: interval, pendingFixed: 0, ownSavingsAccounts: [nu, lulo])
        XCTAssertEqual(s.outflow, 0)
        XCTAssertFalse(s.overspent)
    }

    func testCategoriasAutomaticas() {
        XCTAssertEqual(AutoCategory.guess("UBER*RIDES"), "Transporte")
        XCTAssertEqual(AutoCategory.guess("PAYU*UBER"), "Transporte")
        XCTAssertEqual(AutoCategory.guess("Enviaste a MARIA ANGELICA PARRA"), "Envíos y billeteras")
        XCTAssertEqual(AutoCategory.guess("OXXO MENSULI HIC"), "Mercado")
        XCTAssertEqual(AutoCategory.guess("Comisión por servicio"), "Costos financieros")
        XCTAssertEqual(AutoCategory.guess("NOVAVENTA"), "Compras")
        XCTAssertNil(AutoCategory.guess("PARRA"))
    }
}
