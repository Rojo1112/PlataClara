import XCTest
@testable import PlataCore

final class BackupTests: XCTestCase {
    let at = Date(timeIntervalSince1970: 1_790_000_000)

    func sample(version: Int = BackupFile.currentVersion) -> BackupFile {
        let account = AccountDTO(id: UUID(), name: "Nu", bank: .nu, kind: .credito, openingBalance: 0, creditLimit: 2_000_000,
                                 cutoffDay: 20, paymentDay: 5, last4: ["1234"], walletCardName: "Nu Mastercard",
                                 emailSenders: [], createdAt: at)
        let category = CategoryDTO(id: UUID(), name: "Mercado", icon: "cart", colorHex: "#2E7D32", isIncome: false, sortOrder: 0)
        let recurring = RecurringDTO(id: UUID(), name: "Arriendo", amount: 1_200_000, dayOfMonth: 5, accountID: account.id,
                                     method: .llave, categoryID: nil, active: true, remind: true)
        let occurrence = OccurrenceDTO(id: UUID(), recurringID: recurring.id, monthKey: "2026-10", dueDate: at,
                                       status: .pendiente, movementID: nil)
        let movement = MovementDTO(id: UUID(), amount: 50_000, date: at, kind: .gasto, method: .credito, accountID: account.id,
                                   destinationAccountID: nil, categoryID: category.id, merchant: "Éxito", note: nil,
                                   source: .applePay, status: .confirmado, rawText: nil, occurrenceID: nil)
        return BackupFile(formatVersion: version, exportedAt: at, accounts: [account], categories: [category],
                          movements: [movement], recurring: [recurring], occurrences: [occurrence])
    }

    func testRoundTrip() throws {
        let file = sample()
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode(file)), file)
    }

    func testRejectsOtherVersion() throws {
        let data = try BackupCodec.encode(sample(version: 99))
        XCTAssertThrowsError(try BackupCodec.decode(data)) { XCTAssertEqual($0 as? BackupError, .unsupportedVersion(99)) }
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try BackupCodec.decode(Data("no soy json".utf8))) { XCTAssertEqual($0 as? BackupError, .invalidFile) }
    }
}
