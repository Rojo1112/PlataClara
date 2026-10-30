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
    @State private var holdFlags: Set<Int> = []
    @State private var thirdPartyFlags: Set<Int> = []
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @State private var selected: Set<Int> = []
    @State private var document: PDFDocument?
    @State private var needsPassword = false
    @State private var password = ""
    @State private var readingImage = false
    @State private var usedOCR = false
    @State private var message: String?
    @State private var photos: [PhotosPickerItem] = []
    /// Avance al leer capturas, que pueden ser muchas: cuántas van y cuántas son.
    @State private var screenshotProgress: (read: Int, total: Int)?
    @State private var fromScreenshots = false
    @Query private var checkpoints: [BalanceCheckpoint]
    @State private var summary = StatementSummary()
    /// Renglones agregados al final desde el resumen (rendimientos, 4x1000, costos): no están en «lo que entró / salió».
    @State private var summaryEntries = 0
    @State private var saveCheckpoints = true
    @State private var registerPocketTransfer = false

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
                PhotosPicker(selection: $photos, matching: .images) {
                    Label("Leer capturas de pantalla…", systemImage: "photo.on.rectangle")
                }
                .disabled(accountID == nil || readingImage)
            } footer: {
                Text("Elige las capturas que quieras, sin límite, de la lista de movimientos de la app del banco. Se leen en tu iPhone. Lo tachado o con reloj en la app del banco no se distingue: desmarca esos antes de importar.")
            }

            if needsPassword {
                Section("El PDF tiene contraseña") {
                    SecureField("Contraseña (en Nu suele ser tu cédula)", text: $password)
                    Button("Desbloquear", action: unlock)
                }
            }

            if readingImage {
                Section {
                    HStack {
                        ProgressView()
                        if let progress = screenshotProgress {
                            Text("  Leyendo captura \(progress.read + 1) de \(progress.total)…")
                        } else {
                            Text("  Leyendo la imagen del PDF…")
                        }
                    }
                }
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

            if !entries.isEmpty, !fromScreenshots, summary.closing != nil {
                continuitySection
            }

            if document != nil, !needsPassword, !readingImage, !entries.isEmpty, !usedOCR {
                Section {
                    Button("¿No coinciden los totales? Releer como imagen (OCR)") { readImage() }
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
                    let saved = pocketTotal(.toPocket)
                    let withdrawn = pocketTotal(.fromPocket)
                    let cardPayments = total(of: .transferencia) - saved - withdrawn
                    LabeledContent("Pagos a tarjeta de crédito", value: Money.format(cardPayments))
                    if saved > 0 { LabeledContent("Guardado en cajitas (no es gasto)", value: Money.format(saved)) }
                    if withdrawn > 0 { LabeledContent("Sacado de cajitas (no es ingreso)", value: Money.format(withdrawn)) }
                    let balance = total(of: .ingreso) - total(of: .gasto) - cardPayments - saved + withdrawn
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

    /// El renglón es plata que se guarda en una cajita o se saca de ella (y nadie le cambió el tipo).
    private func isPocket(_ index: Int, _ direction: PocketDirection) -> Bool {
        kind(index) == .transferencia && entries[index].pocket == direction
    }

    private func pocketTotal(_ direction: PocketDirection) -> Int {
        selected.reduce(0) { $0 + (isPocket($1, direction) ? entries[$1].amount : 0) }
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
                      holdFlags.contains(index) ? MovementTag.hold.title : nil,
                      thirdPartyFlags.contains(index) ? MovementTag.thirdParty.title : nil,
                      duplicates.contains(index) ? "ya registrado" : nil].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text((kind(index) == .ingreso || isPocket(index, .fromPocket) ? "+" : "-") + Money.format(entry.amount)).monospacedDigit()
            Menu {
                Button(isOn ? "Ignorar este movimiento" : "Importar este movimiento",
                       systemImage: isOn ? "minus.circle" : "plus.circle") {
                    if isOn { selected.remove(index) } else { selected.insert(index) }
                }
                Picker("Tipo", selection: Binding(get: { kind(index) }, set: { kindOverride[index] = $0 })) {
                    ForEach(MovementKind.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle("Retención pendiente (reloj de Nu)", isOn: Binding(
                    get: { holdFlags.contains(index) },
                    set: { on in if on { holdFlags.insert(index) } else { holdFlags.remove(index) } }))
                Toggle("Plata de un tercero", isOn: Binding(
                    get: { thirdPartyFlags.contains(index) },
                    set: { on in if on { thirdPartyFlags.insert(index) } else { thirdPartyFlags.remove(index) } }))
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
        return StatementReconciler.check(entries: Array(entries.dropLast(summaryEntries)), against: declared)
    }

    /// Contraste del saldo: inicio + entró − salió + rendimientos − 4x1000 − costos contra el final, y el inicio
    /// contra el final del extracto anterior. El saldo final queda como punto de cuadre.
    @ViewBuilder
    private var continuitySection: some View {
        Section {
            if let gap = summary.continuityGap {
                if abs(gap) <= 1 {
                    Label("El saldo cuadra: inicio + lo que entró − lo que salió + rendimientos − impuestos da el saldo final.",
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label(gap > 0 ? "Entraron \(Money.format(gap)) que no aparecen en la lista de movimientos."
                                  : "Salieron \(Money.format(-gap)) que no aparecen en la lista de movimientos.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Toggle(gap > 0 ? "Fue un traslado desde una cajita: registrarlo" : "Fue un traslado hacia una cajita: registrarlo",
                           isOn: $registerPocketTransfer)
                }
            }
            if let previous = previousClosing, let opening = StatementSummary.pesos(summary.opening),
               abs(previous.balance - opening) > 1 {
                Label("El saldo inicial (\(Money.format(opening))) no coincide con el final del extracto anterior (\(Money.format(previous.balance))).",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            if let closing = StatementSummary.pesos(summary.closing), let end = summary.periodEnd {
                Toggle("Guardar el saldo final (\(Money.format(closing)) el \(Fecha.dia(end))) como punto de cuadre", isOn: $saveCheckpoints)
            }
        } header: {
            Text("¿Cuadra el saldo del extracto?")
        } footer: {
            Text("Con el punto de cuadre, el saldo de la cuenta parte de lo que dice el banco y no de sumar todos los movimientos desde el principio.")
        }
    }

    /// Punto de cuadre que ya existe justo donde empieza este extracto (el final del anterior).
    private var previousClosing: BalanceCheckpoint? {
        guard let accountID, let opening = summary.openingDate else { return nil }
        return checkpoints.first { $0.accountID == accountID && abs($0.date.timeIntervalSince(opening)) < 1 }
    }

    /// Rendimientos, 4x1000 y costos del resumen como movimientos, el último día del período.
    private func summaryLines(_ s: StatementSummary) -> [StatementEntry] {
        guard let end = s.periodEnd else { return [] }
        let at = end.addingTimeInterval(-59)
        var lines: [StatementEntry] = []
        if let value = StatementSummary.pesos(s.yield), value > 0 {
            lines.append(StatementEntry(date: at, description: "Rendimientos del mes (resumen del extracto)", amount: value,
                                        kind: .ingreso, balance: nil, hasTime: true))
        }
        if let value = StatementSummary.pesos(s.tax), value > 0 {
            lines.append(StatementEntry(date: at, description: "Impuesto 4x1000 (resumen del extracto)", amount: value,
                                        kind: .gasto, balance: nil, hasTime: true))
        }
        if let value = StatementSummary.pesos(s.withdrawalCosts), value > 0 {
            lines.append(StatementEntry(date: at, description: "Costos por retiro (resumen del extracto)", amount: value,
                                        kind: .gasto, balance: nil, hasTime: true))
        }
        return lines
    }

    /// Guarda el saldo inicial y el final del extracto como puntos de cuadre, y el de las cajitas si lo trae.
    private func saveStatementCheckpoints(for account: Account) {
        if registerPocketTransfer, let gap = summary.continuityGap, abs(gap) > 1, let end = summary.periodEnd {
            ReconciliationService.apply(BalanceAudit.pocketTransfer(gap, date: end.addingTimeInterval(-120)), to: account, context: context)
        }
        guard saveCheckpoints, let end = summary.periodEnd, let closing = StatementSummary.pesos(summary.closing) else { return }
        if previousClosing == nil, let opening = StatementSummary.pesos(summary.opening), let start = summary.openingDate {
            ReconciliationService.addCheckpoint(accountID: account.id, balance: opening, date: start, source: .extracto, context: context)
        }
        ReconciliationService.addCheckpoint(accountID: account.id, balance: closing, date: end, source: .extracto, context: context)
        if let pockets = StatementSummary.pesos(summary.pockets),
           pockets > 0 || accounts.contains(where: { $0.parentAccountID == account.id }) {
            let pocketsAccount = ReconciliationService.pockets(of: account, context: context)
            ReconciliationService.addCheckpoint(accountID: pocketsAccount.id, balance: pockets, date: end, source: .extracto, context: context)
        }
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

    /// Texto incrustado primero. Si no aparece ningún movimiento, o lo leído no cuadra con los totales que dice el
    /// propio PDF, se lee también la imagen de las páginas y se queda la lectura que más se acerque a esos totales.
    private func read(_ pdf: PDFDocument) {
        let embedded = StatementTextExtractor.embeddedText(of: pdf)
        process(text: embedded, announceEmpty: false)
        let doesNotMatch = totalsCheck.map { $0.incomeMatches == false || $0.outflowMatches == false } ?? false
        guard entries.isEmpty || doesNotMatch else { return }
        readImage(comparingWith: embedded)
    }

    /// Dibuja cada página y la lee con OCR: sirve cuando el PDF no deja copiar el texto, es una imagen o el texto
    /// incrustado sale incompleto. Con `embedded` solo reemplaza la primera lectura si queda más cerca de los totales.
    private func readImage(comparingWith embedded: String? = nil) {
        guard let pdf = document, !readingImage else { return }
        readingImage = true
        Task {
            let text = await StatementTextExtractor.ocrText(of: pdf)
            readingImage = false
            if let embedded, !isBetter(text, than: embedded) {
                process(text: embedded, announceEmpty: true)
                return
            }
            usedOCR = true
            process(text: text, announceEmpty: true)
        }
    }

    /// Cuánto se aleja lo leído de los totales del PDF (0 = cuadra). Sin totales, gana quien encuentre más movimientos.
    private func gap(_ text: String, declared: StatementTotals) -> Int {
        let calendar = Calendar.gregoriano
        let found = StatementParser.parse(text: text, calendar: calendar, defaultYear: calendar.component(.year, from: .now))
        guard declared.income != nil || declared.outflow != nil else { return -found.count }
        let check = StatementReconciler.check(entries: found, against: declared)
        return abs(check.readIncome - (declared.income ?? check.readIncome))
            + abs(check.readOutflow - (declared.outflow ?? check.readOutflow))
    }

    private func isBetter(_ ocr: String, than embedded: String) -> Bool {
        let fromEmbedded = StatementParser.declaredTotals(in: embedded)
        let fromOCR = StatementParser.declaredTotals(in: ocr)
        let declared = StatementTotals(income: fromEmbedded.income ?? fromOCR.income,
                                       outflow: fromEmbedded.outflow ?? fromOCR.outflow)
        return gap(ocr, declared: declared) < gap(embedded, declared: declared)
    }

    /// Lee las capturas elegidas con OCR y arma la lista de movimientos.
    private func readScreenshots(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty, !readingImage else { return }
        readingImage = true
        screenshotProgress = (0, items.count)
        Task {
            var texts: [String] = []
            // Una a la vez: con muchas capturas no se cargan todas las imágenes en memoria juntas.
            for (index, item) in items.enumerated() {
                screenshotProgress = (index, items.count)
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    texts.append(await StatementTextExtractor.ocrText(of: image))
                }
            }
            photos = []
            screenshotProgress = nil
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
            summary = StatementSummary()
            summaryEntries = 0
        } else {
            entries = StatementParser.parse(text: text, calendar: calendar, defaultYear: year)
            declared = StatementParser.declaredTotals(in: text)
            summary = StatementParser.summary(in: text, calendar: calendar)
            let extra = entries.isEmpty ? [] : summaryLines(summary)
            entries += extra
            summaryEntries = extra.count
        }
        saveCheckpoints = true
        registerPocketTransfer = false
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        matches = StatementReconciler.match(entries, accountID: accountID, existing: snapshots, calendar: calendar)
        duplicates = Set(matches.keys)
        kindOverride = [:]
        categoryOverride = [:]
        holdFlags = []
        thirdPartyFlags = []
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
        var pocketsAccount: Account?
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
            if let direction = entry.pocket, finalKind == .transferencia, ReconciliationService.allowsPockets(account) {
                // Guardar en una cajita o sacar de ella es un traslado entre la cuenta y sus cajitas: no es gasto ni ingreso.
                let pockets = pocketsAccount ?? ReconciliationService.pockets(of: account, context: context)
                pocketsAccount = pockets
                movement.accountID = direction == .fromPocket ? pockets.id : account.id
                movement.destinationAccountID = direction == .fromPocket ? account.id : pockets.id
            } else if finalKind == .transferencia, cards.count == 1 {
                movement.destinationAccountID = cards[0].id
            }
            movement.note = MovementTag.compose(text: "", hold: holdFlags.contains(index), thirdParty: thirdPartyFlags.contains(index))
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
        if !fromScreenshots { saveStatementCheckpoints(for: account) }
        let alreadyThere = matches.count
        message = "Importados \(selected.count) movimientos nuevos."
            + (alreadyThere > 0 ? " \(alreadyThere) ya estaban registrados y no se repitieron" + (completed > 0 ? " (\(completed) se completaron con los datos del banco)." : ".") : "")
        entries = []
        selected = []
        duplicates = []
        matches = [:]
        kindOverride = [:]
        categoryOverride = [:]
        holdFlags = []
        thirdPartyFlags = []
        rawText = ""
        summary = StatementSummary()
        summaryEntries = 0
    }
}
