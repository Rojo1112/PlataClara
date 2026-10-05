import XCTest
@testable import PlataCore

final class RecurringPlannerTests: XCTestCase {
    func testMonthKey() {
        XCTAssertEqual(RecurringPlanner.monthKey(for: fecha(2026, 10, 4), calendar: bogota), "2026-10")
        XCTAssertEqual(RecurringPlanner.monthKey(for: fecha(2027, 2, 1), calendar: bogota), "2027-02")
    }

    func testDay31ClampsToLastDayOfFebruary() {
        XCTAssertEqual(RecurringPlanner.dueDate(day: 31, inMonthOf: fecha(2026, 2, 10), calendar: bogota), fecha(2026, 2, 28, 0))
        XCTAssertEqual(RecurringPlanner.dueDate(day: 31, inMonthOf: fecha(2026, 11, 3), calendar: bogota), fecha(2026, 11, 30, 0))
    }

    func testCreatesOnlyActiveAndMissingOccurrences() {
        let arriendo = RecurringSnapshot(name: "Arriendo", amount: 1_200_000, dayOfMonth: 5, accountID: nil, active: true)
        let netflix = RecurringSnapshot(name: "Netflix", amount: 40_000, dayOfMonth: 12, accountID: nil, active: false)
        let internet = RecurringSnapshot(name: "Internet", amount: 90_000, dayOfMonth: 15, accountID: nil, active: true)
        let result = RecurringPlanner.occurrencesToCreate(month: fecha(2026, 10, 4), recurring: [arriendo, netflix, internet],
                                                          alreadyCreated: [internet.id], calendar: bogota)
        XCTAssertEqual(result, [DueOccurrence(recurringID: arriendo.id, dueDate: fecha(2026, 10, 5, 0))])
    }

    func testMatchesExpenseNearDueDateWithinTenPercent() {
        let cuenta = UUID()
        let pendiente = PendingOccurrence(amount: 1_200_000, accountID: cuenta, dueDate: fecha(2026, 10, 5, 0))
        func gasto(_ amount: Int, _ day: Int, account: UUID? = cuenta, kind: MovementKind = .gasto) -> MovementSnapshot {
            MovementSnapshot(amount: amount, date: fecha(2026, 10, day), kind: kind, method: .llave, accountID: account)
        }
        XCTAssertEqual(RecurringPlanner.matchingPending(for: gasto(1_150_000, 6), pending: [pendiente]), pendiente.id)
        XCTAssertNil(RecurringPlanner.matchingPending(for: gasto(1_000_000, 6), pending: [pendiente]))
        XCTAssertNil(RecurringPlanner.matchingPending(for: gasto(1_200_000, 6, account: UUID()), pending: [pendiente]))
        XCTAssertNil(RecurringPlanner.matchingPending(for: gasto(1_200_000, 6, kind: .ingreso), pending: [pendiente]))
        XCTAssertNil(RecurringPlanner.matchingPending(for: gasto(1_200_000, 20), pending: [pendiente]))
    }
}
