import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import PlataCore

struct StatementImportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]

    @State private var accountID: UUID?
    @State private var importing = false
    @State private var rawText = ""
    @State private var entries: [StatementEntry] = []
    @State private var duplicates: Set<Int> = []
    @State private var selected: Set<Int> = []
    @State private var document: PDFDocument?
    @State private var needsPassword = false
    @State private var password = ""
    @State private var readingImage = false
    @State private var usedOCR = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Picker("Cuenta del extracto", selection: $accountID) {
                    Text("Elegir…").tag(UUID?.none)
                    ForEach(accounts) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Button("Elegir archivo del extracto…") { importing = true }
                    .disabled(accountID == nil || readingImage)
                    .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .commaSeparatedText, .plainText]) { result in
                        if case .success(let url) = result { load(url) } else { message = "No se pudo abrir el archivo." }
                    }
            } footer: {
                Text("Sirve con PDF del banco (con o sin contraseña), CSV o TXT. Si el PDF tiene la copia de texto bloqueada o es una imagen, la app lee la imagen de cada página en tu iPhone. Nada sale del teléfono.")
            }

            if needsPassword {
                Section("El PDF tiene contraseña") {
                    SecureField("Contraseña (en Nu suele ser tu cédula)", text: $password)
                    Button("Desbloquear", action: unlock)
                }
            }

            if readingImage {
                Section { HStack { ProgressView(); Text("  Leyendo la imagen del PDF…") } }
            }

            if document != nil, !needsPassword, !readingImage, !entries.isEmpty, !usedOCR {
                Section {
                    Button("¿No coinciden los totales? Releer como imagen (OCR)", action: readImage)
                }
            }

            if !entries.isEmpty {
                Section {
                    LabeledContent("Entradas seleccionadas", value: Money.format(total(of: .ingreso)))
                    LabeledContent("Salidas seleccionadas", value: Money.format(total(of: .gasto)))
                    LabeledContent("Pagos a tarjeta", value: Money.format(total(of: .transferencia)))
                } header: {
                    Text("Compáralo con el resumen del extracto")
                } footer: {
                    Text(usedOCR
                         ? "Se leyó la imagen del PDF (OCR): revisa que cada monto esté bien antes de importar. Si estos totales no coinciden con los del extracto, desmarca o corrige lo que falle."
                         : "Si estos totales coinciden con «lo que entró» y «lo que salió» del extracto, la lectura es correcta.")
                }

                Section("Movimientos encontrados (\(selected.count) de \(entries.count) seleccionados)") {
                    ForEach(entries.indices, id: \.self) { index in
                        Toggle(isOn: Binding(get: { selected.contains(index) },
                                             set: { on in if on { selected.insert(index) } else { selected.remove(index) } })) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entries[index].description.isEmpty ? "(sin descripción)" : entries[index].description).lineLimit(2)
                                    Text("\(entries[index].date.formatted(date: .abbreviated, time: .omitted)) · \(entries[index].kind.displayName)\(duplicates.contains(index) ? " · ya registrado" : "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text((entries[index].kind == .ingreso ? "+" : "-") + Money.format(entries[index].amount))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                Section {
                    Button("Importar \(selected.count) movimientos", action: importSelected)
                        .disabled(selected.isEmpty)
                }
            }
        }
        .navigationTitle("Importar extracto")
        .onChange(of: accountID) { _, _ in if !rawText.isEmpty { process(text: rawText, announceEmpty: true) } }
        .alert("Extracto", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func total(of kind: MovementKind) -> Int {
        selected.reduce(0) { $0 + (entries[$1].kind == kind ? entries[$1].amount : 0) }
    }

    private func load(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { message = "No se pudo leer el archivo."; return }
        document = nil
        needsPassword = false
        usedOCR = false
        entries = []
        if url.pathExtension.lowercased() == "pdf" {
            guard let pdf = PDFDocument(data: data) else { message = "No se pudo abrir el PDF."; return }
            document = pdf
            if pdf.isLocked { needsPassword = true; return }
            read(pdf)
        } else {
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                message = "No se pudo leer el texto del archivo."
                return
            }
            process(text: text, announceEmpty: true)
        }
    }

    private func unlock() {
        guard let pdf = document else { return }
        if pdf.unlock(withPassword: password.trimmingCharacters(in: .whitespaces)) {
            needsPassword = false
            password = ""
            read(pdf)
        } else {
            message = "Contraseña incorrecta."
        }
    }

    /// Texto incrustado primero; si no aparece ningún movimiento, se lee la imagen de las páginas.
    private func read(_ pdf: PDFDocument) {
        process(text: StatementTextExtractor.embeddedText(of: pdf), announceEmpty: false)
        guard entries.isEmpty else { return }
        readImage()
    }

    /// Dibuja cada página y la lee con OCR: sirve cuando el PDF no deja copiar el texto o es una imagen.
    private func readImage() {
        guard let pdf = document, !readingImage else { return }
        readingImage = true
        Task {
            let text = await StatementTextExtractor.ocrText(of: pdf)
            readingImage = false
            usedOCR = true
            process(text: text, announceEmpty: true)
        }
    }

    private func process(text: String, announceEmpty: Bool) {
        rawText = text
        let year = Calendar.current.component(.year, from: .now)
        entries = StatementParser.parse(text: text, calendar: .current, defaultYear: year)
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        duplicates = Set(entries.indices.filter {
            StatementReconciler.isDuplicate(entries[$0], accountID: accountID, existing: snapshots, calendar: .current)
        })
        selected = Set(entries.indices).subtracting(duplicates)
        if entries.isEmpty && announceEmpty {
            message = "No encontré movimientos. Cada uno debe tener fecha, descripción y monto. Descarga el extracto desde la app del banco (PDF, CSV o TXT) y vuelve a intentarlo."
        }
    }

    private func importSelected() {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return }
        // Un «pago a tu tarjeta» va a la tarjeta de crédito del mismo banco, si es la única.
        let cards = accounts.filter { $0.kind == .credito && $0.bank == account.bank && $0.id != account.id }
        var created: [Movement] = []
        for index in selected.sorted() {
            let entry = entries[index]
            let method: PaymentMethod
            switch entry.kind {
            case .ingreso, .transferencia: method = .transferencia
            case .gasto: method = account.kind == .credito ? .credito : .debito
            }
            let movement = Movement(amount: entry.amount, date: entry.date, kind: entry.kind, method: method,
                                    accountID: account.id, source: .extracto, status: .confirmado)
            movement.merchant = entry.description.isEmpty ? nil : entry.description
            if entry.kind == .transferencia, cards.count == 1 { movement.destinationAccountID = cards[0].id }
            context.insert(movement)
            created.append(movement)
        }
        try? context.save()
        created.forEach { MovementStore.didConfirm($0, context: context) }
        message = "Importados \(created.count) movimientos."
        entries = []
        selected = []
        duplicates = []
        rawText = ""
    }
}
