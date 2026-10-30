import Foundation

/// Lee el texto (OCR) de capturas de pantalla de la lista de movimientos de la app del banco.
/// Entiende dos formas:
/// - **con fecha**: `Pagaste en TIENDA -$25.000,00` y debajo `05 mar - 11:59`;
/// - **con encabezado de día**: `Hoy` / `Sábado` y cada movimiento con su hora (así sale la tarjeta de crédito de Nu).
/// Lo tachado o con reloj en la app no se distingue en el texto: se revisa a mano antes de importar.
/// Lo que se guarda en una cajita o se saca de ella sale como transferencia, no como gasto ni ingreso.
public enum ScreenshotParser {
    // «0ct»: el OCR a veces lee la «o» de «oct» como un cero.
    private static let monthNames = "ene|feb|mar|abr|may|jun|jul|ago|sept|sep|oct|0ct|nov|dic"
    private static let dateTime = try! NSRegularExpression(
        pattern: #"(\d{1,2})\s+("# + monthNames + #")[a-z]*\.?\s*[-–·]?\s*(\d{1,2}):(\d{2})"#, options: [.caseInsensitive])
    private static let timeOnly = try! NSRegularExpression(pattern: #"^(\d{1,2}):(\d{2})$"#)
    private static let amount = try! NSRegularExpression(pattern: #"([-+−–])?\s*\$\s*(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,](\d{2}))?"#)
    private static let installments = try! NSRegularExpression(pattern: #"\ba\s+\d+\s+mes(?:es)?\b"#, options: [.caseInsensitive])
    private static let noise = try! NSRegularExpression(
        pattern: #"^(?:(?:[\d:%\s]|[2-5]G|LTE|Wi-?Fi)+|buscar movimiento|movimientos)$"#, options: [.caseInsensitive])
    private static let weekdays = ["domingo": 1, "lunes": 2, "martes": 3, "miercoles": 4, "jueves": 5, "viernes": 6, "sabado": 7]

    /// Línea que separa el texto de una captura del de la siguiente.
    public static let pageBreak = "<<<captura>>>"

    public static func parse(text: String, now: Date, calendar: Calendar) -> [StatementEntry] {
        var pages: [[StatementEntry]] = [[]]
        var day: Date?
        var pre: String?
        var desc: [String] = []
        var value: Int?
        var sign: Character?
        /// La fila pendiente viene de la captura anterior (quedó partida en el borde).
        var carried = false

        func flush(_ date: Date?) {
            defer { desc = []; value = nil; sign = nil; carried = false }
            guard let amountValue = value, amountValue > 0 else { return }
            let description = clean(desc.joined(separator: " "))
            guard !description.isEmpty else { return }
            // Sin hora propia ni encabezado de día es una fila cortada al borde de la captura: se descarta.
            guard date != nil || day != nil else { return }
            let when = date ?? day ?? calendar.startOfDay(for: now)
            let pocket = MovementClassifier.pocketDirection(description, sign: sign)
            pages[pages.count - 1].append(StatementEntry(date: when, description: description, amount: amountValue,
                                                         kind: pocket != nil ? .transferencia : kind(of: description, sign: sign),
                                                         balance: nil, hasTime: date != nil, pocket: pocket))
        }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line == pageBreak {
                // Una fila con monto pero sin fecha al final de la captura quedó partida: si la siguiente captura
                // empieza con su fecha, se completa; si empieza con un monto, la fila se repite entera y esta se descarta.
                if value == nil || day != nil { flush(nil) } else { carried = true }
                pre = nil
                pages.append([])
                continue
            }
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
                // Con una fila partida pendiente, una hora suelta es la del reloj del teléfono, no la del movimiento.
                if value != nil, !carried {
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
                // Los montos se guardan en pesos: los centavos se redondean (0,87 → 1), no se cortan.
                let cents = match.range(at: 3).location == NSNotFound ? 0 : Int(ns.substring(with: match.range(at: 3))) ?? 0
                let signText = match.range(at: 1).location == NSNotFound ? nil : ns.substring(with: match.range(at: 1))
                sign = signText.map { $0 == "+" ? Character("+") : Character("-") }
                value = parsed + (cents >= 50 ? 1 : 0)
                let rest = ns.replacingCharacters(in: match.range, with: "").trimmingCharacters(in: CharacterSet(charactersIn: " -|·"))
                if desc.isEmpty, let previous = pre, TextNormalizer.fold(previous).contains("gracias") { desc.append(previous) }
                pre = nil
                if !rest.isEmpty { desc.append(rest) }
                continue
            }
            if value != nil { desc.append(withoutInstallments) } else { pre = withoutInstallments }
        }
        flush(nil)
        return merge(pages)
    }

    /// Une las capturas quitando lo que se repite donde se solapan. Una fila con igual fecha, monto y tipo que otra
    /// de una captura anterior es la misma, salvo que la fila de debajo lo desmienta: si las dos tienen fila justo
    /// debajo, es distinta y tampoco comparten ninguna fila cercana (dos arriba y dos abajo), son dos movimientos
    /// iguales en el mismo minuto y se dejan los dos. La fila de arriba no cuenta: en el solape suele quedar cortada.
    /// Una fila que el OCR se salte en una de las capturas no basta para duplicar: las cercanas siguen coincidiendo.
    static func merge(_ pages: [[StatementEntry]]) -> [StatementEntry] {
        struct Context { let below: String?; let nearby: Set<String> }
        func key(_ entry: StatementEntry) -> String { "\(entry.date.timeIntervalSince1970)|\(entry.amount)|\(entry.kind.rawValue)" }
        func isSame(_ a: Context, _ b: Context) -> Bool {
            !a.nearby.isDisjoint(with: b.nearby) || a.below == nil || b.below == nil || a.below == b.below
        }

        var result: [StatementEntry] = []
        var seen: [String: [Context]] = [:]
        for page in pages {
            let keys = page.map(key)
            var found: [(String, Context)] = []
            for (index, entry) in page.enumerated() {
                let window = keys[max(0, index - 2)..<min(keys.count, index + 3)]
                let here = Context(below: index + 1 < keys.count ? keys[index + 1] : nil,
                                   nearby: Set(window).subtracting([keys[index]]))
                if !seen[keys[index], default: []].contains(where: { isSame($0, here) }) { result.append(entry) }
                found.append((keys[index], here))
            }
            // Las de esta captura se comparan solo con las siguientes: dentro de una misma captura nada se repite.
            for (k, context) in found { seen[k, default: []].append(context) }
        }
        return result
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
              let day = Int(g[0]),
              let month = StatementParser.months[String(g[1].lowercased().replacingOccurrences(of: "0", with: "o").prefix(3))],
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
