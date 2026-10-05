import Foundation

extension Calendar {
    /// Calendario gregoriano con la zona horaria del teléfono, aunque el usuario tenga otro calendario
    /// (por ejemplo el japonés, donde 2026 se escribe «Reiwa 8»).
    static var gregoriano: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "es_CO")
        return calendar
    }
}

/// Fechas para mostrar: siempre en calendario gregoriano y en español.
enum Fecha {
    private static func texto(_ date: Date, _ patron: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = .gregoriano
        formatter.locale = Locale(identifier: "es_CO")
        formatter.timeZone = .current
        formatter.dateFormat = patron
        return formatter.string(from: date)
    }

    static func dia(_ date: Date) -> String { texto(date, "d MMM yyyy") }
    static func diaHora(_ date: Date) -> String { texto(date, "d MMM yyyy, HH:mm") }
    static func diaMes(_ date: Date) -> String { texto(date, "d MMM") }
    static func mesAnio(_ date: Date) -> String { texto(date, "LLLL yyyy") }
    static func mesCorto(_ date: Date) -> String { texto(date, "LLL") }
}
