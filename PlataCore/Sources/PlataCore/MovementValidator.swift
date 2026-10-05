import Foundation

public enum MovementValidationError: Error, Equatable, Hashable, Sendable {
    case montoInvalido, faltaCuenta, faltaDestino, mismaCuenta

    public var message: String {
        switch self {
        case .montoInvalido: return "El monto debe ser mayor que cero."
        case .faltaCuenta: return "Elige la cuenta."
        case .faltaDestino: return "Elige la cuenta de destino."
        case .mismaCuenta: return "La cuenta de origen y la de destino deben ser distintas."
        }
    }
}

public enum MovementValidator {
    public static func validate(amount: Int, kind: MovementKind, accountID: UUID?,
                                destinationAccountID: UUID?) -> [MovementValidationError] {
        var errors: [MovementValidationError] = []
        if amount <= 0 { errors.append(.montoInvalido) }
        if accountID == nil { errors.append(.faltaCuenta) }
        if kind == .transferencia {
            if destinationAccountID == nil {
                errors.append(.faltaDestino)
            } else if destinationAccountID == accountID {
                errors.append(.mismaCuenta)
            }
        }
        return errors
    }
}
