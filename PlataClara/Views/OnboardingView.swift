import SwiftUI
import SwiftData
import AppIntents
import PlataCore

/// Recorrido de primera vez. Se puede omitir en cualquier paso y volver a verlo desde Ajustes.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("onboardingDone") private var onboardingDone = false
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @State private var step = 0
    @State private var addingAccount = false

    private let lastStep = 4

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    welcome.tag(0)
                    accountsStep.tag(1)
                    capture.tag(2)
                    shortcuts.tag(3)
                    done.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    if step > 0 {
                        Button("Atrás") { withAnimation { step -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    Button(step == lastStep ? "Empezar" : "Siguiente") {
                        if step == lastStep { finish() } else { withAnimation { step += 1 } }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if step < lastStep {
                        Button("Omitir tutorial", action: finish)
                    }
                }
            }
            .sheet(isPresented: $addingAccount) { AccountFormView(account: nil) }
        }
        .interactiveDismissDisabled()
    }

    private func finish() {
        onboardingDone = true
        dismiss()
    }

    private func page(icon: String, title: String, text: String, @ViewBuilder extra: () -> some View) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if icon == "logo" {
                    LogoMark(size: 104).padding(.top, 24)
                } else {
                    Image(systemName: icon).font(.system(size: 56)).foregroundStyle(Color.accentColor).padding(.top, 24)
                }
                Text(title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
                extra()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    private var welcome: some View {
        page(icon: "logo", title: "Tu plata, clara",
             text: "PlataClara te dice cuánto te entró, cuánto te salió y si gastaste más de lo que ingresó. Todo se guarda en tu iPhone.") { EmptyView() }
    }

    private var accountsStep: some View {
        page(icon: "creditcard.fill", title: "Agrega tus cuentas",
             text: "Elige el banco y el tipo con un menú. Pon lo que tienes hoy en cada una. Puedes agregar más después en Ajustes › Cuentas.") {
            VStack(spacing: 8) {
                ForEach(accounts) { account in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text(account.name)
                        Spacer()
                        Text(account.bank.displayName).foregroundStyle(.secondary).font(.caption)
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
                Button { addingAccount = true } label: {
                    Label(accounts.isEmpty ? "Agregar mi primera cuenta" : "Agregar otra cuenta", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var capture: some View {
        page(icon: "square.and.arrow.down.fill", title: "Cómo entran tus movimientos",
             text: "Sin tener que escribir cada uno:") {
            VStack(alignment: .leading, spacing: 14) {
                bullet("doc.text.magnifyingglass", "Extracto en PDF", "Con o sin contraseña. Ajustes › Importar extracto.")
                bullet("photo.on.rectangle", "Capturas de la app del banco", "Elige hasta 10. Si repites una, no se duplica.")
                bullet("applewatch.and.arrow.forward", "Apple Pay, QR y envíos", "Con los atajos del siguiente paso.")
                bullet("square.and.pencil", "A mano", "Siempre disponible con el botón +.")
            }
        }
    }

    private var shortcuts: some View {
        page(icon: "bolt.fill", title: "Atajos listos",
             text: "Registrar pagos con tarjeta o QR, envíos y entradas de otras cuentas ya viene dentro de la app. Aparecen solos en la app Atajos.") {
            VStack(spacing: 12) {
                ShortcutsLink().shortcutsLinkStyle(.automaticOutline)
                Text("Lo que registren no se duplica si después subes una captura o un extracto: se completa con los datos del banco. Los verás todos en Ajustes › Todos los atajos.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    private var done: some View {
        page(icon: "checkmark.seal.fill", title: "Todo listo",
             text: accounts.isEmpty
                ? "Todavía no agregaste cuentas. Puedes hacerlo en Ajustes › Cuentas cuando quieras."
                : "Ya puedes importar tu primer extracto o capturas. Pon la cuenta con el saldo con el que empezó el mes que vas a subir.") { EmptyView() }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 28).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
