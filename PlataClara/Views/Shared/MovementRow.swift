import SwiftUI
import PlataCore

struct MovementRow: View {
    let movement: Movement
    let accounts: [Account]
    let categories: [Category]

    var body: some View {
        let category = categories.first { $0.id == movement.categoryID }
        let account = accounts.first { $0.id == movement.accountID }
        HStack(spacing: 12) {
            Image(systemName: category?.icon ?? fallbackIcon)
                .frame(width: 28)
                .foregroundStyle(category.map { Color(hex: $0.colorHex) } ?? Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(movement.merchant ?? category?.name ?? movement.kind.displayName).lineLimit(1)
                Text("\(movement.method.displayName) · \(account?.name ?? "Sin cuenta") · \(Fecha.diaHora(movement.date))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if !movement.tagTitles.isEmpty {
                    Text(movement.tagTitles.joined(separator: " · "))
                        .font(.caption2.weight(.semibold)).foregroundStyle(.orange).lineLimit(1)
                }
            }
            Spacer()
            Text(signedAmount).monospacedDigit().foregroundStyle(amountColor)
        }
    }

    private var fallbackIcon: String {
        switch movement.method {
        case .qr: return "qrcode"
        case .llave: return "key"
        case .credito, .debito: return "creditcard"
        case .transferencia: return "arrow.left.arrow.right"
        case .efectivo: return "banknote"
        }
    }

    private var signedAmount: String {
        switch movement.kind {
        case .ingreso: return "+" + Money.format(movement.amount)
        case .gasto: return "-" + Money.format(movement.amount)
        case .transferencia: return Money.format(movement.amount)
        }
    }

    private var amountColor: Color {
        switch movement.kind {
        case .ingreso: return .green
        case .gasto: return .primary
        case .transferencia: return .secondary
        }
    }
}
