import Foundation

public struct AccountSnapshot: Equatable, Sendable {
    public let id: UUID
    public let kind: AccountKind
    public let openingBalance: Int

    public init(id: UUID = UUID(), kind: AccountKind, openingBalance: Int) {
        self.id = id
        self.kind = kind
        self.openingBalance = openingBalance
    }
}

public struct MovementSnapshot: Equatable, Sendable {
    public let id: UUID
    public let amount: Int
    public let date: Date
    public let kind: MovementKind
    public let method: PaymentMethod
    public let accountID: UUID?
    public let destinationAccountID: UUID?
    public let categoryName: String?
    public let status: MovementStatus
    /// Ingreso que es la devolución de un gasto: resta del gasto en las estadísticas.
    public let isRefund: Bool
    public let merchant: String?
    /// Plata de un tercero: cuenta en el saldo pero no en gastos ni ingresos.
    public let isExternal: Bool

    public init(id: UUID = UUID(), amount: Int, date: Date, kind: MovementKind, method: PaymentMethod,
                accountID: UUID?, destinationAccountID: UUID? = nil, categoryName: String? = nil,
                status: MovementStatus = .confirmado, isRefund: Bool = false, merchant: String? = nil, isExternal: Bool = false) {
        self.id = id
        self.amount = amount
        self.date = date
        self.kind = kind
        self.method = method
        self.accountID = accountID
        self.destinationAccountID = destinationAccountID
        self.categoryName = categoryName
        self.status = status
        self.isRefund = isRefund
        self.merchant = merchant
        self.isExternal = isExternal
    }
}
