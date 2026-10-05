import SwiftUI
import PlataCore

/// Campo de pesos: solo dígitos, se muestra como "$ 12.345".
struct AmountField: View {
    let title: String
    @Binding var value: Int
    @State private var text = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("$ 0", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .onAppear { text = display(value) }
        .onChange(of: text) { _, newText in
            let digits = newText.filter(\.isNumber)
            let parsed = Int(digits) ?? 0
            if parsed != value { value = parsed }
            let formatted = digits.isEmpty ? "" : Money.format(parsed)
            if formatted != newText { text = formatted }
        }
        .onChange(of: value) { _, newValue in
            if (Int(text.filter(\.isNumber)) ?? 0) != newValue { text = display(newValue) }
        }
    }

    private func display(_ amount: Int) -> String { amount == 0 ? "" : Money.format(amount) }
}
