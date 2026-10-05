import Foundation

/// Lee el texto (OCR) de capturas de pantalla de la lista de movimientos de la app del banco.
/// Entiende dos formas:
/// - **con fecha**: `Pagaste en NEQUI -$88.000,00` y debajo `05 oct - 11:59`;
/// - **con encabezado de día**: `Hoy` / `Sábado` y cada movimiento con su hora (así sale la tarjeta de crédito de Nu).
/// Lo tachado o con reloj en la app no se distingue en el texto: se revisa a mano antes de importar.
public enum ScreenshotParser {
    private static let monthNames = "ene|feb|mar|abr|may|jun|jul|ago|sept|sep|oct|nov|dic"
    private static let dateTime = try! NSRegularExpression(
        pattern: #"(\d{1,2})\s+("# + monthNames + #")[a-z]*\.?\s*[-–·]?\s*(\d{1,2}):(\d{2})"#, options: [.caseInsensitive])
    private static let timeOnly = try! NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})$"#)
    private static let amount = try! NSRegularExpression(pattern: #"([-+−–])?\s*\$\s*(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d{2})?"#)
    private static let installments = try! NSRegularExpression(pattern: #"\ba\s+\d+\s+mes(?:es)?\b"#, options: [.caseInsensitive])
    private static let noise = try! NSRegularExpression(
        pattern: #"^(?:(?:[\d:%\s]|[2-5]G|LTE|Wi-?Fi)+|buscar movimiento|movimientos)$"#, options: [.caseInsensitive])
    private static let weekdays = ["domingo": 1, "lunes": 2, "martes": 3, "miercoles": 4, "jueves": 5, "viernes": 6, "sabado": 7]

    /// Línea que separa el texto de una captura del de la siguiente.
    public static let pageBreak = "<<<captura>>>"

    public static func parse(text: String, now: Date, calendar: Calendar) -> [StatementEntry] {
        var entries: [StatementEntry] = []
        var day: Date?
        var pre: String?
        var desc: [String] = []
        var value: Int?
        var sign: Character?

        func flush(_ date: Date?) {
            defer { desc = []; value = nil; sign = nil }
            guard let amountValue = value, amountValue > 0 else { return }
            let description = clean(desc.joined(separator: " "))
            guard !description.isEmpty else { return }
            // Sin hora propia ni encabezado de día es una fila cortada al borde de la captura: se descarta.
            guard date != nil || day != nil else { return }
            let when = date ?? day.flatMap { calendar.date(byAdding: .hour, value: 12, to: $0) } ?? now
            entries.append(StatementEntry(date: when, description: description, amount: amountValue,
                                          kind: kind(of: description, sign: sign), balance: nil))
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line == pageBreak { flush(nil); pre = nil; continue }
            if TextNormalizer.fold(line).contains("buscar movimiento") { continue }

            if let header = dayHeader(TextNormalizer.fold(line), now: now, calendar: calendar) {
                flush(nil); pre = nil; day = header
                continue
            }
            if let stamp = stampedDate(line, now: now, calendar: calendar) {
                flush(stamp); pre = nil
                continue
            }
            if let time = firstGroups(timeOnly, in: line), let h = Int(time[0]), let m = Int(time[1]) {
                if value != nil {
                    let base = day ?? calendar.startOfDay(for: now)
                    flush(calendar.date(bySettingHour: h, minute: m, second: 0, of: base))
                }
                continue
            }
            let withoutInstallments = installments.stringByReplacing(in: line, with: "").trimmingCharacters(in: .whitespaces)
            if withoutInstallments.isEmpty || matches(noise, withoutInstallments, whole: true) { continue }

            let ns = withoutInstallments as NSString
            if let match = amount.firstMatch(in: withoutInstallments, range: NSRange(location: 0, length: ns.length)) {
                if value != nil { flush(nil) }
                let digits = ns.substring(with: match.range(at: 2)).filter { $0.isNumber }
                guard let parsed = Int(digits) else { continue }
                let signText = match.range(at: 1).location == NSNotFound ? nil : ns.substring(with: match.range(at: 1))
                sign = signText.map { $0 == "+" ? Character("+") : Character("-") }
                value = parsed
                let rest = ns.replacingCharacters(in: match.range, with: "").trimmingCharacters(in: CharacterSet(charactersIn: " -|·"))
                if desc.isEmpty, let previous = pre, TextNormalizer.fold(previous).contains("gracias") { desc.append(previous) }
                pre = nil
                if !rest.isEmpty { desc.append(rest) }
                continue
            }
            if value != nil { desc.append(withoutInstallments) } else { pre = withoutInstallments }
        }
        flush(nil)

        var seen = Set<String>()
        return entries.filter { entry in
            let key = "\(entry.date.timeIntervalSince1970)|\(entry.amount)|\(entry.kind.rawValue)"
            return seen.insert(key).inserted
        }
    }

    private static func kind(of description: String, sign: Character?) -> MovementKind {
        let folded = TextNormalizer.fold(description)
        var kind: MovementKind = sign == "+" ? .ingreso : .gasto
        if sign != "-" && MovementClassifier.isRefund(description) {
            kind = .ingreso
        } else if sign != "+" && (folded.contains("gracias por tu pago") || MovementClassifier.classify(description).kind == .transferencia) {
            kind = .transferencia
        }
        return kind
    }

    private static func clean(_ text: String) -> String {
        let withoutInstallments = installments.stringByReplacing(in: text, with: "")
        let collapsed = withoutInstallments.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " -|·"))
    }

    private static func dayHeader(_ folded: String, now: Date, calendar: Calendar) -> Date? {
        let word = folded.trimmingCharacters(in: CharacterSet.letters.inverted)
        let today = calendar.startOfDay(for: now)
        if word == "hoy" { return today }
        if word == "ayer" { return calendar.date(byAdding: .day, value: -1, to: today) }
        guard let target = weekdays[word] else { return nil }
        for back in 1...7 {
            if let candidate = calendar.date(byAdding: .day, value: -back, to: today),
               calendar.component(.weekday, from: candidate) == target { return candidate }
        }
        return nil
    }

    private static func stampedDate(_ line: String, now: Date, calendar: Calendar) -> Date? {
        guard let g = firstGroups(dateTime, in: line), g.count == 4,
              let day = Int(g[0]), let month = StatementParser.months[String(g[1].lowercased().prefix(3))],
              let hour = Int(g[2]), let minute = Int(g[3]) else { return nil }
        var parts = DateComponents(year: calendar.component(.year, from: now), month: month, day: day, hour: hour, minute: minute)
        guard var date = calendar.date(from: parts) else { return nil }
        if date > now.addingTimeInterval(86_400) {
            parts.year = (parts.year ?? 0) - 1
            date = calendar.date(from: parts) ?? date
        }
        return date
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String, whole: Bool) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, range: range) else { return false }
        return !whole || match.range == range
    }

    private static func firstGroups(_ regex: NSRegularExpression, in text: String) -> [String]? {
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (1..<match.numberOfRanges).map { ns.substring(with: match.range(at: $0)) }
    }
}

private extension NSRegularExpression {
    func stringByReplacing(in text: String, with replacement: String) -> String {
        stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: replacement)
    }
}
