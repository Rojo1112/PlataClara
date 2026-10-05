import Foundation

public struct AccountDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var bank: Bank
    public var kind: AccountKind
    public var openingBalance: Int
    public var creditLimit: Int?
    public var cutoffDay: Int?
    public var paymentDay: Int?
    public var last4: [String]
    public var walletCardName: String?
    public var emailSenders: [String]
    public var createdAt: Date

    public init(id: UUID, name: String, bank: Bank, kind: AccountKind, openingBalance: Int, creditLimit: Int?,
                cutoffDay: Int?, paymentDay: Int?, last4: [String], walletCardName: String?, emailSenders: [String],
                createdAt: Date) {
        self.id = id; self.name = name; self.bank = bank; self.kind = kind; self.openingBalance = openingBalance
        self.creditLimit = creditLimit; self.cutoffDay = cutoffDay; self.paymentDay = paymentDay; self.last4 = last4
        self.walletCardName = walletCardName; self.emailSenders = emailSenders; self.createdAt = createdAt
    }
}

public struct CategoryDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var colorHex: String
    public var isIncome: Bool
    public var sortOrder: Int

    public init(id: UUID, name: String, icon: String, colorHex: String, isIncome: Bool, sortOrder: Int) {
        self.id = id; self.name = name; self.icon = icon; self.colorHex = colorHex; self.isIncome = isIncome
        self.sortOrder = sortOrder
    }
}

public struct MovementDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var amount: Int
    public var date: Date
    public var kind: MovementKind
    public var method: PaymentMethod
    public var accountID: UUID?
    public var destinationAccountID: UUID?
    public var categoryID: UUID?
    public var merchant: String?
    public var note: String?
    public var source: CaptureSource
    public var status: MovementStatus
    public var rawText: String?
    public var occurrenceID: UUID?

    public init(id: UUID, amount: Int, date: Date, kind: MovementKind, method: PaymentMethod, accountID: UUID?,
                destinationAccountID: UUID?, categoryID: UUID?, merchant: String?, note: String?, source: CaptureSource,
                status: MovementStatus, rawText: String?, occurrenceID: UUID?) {
        self.id = id; self.amount = amount; self.date = date; self.kind = kind; self.method = method
        self.accountID = accountID; self.destinationAccountID = destinationAccountID; self.categoryID = categoryID
        self.merchant = merchant; self.note = note; self.source = source; self.status = status; self.rawText = rawText
        self.occurrenceID = occurrenceID
    }
}

public struct RecurringDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var amount: Int
    public var dayOfMonth: Int
    public var accountID: UUID?
    public var method: PaymentMethod
    public var categoryID: UUID?
    public var active: Bool
    public var remind: Bool

    public init(id: UUID, name: String, amount: Int, dayOfMonth: Int, accountID: UUID?, method: PaymentMethod,
                categoryID: UUID?, active: Bool, remind: Bool) {
        self.id = id; self.name = name; self.amount = amount; self.dayOfMonth = dayOfMonth; self.accountID = accountID
        self.method = method; self.categoryID = categoryID; self.active = active; self.remind = remind
    }
}

public struct OccurrenceDTO: Codable, Equatable, Sendable {
    public var id: UUID
    public var recurringID: UUID
    public var monthKey: String
    public var dueDate: Date
    public var status: OccurrenceStatus
    public var movementID: UUID?

    public init(id: UUID, recurringID: UUID, monthKey: String, dueDate: Date, status: OccurrenceStatus, movementID: UUID?) {
        self.id = id; self.recurringID = recurringID; self.monthKey = monthKey; self.dueDate = dueDate
        self.status = status; self.movementID = movementID
    }
}

public struct BackupFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var accounts: [AccountDTO]
    public var categories: [CategoryDTO]
    public var movements: [MovementDTO]
    public var recurring: [RecurringDTO]
    public var occurrences: [OccurrenceDTO]

    public init(formatVersion: Int = BackupFile.currentVersion, exportedAt: Date, accounts: [AccountDTO],
                categories: [CategoryDTO], movements: [MovementDTO], recurring: [RecurringDTO], occurrences: [OccurrenceDTO]) {
        self.formatVersion = formatVersion; self.exportedAt = exportedAt; self.accounts = accounts
        self.categories = categories; self.movements = movements; self.recurring = recurring; self.occurrences = occurrences
    }
}

public enum BackupError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidFile
}

public enum BackupCodec {
    public static func encode(_ file: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    public static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
        guard file.formatVersion == BackupFile.currentVersion else { throw BackupError.unsupportedVersion(file.formatVersion) }
        return file
    }
}
