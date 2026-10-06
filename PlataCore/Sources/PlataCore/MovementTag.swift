import Foundation

/// Etiquetas que se guardan dentro de la nota del movimiento. Así viajan en el respaldo sin cambiar su formato.
public enum MovementTag: String, CaseIterable, Sendable {
    /// Nu apartó la plata pero todavía no la cobra (el reloj de la app): puede liberarse o cambiar de monto.
    case hold = "[Retención pendiente]"
    /// Plata que pasó por tu cuenta pero no es tuya (le pagaste a alguien por otra persona y te devolvió):
    /// cuenta en el saldo, no en gastos ni ingresos.
    case thirdParty = "[Plata de un tercero]"

    public var title: String {
        switch self {
        case .hold: return "Retención pendiente"
        case .thirdParty: return "Plata de un tercero"
        }
    }

    public static func has(_ tag: MovementTag, in note: String?) -> Bool {
        note?.contains(tag.rawValue) ?? false
    }

    /// La nota sin etiquetas, tal como la escribió la persona.
    public static func stripped(_ note: String?) -> String {
        var text = note ?? ""
        for tag in allCases { text = text.replacingOccurrences(of: tag.rawValue, with: "") }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nota final: las etiquetas activas y después el texto de la persona. Vacía si no hay nada.
    public static func compose(text: String, hold: Bool, thirdParty: Bool) -> String? {
        var parts: [String] = []
        if hold { parts.append(MovementTag.hold.rawValue) }
        if thirdParty { parts.append(MovementTag.thirdParty.rawValue) }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty { parts.append(clean) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
