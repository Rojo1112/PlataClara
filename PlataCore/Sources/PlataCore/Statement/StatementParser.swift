import Foundation

public struct StatementEntry: Equatable, Sendable {
    public let date: Date
    public let description: String
    public let amount: Int
    public let kind: MovementKind
    public let balance: Int?
    /// true si el renglón trae hora real (capturas); si solo trae el día, vale 00:00 y se compara por día.
    public let hasTime: Bool

    public init(date: Date, description: String, amount: Int, kind: MovementKind, balance: Int?, hasTime: Bool = false) {
        self.date = date
        self.description = description
        self.amount = amount
        self.kind = kind
        self.balance = balance
        self.hasTime = hasTime
    }
}

/// Lee el texto de un extracto (PDF con texto, CSV o TXT). Entiende dos formas:
/// - **una línea por movimiento**: `04/10/2026 COMPRA EXITO -50.000,00 1.234.567,00` (o `01 sep Compra en X -$4.300,00`);
/// - **renglones separados**: la fecha, la descripción y el monto cada uno en su línea (así sale el PDF de Nu).
/// Un pago a la tarjeta de crédito se marca como transferencia, no como gasto.
public enum StatementParser {
    static let incomeWords = ["abono", "consignacion", "deposito", "intereses", "nomina", "reembolso", "devolucion", "ingreso"]
    static let months = ["ene": 1, "feb": 2, "mar": 3, "abr": 4, "may": 5, "jun": 6,
                         "jul": 7, "ago": 8, "sep": 9, "oct": 10, "nov": 11, "dic": 12]
    private static let monthNames = "ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic"

    private static let isoDate = try! NSRegularExpression(pattern: #"^\s*(\d{4})-(\d{2})-(\d{2})"#)
    private static let localDate = try! NSRegularExpression(pattern: #"^\s*(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?![\d/-])"#)
    private static let textDate = try! NSRegularExpression(
        pattern: #"^\s*(\d{1,2})\s+("# + monthNames + #")[a-z]*\.?(?:\s+(\d{4}))?(?![\w])"#, options: [.caseInsensitive])
    private static let wholeLineTextDate = try! NSRegularExpression(
        pattern: #"^(\d{1,2})\s+("# + monthNames + #")[a-z]*\.?(?:\s+(\d{4}))?$"#, options: [.caseInsensitive])
    private static let periodYear = try! NSRegularExpression(
        pattern: #"\b\d{1,2}\s*-\s*\d{1,2}\s+(?:"# + monthNames + #")[a-z]*\.?\s+(\d{4})\b"#, options: [.caseInsensitive])
    private static let pageMarker = try! NSRegularExpression(pattern: #"^\s*\d+\s*/\s*\d+\s*$"#)
    private static let amountOnly = try! NSRegularExpression(pattern: #"^([-+])?\s*\$?\s*(\d[\d.,]*)$"#)
    private static let amountToken = try! NSRegularExpression(pattern: #"(?<![\w.,/])[-+]?\(?\$?\s?\d[\d.,]*\)?-?(?![\w/])"#)

    public static func parse(text: String, calendar: Calendar, defaultYear: Int?) -> [StatementEntry] {
        let year = firstInt(periodYear, in: text) ?? defaultYear
        let lines = text.components(separatedBy: .newlines)
        let single = lines.compactMap { parseLine($0, calendar: calendar, defaultYear: year) }
        let stacked = parseStacked(lines: lines, calendar: calendar, year: year)
        let stream = parseStream(lines: lines, calendar: calendar, year: year)
        return [single, stacked, stream].reduce(single) { $1.count > $0.count ? $1 : $0 }
    }

    /// Totales que el propio extracto declara en su resumen («Lo que entró / salió de tu cuenta»).
    public static func declaredTotals(in text: String) -> StatementTotals {
        StatementTotals(income: declared(#"lo que entr[oó] a tu cuenta"#, in: text),
                        outflow: declared(#"lo que sali[oó] de tu cuenta"#, in: text))
    }

    private static func declared(_ label: String, in text: String) -> Int? {
        let pattern = label + #"[\s\S]{0,60}?[+-]?\s?\$\s?(\d{1,3}(?:\.\d{3})*|\d+)(?:,\d{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let digits = firstGroup(regex, in: text) else { return nil }
        return Int(digits.replacingOccurrences(of: ".", with: ""))
    }

    // MARK: una línea por movimiento

    private struct Token {
        let range: NSRange
        let text: String
        let value: Int
    }

    static func parseLine(_ raw: String, calendar: Calendar, defaultYear: Int?) -> StatementEntry? {
        let line = raw.replacingOccurrences(of: ";", with: " ").replacingOccurrences(of: "\t", with: " ")
        guard let lead = leadingDate(line, calendar: calendar, defaultYear: defaultYear) else { return nil }
        let rest = lead.rest
        let ns = rest as NSString

        let tokens: [Token] = amountToken.matches(in: rest, range: NSRange(location: 0, length: ns.length)).compactMap { match in
            let text = ns.substring(with: match.range)
            guard text.contains(where: { ".,$()+-".contains($0) }) else { return nil }
            let digits = text.filter { "0123456789.,".contains($0) }
            guard let value = AmountParser.normalize(digits) else { return nil }
            return Token(range: match.range, text: text, value: value)
        }
        guard let first = tokens.first, first.value > 0 else { return nil }

        let description = ns.substring(to: first.range.location).trimmingCharacters(in: CharacterSet(charactersIn: " -|"))
        let folded = TextNormalizer.fold(rest)
        var kind: MovementKind
        if first.text.contains("-") || first.text.contains("(") {
            kind = .gasto
        } else if first.text.hasPrefix("+") {
            kind = .ingreso
        } else if folded.range(of: #"\bcr\b"#, options: .regularExpression) != nil {
            kind = .ingreso
        } else if folded.range(of: #"\bdb\b"#, options: .regularExpression) != nil {
            kind = .gasto
        } else if incomeWords.contains(where: { folded.contains($0) }) {
            kind = .ingreso
        } else {
            kind = .gasto
        }
        kind = asTransferIfCardPayment(kind, description: description)
        return StatementEntry(date: lead.date, description: description, amount: first.value, kind: kind,
                              balance: tokens.dropFirst().first?.value)
    }

    // MARK: renglones separados

    static func parseStacked(lines: [String], calendar: Calendar, year: Int?) -> [StatementEntry] {
        var entries: [StatementEntry] = []
        var current: (date: Date, description: [String])?
        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if let match = wholeLineTextDate.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)),
               let date = makeDate(from: match, in: line, dayIndex: 1, monthIndex: 2, yearIndex: 3, calendar: calendar, defaultYear: year) {
                current = (date, [])
                continue
            }
            guard let open = current else { continue }
            if matches(pageMarker, line) { continue }
            if let amount = amountLine(line) {
                let description = open.description.joined(separator: " ")
                let folded = TextNormalizer.fold(description)
                var kind: MovementKind
                if amount.sign == "-" {
                    kind = .gasto
                } else if amount.sign == "+" {
                    kind = .ingreso
                } else {
                    kind = incomeWords.contains(where: { folded.contains($0) }) ? .ingreso : .gasto
                }
                kind = asTransferIfCardPayment(kind, description: description)
                entries.append(StatementEntry(date: open.date, description: description, amount: amount.value, kind: kind, balance: nil))
                current = nil
            } else {
                current = (open.date, open.description + [line])
            }
        }
        return entries
    }

    // MARK: flujo de texto (sin depender de cómo se parten las líneas)

    private static let streamDate = try! NSRegularExpression(
        pattern: #"(?<![\w/])(\d{1,2})\s+("# + monthNames + #")(?![a-zA-Z])\.?(?:\s+(\d{4}))?"#, options: [.caseInsensitive])
    private static let streamAmount = try! NSRegularExpression(
        pattern: #"(?<![\w.,])([-+])\s?\$\s?(\d{1,3}(?:\.\d{3})+|\d+)(?:,\d{1,2})?(?!\d)"#)

    /// Lee todo el texto como una secuencia «fecha, descripción, monto con signo y $», sin importar si
    /// el PDF partió cada fila en una, dos o tres líneas. Una descripción con `$` o muy larga es del
    /// resumen, no de un movimiento, y se descarta.
    static func parseStream(lines: [String], calendar: Calendar, year: Int?) -> [StatementEntry] {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !matches(pageMarker, $0) }
        let text = cleaned.joined(separator: "\n")
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        enum Item {
            case date(Date, end: Int)
            case amount(value: Int, sign: String, start: Int)
        }
        var items: [(position: Int, item: Item)] = []
        for m in streamDate.matches(in: text, range: full) {
            guard let date = makeDate(from: m, in: text, dayIndex: 1, monthIndex: 2, yearIndex: 3, calendar: calendar, defaultYear: year) else { continue }
            items.append((m.range.location, .date(date, end: m.range.location + m.range.length)))
        }
        for m in streamAmount.matches(in: text, range: full) {
            let sign = ns.substring(with: m.range(at: 1))
            let digits = ns.substring(with: m.range(at: 2)).replacingOccurrences(of: ".", with: "")
            guard let value = Int(digits), value > 0 else { continue }
            items.append((m.range.location, .amount(value: value, sign: sign, start: m.range.location)))
        }
        items.sort { $0.position < $1.position }

        var entries: [StatementEntry] = []
        var pending: (date: Date, end: Int)?
        for entry in items {
            switch entry.item {
            case .date(let date, let end):
                pending = (date, end)
            case .amount(let value, let sign, let start):
                guard let open = pending, start >= open.end else { continue }
                pending = nil
                let description = ns.substring(with: NSRange(location: open.end, length: start - open.end))
                    .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                    .trimmingCharacters(in: CharacterSet(charactersIn: " -|"))
                guard !description.contains("$"), description.count <= 140 else { continue }
                var kind: MovementKind = sign == "+" ? .ingreso : .gasto
                kind = asTransferIfCardPayment(kind, description: description)
                entries.append(StatementEntry(date: open.date, description: description, amount: value, kind: kind, balance: nil))
            }
        }
        return entries
    }

    /// Línea que es solo un monto: debe traer `$`, signo o separador (un "2026" suelto no cuenta).
    private static func amountLine(_ line: String) -> (value: Int, sign: Character?)? {
        let ns = line as NSString
        guard let m = amountOnly.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let signRange = m.range(at: 1)
        let sign: Character? = signRange.location == NSNotFound ? nil : ns.substring(with: signRange).first
        let digits = ns.substring(with: m.range(at: 2))
        guard line.contains("$") || sign != nil || digits.contains(".") || digits.contains(","),
              let value = AmountParser.normalize(digits), value > 0 else { return nil }
        return (value, sign)
    }

    private static func asTransferIfCardPayment(_ kind: MovementKind, description: String) -> MovementKind {
        kind == .gasto && MovementClassifier.classify(description).kind == .transferencia ? .transferencia : kind
    }

    // MARK: fechas

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    private static func firstGroup(_ regex: NSRegularExpression, in text: String) -> String? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return ns.substring(with: m.range(at: 1))
    }

    private static func firstInt(_ regex: NSRegularExpression, in text: String) -> Int? {
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return Int(ns.substring(with: m.range(at: 1)))
    }

    private static func makeDate(from match: NSTextCheckingResult, in line: String, dayIndex: Int, monthIndex: Int,
                                 yearIndex: Int, calendar: Calendar, defaultYear: Int?) -> Date? {
        let ns = line as NSString
        func text(_ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : ns.substring(with: range)
        }
        guard let day = text(dayIndex).flatMap({ Int($0) }),
              let monthText = text(monthIndex) else { return nil }
        let month = Int(monthText) ?? months[String(TextNormalizer.fold(monthText).prefix(3))]
        var year = text(yearIndex).flatMap { Int($0) }
        if let short = year, short < 100 { year = 2000 + short }
        guard let y = year ?? defaultYear, let mo = month else { return nil }
        return buildDate(year: y, month: mo, day: day, calendar: calendar)
    }

    private static func buildDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        // Siempre gregoriano: con el calendario japonés del teléfono, 2026 sería el año 2026 de la era Reiwa.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        guard let date = gregorian.date(from: components) else { return nil }
        let check = gregorian.dateComponents([.month, .day], from: date)
        return check.month == month && check.day == day ? date : nil
    }

    private static func leadingDate(_ line: String, calendar: Calendar, defaultYear: Int?) -> (date: Date, rest: String)? {
        let ns = line as NSString
        let full = NSRange(location: 0, length: ns.length)
        if let m = isoDate.firstMatch(in: line, range: full),
           let date = makeDate(from: m, in: line, dayIndex: 3, monthIndex: 2, yearIndex: 1, calendar: calendar, defaultYear: defaultYear) {
            return (date, ns.substring(from: m.range.location + m.range.length))
        }
        if let m = localDate.firstMatch(in: line, range: full),
           let date = makeDate(from: m, in: line, dayIndex: 1, monthIndex: 2, yearIndex: 3, calendar: calendar, defaultYear: defaultYear) {
            return (date, ns.substring(from: m.range.location + m.range.length))
        }
        if let m = textDate.firstMatch(in: line, range: full),
           let date = makeDate(from: m, in: line, dayIndex: 1, monthIndex: 2, yearIndex: 3, calendar: calendar, defaultYear: defaultYear) {
            return (date, ns.substring(from: m.range.location + m.range.length))
        }
        return nil
    }
}
