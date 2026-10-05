import Foundation
import SwiftData
import PlataCore

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var bankRaw: String = Bank.otro.rawValue
    var kindRaw: String = AccountKind.ahorros.rawValue
    var openingBalance: Int = 0
    var creditLimit: Int?
    var cutoffDay: Int?
    var paymentDay: Int?
    var last4Raw: String = ""
    var walletCardName: String?
    var emailSendersRaw: String = ""
    var createdAt: Date = Date()

    init(name: String, bank: Bank, kind: AccountKind, openingBalance: Int) {
        self.name = name
        self.bankRaw = bank.rawValue
        self.kindRaw = kind.rawValue
        self.openingBalance = openingBalance
    }

    var bank: Bank {
        get { Bank(rawValue: bankRaw) ?? .otro }
        set { bankRaw = newValue.rawValue }
    }

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .ahorros }
        set { kindRaw = newValue.rawValue }
    }

    var last4: [String] {
        get { Account.splitList(last4Raw) }
        set { last4Raw = newValue.joined(separator: ",") }
    }

    var emailSenders: [String] {
        get { Account.splitList(emailSendersRaw) }
        set { emailSendersRaw = newValue.joined(separator: ",") }
    }

    var snapshot: AccountSnapshot { AccountSnapshot(id: id, kind: kind, openingBalance: openingBalance) }

    var hint: AccountHint {
        AccountHint(id: id, bank: bank, kind: kind, last4: last4, walletCardName: walletCardName, emailSenders: emailSenders)
    }

    static func splitList(_ raw: String) -> [String] {
        raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
