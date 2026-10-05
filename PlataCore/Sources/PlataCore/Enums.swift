import Foundation

public enum Bank: String, Codable, CaseIterable, Sendable, Identifiable {
    case nu, dale, uala, lulo, efectivo, otro
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .nu: return "Nu"
        case .dale: return "Dale!"
        case .uala: return "Ualá"
        case .lulo: return "Lulo Bank"
        case .efectivo: return "Efectivo"
        case .otro: return "Otro"
        }
    }
}

public enum AccountKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case ahorros, credito
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .ahorros: return "Cuenta de ahorros"
        case .credito: return "Tarjeta de crédito"
        }
    }
}

public enum MovementKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case gasto, ingreso, transferencia
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .gasto: return "Gasto"
        case .ingreso: return "Ingreso"
        case .transferencia: return "Transferencia"
        }
    }
}

public enum PaymentMethod: String, Codable, CaseIterable, Sendable, Identifiable {
    case debito, credito, qr, llave, transferencia, efectivo
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .debito: return "Tarjeta débito"
        case .credito: return "Tarjeta crédito"
        case .qr: return "QR"
        case .llave: return "Llave Bre-B"
        case .transferencia: return "Transferencia"
        case .efectivo: return "Efectivo"
        }
    }
}

public enum CaptureSource: String, Codable, CaseIterable, Sendable, Identifiable {
    case manual, correo, applePay, captura, fijo, extracto
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .correo: return "Correo"
        case .applePay: return "Apple Pay"
        case .captura: return "Captura"
        case .fijo: return "Gasto fijo"
        case .extracto: return "Extracto"
        }
    }
}

public enum MovementStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case confirmado, porRevisar
    public var id: String { rawValue }
    public var displayName: String { self == .confirmado ? "Confirmado" : "Por revisar" }
}

public enum OccurrenceStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case pendiente, pagado, omitido
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .pendiente: return "Pendiente"
        case .pagado: return "Pagado"
        case .omitido: return "Omitido"
        }
    }
}
