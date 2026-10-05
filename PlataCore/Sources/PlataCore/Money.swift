import Foundation

public enum Money {
    /// Formatea pesos colombianos: 1234567 -> "$ 1.234.567"; -5000 -> "-$ 5.000".
    public static func format(_ amount: Int) -> String {
        let digits = String(amount.magnitude)
        var groups: [String] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -3, limitedBy: digits.startIndex) ?? digits.startIndex
            groups.insert(String(digits[start..<end]), at: 0)
            end = start
        }
        return (amount < 0 ? "-" : "") + "$ " + groups.joined(separator: ".")
    }
}
