import Foundation

/// El resumen del extracto («Tu dinero al inicio del mes», «Lo que entró», …). Los montos van en **centavos**,
/// tal como los trae el banco, para que la continuidad cuadre al centavo.
public struct StatementSummary: Equatable, Sendable {
    public var opening: Int?
    public var income: Int?
    public var outflow: Int?
    public var tax: Int?
    public var withdrawalCosts: Int?
    public var yield: Int?
    public var closing: Int?
    /// Plata en las cajitas al final del período.
    public var pockets: Int?
    /// Último día del período, a las 23:59:59: ahí vale el saldo final.
    public var periodEnd: Date?

    public init(opening: Int? = nil, income: Int? = nil, outflow: Int? = nil, tax: Int? = nil, withdrawalCosts: Int? = nil,
                yield: Int? = nil, closing: Int? = nil, pockets: Int? = nil, periodEnd: Date? = nil) {
        self.opening = opening; self.income = income; self.outflow = outflow; self.tax = tax
        self.withdrawalCosts = withdrawalCosts; self.yield = yield; self.closing = closing; self.pockets = pockets
        self.periodEnd = periodEnd
    }

    /// Saldo final menos lo que da la cuenta (inicio + entró − salió + rendimientos − 4x1000 − costos), en pesos.
    /// 0 = cuadra. Positivo: entró plata que no está en la lista (por ejemplo, desde una cajita).
    public var continuityGap: Int? {
        guard let opening, let income, let outflow, let closing else { return nil }
        let computed = opening + income - outflow + (yield ?? 0) - (tax ?? 0) - (withdrawalCosts ?? 0)
        return Int((Double(closing - computed) / 100).rounded())
    }

    /// Centavos a pesos, descartando los centavos como en el resto de la app.
    public static func pesos(_ cents: Int?) -> Int? { cents.map { $0 / 100 } }
}

extension StatementParser {
    private static let periodEnd = try! NSRegularExpression(
        pattern: #"\b\d{1,2}\s*-\s*(\d{1,2})\s+(ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic)[a-z]*\.?\s+(\d{4})\b"#,
        options: [.caseInsensitive])

    /// Lee el resumen del extracto de Nu. Lo que no aparezca queda en nil.
    public static func summary(in text: String, calendar: Calendar) -> StatementSummary {
        StatementSummary(opening: cents(#"tu dinero al inicio del mes"#, in: text),
                         income: cents(#"lo que entr[oó] a tu cuenta"#, in: text),
                         outflow: cents(#"lo que sali[oó] de tu cuenta"#, in: text),
                         tax: cents(#"impuesto del 4\s?x\s?1\.?000"#, in: text),
                         withdrawalCosts: cents(#"costos? por retiros?"#, in: text),
                         yield: cents(#"rendimiento total de tu cuenta"#, in: text),
                         closing: cents(#"tu dinero a(?:l)? final del mes"#, in: text),
                         pockets: cents(#"dinero en tus cajitas"#, in: text),
                         periodEnd: endOfPeriod(in: text, calendar: calendar))
    }

    private static func cents(_ label: String, in text: String) -> Int? {
        let pattern = label + #"[\s\S]{0,40}?[-+−]?\s?\$\s?(\d{1,3}(?:\.\d{3})*|\d+)(?:,(\d{1,2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let pesos = Int(ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ".", with: "")) else { return nil }
        var decimals = m.range(at: 2).location == NSNotFound ? "00" : ns.substring(with: m.range(at: 2))
        if decimals.count == 1 { decimals += "0" }
        return pesos * 100 + (Int(decimals) ?? 0)
    }

    private static func endOfPeriod(in text: String, calendar: Calendar) -> Date? {
        let ns = text as NSString
        guard let m = periodEnd.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              let day = Int(ns.substring(with: m.range(at: 1))),
              let month = months[String(TextNormalizer.fold(ns.substring(with: m.range(at: 2))).prefix(3))],
              let year = Int(ns.substring(with: m.range(at: 3))) else { return nil }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = DateComponents(year: year, month: month, day: day, hour: 23, minute: 59, second: 59)
        guard let date = gregorian.date(from: parts), gregorian.component(.day, from: date) == day else { return nil }
        return date
    }
}

/// Lo que se lee en la pantalla de inicio de la app del banco: el saldo de la cuenta y, si se ve, el de las cajitas.
public struct HomeBalance: Equatable, Sendable {
    public let account: Int?
    public let pockets: Int?

    public init(account: Int?, pockets: Int?) {
        self.account = account
        self.pockets = pockets
    }
}

/// Lee el saldo en el texto (OCR) de una captura de la pantalla de inicio de Nu. Busca el monto que acompaña a
/// «Dinero disponible», «Dinero en tu cuenta», «Saldo disponible» o «Cuenta», en la misma línea o en las dos siguientes,
/// y el de «Cajitas». Lo leído siempre se muestra para corregirlo antes de guardarlo.
public enum HomeBalanceParser {
    static let accountLabels = ["dinero en tu cuenta", "dinero disponible", "saldo disponible", "disponible", "tu cuenta", "cuenta"]
    static let pocketLabels = ["dinero en tus cajitas", "en tus cajitas", "cajitas", "cajita"]
    private static let amount = try! NSRegularExpression(pattern: #"\$\s?(\d{1,3}(?:[.,]\d{3})+|\d+)(?:,\d{1,2})?"#)

    public static func parse(text: String) -> HomeBalance? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let account = value(after: accountLabels, in: lines, skipping: pocketLabels)
        let pockets = value(after: pocketLabels, in: lines, skipping: [])
        guard account != nil || pockets != nil else { return nil }
        return HomeBalance(account: account, pockets: pockets)
    }

    /// El primer monto en la línea del rótulo o en las dos siguientes. Las etiquetas se prueban en orden: la más
    /// precisa primero. Una línea que habla de cajitas no cuenta como rótulo de la cuenta.
    private static func value(after labels: [String], in lines: [String], skipping: [String]) -> Int? {
        let folded = lines.map { TextNormalizer.fold($0) }
        for label in labels {
            for (i, line) in folded.enumerated() where line.contains(label) && !skipping.contains(where: { line.contains($0) }) {
                for j in i..<min(i + 3, lines.count) {
                    if j > i, folded[j].contains("rendimiento") { break }
                    if let found = firstAmount(lines[j]) { return found }
                }
            }
        }
        return nil
    }

    private static func firstAmount(_ line: String) -> Int? {
        let ns = line as NSString
        guard let m = amount.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Int(ns.substring(with: m.range(at: 1)).filter(\.isNumber))
    }
}
