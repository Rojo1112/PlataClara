import SwiftUI
import UIKit
import SwiftData
import PDFKit
import PhotosUI
import UniformTypeIdentifiers
import PlataCore

struct StatementImportView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query private var movements: [Movement]

    @State private var accountID: UUID?
    @State private var importing = false
    @State private var rawText = ""
    @State private var declared = StatementTotals(income: nil, outflow: nil)
    @State private var entries: [StatementEntry] = []
    @State private var duplicates: Set<Int> = []
    @State private var matches: [Int: UUID] = [:]
    @State private var kindOverride: [Int: MovementKind] = [:]
    @State private var categoryOverride: [Int: UUID] = [:]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var selected: Set<Int> = []
    @State private var document: PDFDocument?
    @State private var needsPassword = false
    @State private var password = ""
    @State private var readingImage = false
    @State private var usedOCR = false
    @State private var message: String?
    @State private var photos: [PhotosPickerItem] = []
    @State private var fromScreenshots = false

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

            Section {
                PhotosPicker(selection: $photos, maxSelectionCount: 10, matching: .images) {
                    Label("Leer capturas de pantalla…", systemImage: "photo.on.rectangle")
                }
                .disabled(accountID == nil || readingImage)
            } footer: {
                Text("Elige capturas de la lista de movimientos de la app del banco (hasta 10). Se leen en tu iPhone. Lo tachado o con reloj en la app del banco no se distingue: desmarca esos antes de importar.")
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

            if !entries.isEmpty, let check = totalsCheck {
                Section {
                    checkRow("Lo que te entró (ingresos y reembolsos)", read: check.readIncome, declared: declared.income, matches: check.incomeMatches)
                    checkRow("Lo que te salió (gastos y pagos a tarjeta)", read: check.readOutflow, declared: declared.outflow, matches: check.outflowMatches)
                } header: {
                    Text("¿Coincide con el resumen del PDF?")
                } footer: {
                    Text(summaryFooter(check))
                }
            }

            if document != nil, !needsPassword, !readingImage, !entries.isEmpty, !usedOCR {
                Section {
                    Button("¿No coinciden los totales? Releer como imagen (OCR)", action: readImage)
                }
            }

            if !rawText.isEmpty {
                Section {
                    Button("Copiar el texto leído (para pedir ayuda)") { UIPasteboard.general.string = rawText }
                } footer: {
                    Text("Copia el texto que la app sacó del archivo. Pégalo con los datos personales tachados si necesitas que revisen la lectura.")
                }
            }

            if !entries.isEmpty {
                Section {
                    LabeledContent("Ingresos", value: Money.format(selectedIncome(refunds: false)))
                    LabeledContent("Reembolsos (se restan de los gastos)", value: Money.format(selectedIncome(refunds: true)))
                    LabeledContent("Gastos", value: Money.format(total(of: .gasto)))
                    LabeledContent("Pagos a tarjeta de crédito", value: Money.format(total(of: .transferencia)))
                    let balance = total(of: .ingreso) - total(of: .gasto) - total(of: .transferencia)
                    LabeledContent(balance < 0 ? "Salió más de lo que entró" : "Entró más de lo que salió",
                                   value: Money.format(abs(balance)))
                        .foregroundStyle(balance < 0 ? Color.red : Color.green)
                } header: {
                    Text("Lo que vas a importar")
                } footer: {
                    Text(fromScreenshots
                         ? "Leído de capturas: revisa cada movimiento y desmarca lo tachado o con reloj en la app del banco."
                         : usedOCR
                         ? "Se leyó la imagen del PDF (OCR): revisa que cada monto esté bien antes de importar."
                         : "Solo se cuentan los movimientos marcados.")
                }

                Section {
                    Button("Importar \(selected.count) movimientos", action: importSelected)
                        .disabled(selected.isEmpty)
                    Menu {
                        Button("Solo lo nuevo") { selected = Set(entries.indices).subtracting(duplicates) }
                        Button("Todos") { selected = Set(entries.indices) }
                        Button("Ninguno") { selected = [] }
                    } label: {
                        Label("Qué seleccionar", systemImage: "checklist")
                    }
                } footer: {
                    if !duplicates.isEmpty {
                        Text("\(duplicates.count) ya estaban registrados: no se repiten, solo se completan con los datos del banco.")
                    }
                }

                Section("Movimientos encontrados (\(selected.count) de \(entries.count) seleccionados)") {
                    ForEach(entries.indices, id: \.self) { index in
                        row(index)
                    }
                }
            }
        }
        .navigationTitle("Importar extracto")
        .onChange(of: accountID) { _, _ in if !rawText.isEmpty { process(text: rawText, announceEmpty: true, screenshots: fromScreenshots) } }
        .onChange(of: photos) { _, items in readScreenshots(items) }
        .alert("Extracto", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    /// Tipo final del renglón: el que lee la app o el que cambió el usuario en el menú.
    private func kind(_ index: Int) -> MovementKind { kindOverride[index] ?? entries[index].kind }

    private func total(of kind: MovementKind) -> Int {
        selected.reduce(0) { $0 + (self.kind($1) == kind ? entries[$1].amount : 0) }
    }

    private func selectedIncome(refunds: Bool) -> Int {
        selected.reduce(0) { sum, index in
            let entry = entries[index]
            guard kind(index) == .ingreso, MovementClassifier.isRefund(entry.description) == refunds else { return sum }
            return sum + entry.amount
        }
    }

    /// Categoría elegida en el menú o, si no, la que se adivina por la descripción.
    private func categoryName(_ index: Int) -> String? {
        if let id = categoryOverride[index] { return categories.first { $0.id == id }?.name }
        return kind(index) == .gasto ? AutoCategory.guess(entries[index].description) : nil
    }

    @ViewBuilder
    private func row(_ index: Int) -> some View {
        let entry = entries[index]
        let isOn = selected.contains(index)
        HStack(spacing: 12) {
            Button {
                if isOn { selected.remove(index) } else { selected.insert(index) }
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description.isEmpty ? "(sin descripción)" : entry.description).lineLimit(2)
                Text([Fecha.dia(entry.date), kind(index).displayName, categoryName(index),
                      duplicates.contains(index) ? "ya registrado" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text((kind(index) == .ingreso ? "+" : "-") + Money.format(entry.amount)).monospacedDigit()
            Menu {
                Button(isOn ? "Ignorar este movimiento" : "Importar este movimiento",
                       systemImage: isOn ? "minus.circle" : "plus.circle") {
                    if isOn { selected.remove(index) } else { selected.insert(index) }
                }
                Picker("Tipo", selection: Binding(get: { kind(index) }, set: { kindOverride[index] = $0 })) {
                    ForEach(MovementKind.allCases) { Text($0.displayName).tag($0) }
                }
                Menu("Categoría") {
                    Button("Automática") { categoryOverride[index] = nil }
                    ForEach(categories.filter { $0.isIncome == (kind(index) == .ingreso) }) { category in
                        Button(category.name, systemImage: category.icon) { categoryOverride[index] = category.id }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title3)
            }
        }
    }

    /// Lo leído contra lo que el propio extracto declara («Lo que entró / salió de tu cuenta»), si lo trae.
    private var totalsCheck: TotalsCheck? {
        guard declared.income != nil || declared.outflow != nil else { return nil }
        return StatementReconciler.check(entries: entries, against: declared)
    }

    @ViewBuilder
    private func checkRow(_ title: String, read: Int, declared: Int?, matches: Bool?) -> some View {
        if let declared {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: matches == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(matches == true ? Color.green : Color.orange)
                }
                Text("El PDF dice \(Money.format(declared)) · leí \(Money.format(read))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func summaryFooter(_ check: TotalsCheck) -> String {
        if check.incomeMatches != false && check.outflowMatches != false {
            return "Lo leído coincide con el resumen del extracto. Puedes importar con tranquilidad."
        }
        return "Hay diferencias: faltan o sobran movimientos. Prueba «Releer como imagen (OCR)» o copia el texto leído para revisarlo."
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

    /// Lee las capturas elegidas con OCR y arma la lista de movimientos.
    private func readScreenshots(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty, !readingImage else { return }
        readingImage = true
        Task {
            var texts: [String] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    texts.append(await StatementTextExtractor.ocrText(of: image))
                }
            }
            photos = []
            readingImage = false
            document = nil
            needsPassword = false
            usedOCR = true
            process(text: texts.joined(separator: "\n\(ScreenshotParser.pageBreak)\n"), announceEmpty: true, screenshots: true)
        }
    }

    private func process(text: String, announceEmpty: Bool, screenshots: Bool = false) {
        rawText = text
        fromScreenshots = screenshots
        let calendar = Calendar.gregoriano
        let year = calendar.component(.year, from: .now)
        if screenshots {
            entries = ScreenshotParser.parse(text: text, now: .now, calendar: calendar)
            declared = StatementTotals(income: nil, outflow: nil)
        } else {
            entries = StatementParser.parse(text: text, calendar: calendar, defaultYear: year)
            declared = StatementParser.declaredTotals(in: text)
        }
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        matches = StatementReconciler.match(entries, accountID: accountID, existing: snapshots, calendar: calendar)
        duplicates = Set(matches.keys)
        kindOverride = [:]
        categoryOverride = [:]
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
        var knownCategories = categories
        for index in selected.sorted() {
            let entry = entries[index]
            let finalKind = kind(index)
            let method: PaymentMethod
            switch finalKind {
            case .ingreso, .transferencia: method = .transferencia
            case .gasto: method = account.kind == .credito ? .credito : .debito
            }
            let movement = Movement(amount: entry.amount, date: entry.date, kind: finalKind, method: method,
                                    accountID: account.id, source: .extracto, status: .confirmado)
            movement.merchant = entry.description.isEmpty ? nil : entry.description
            if finalKind == .transferencia, cards.count == 1 { movement.destinationAccountID = cards[0].id }
            if let name = categoryName(index) {
                if let known = knownCategories.first(where: { $0.name == name }) {
                    movement.categoryID = known.id
                } else {
                    let new = Category(name: name, icon: "tag", colorHex: "#757575", isIncome: finalKind == .ingreso,
                                       sortOrder: knownCategories.count)
                    context.insert(new)
                    knownCategories.append(new)
                    movement.categoryID = new.id
                }
            }
            context.insert(movement)
            created.append(movement)
        }
        // Lo que ya estaba registrado (Apple Pay, aviso, otra captura) no se duplica: se completa con los datos del banco.
        var completed = 0
        for (index, id) in matches where !selected.contains(index) {
            guard let existing = movements.first(where: { $0.id == id }) else { continue }
            let entry = entries[index]
            var changed = false
            if existing.merchant == nil, !entry.description.isEmpty { existing.merchant = entry.description; changed = true }
            if existing.accountID == nil { existing.accountID = account.id; changed = true }
            if entry.hasTime, existing.date != entry.date { existing.date = entry.date; changed = true }
            if existing.status != .confirmado {
                existing.status = .confirmado
                changed = true
                created.append(existing)
            }
            if changed { completed += 1 }
        }
        try? context.save()
        created.forEach { MovementStore.didConfirm($0, context: context) }
        let alreadyThere = matches.count
        message = "Importados \(selected.count) movimientos nuevos."
            + (alreadyThere > 0 ? " \(alreadyThere) ya estaban registrados y no se repitieron" + (completed > 0 ? " (\(completed) se completaron con los datos del banco)." : ".") : "")
        entries = []
        selected = []
        duplicates = []
        matches = [:]
        kindOverride = [:]
        categoryOverride = [:]
        rawText = ""
    }
}
