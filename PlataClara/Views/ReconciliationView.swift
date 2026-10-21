import SwiftUI
import UIKit
import SwiftData
import PhotosUI
import PlataCore

/// Cuadre de una cuenta con el banco: saldo, confianza, diferencias entre cuadres y qué las explica.
struct ReconciliationView: View {
    @Environment(\.modelContext) private var context
    let account: Account
    @Query private var movements: [Movement]
    @Query private var checkpoints: [BalanceCheckpoint]
    @Query private var accounts: [Account]

    @State private var bankBalance = 0
    @State private var pocketsBalance = 0
    @State private var date = Date.now
    @State private var source: CheckpointSource = .manual
    @State private var photo: PhotosPickerItem?
    @State private var reading = false
    @State private var proposal: [Fix]?
    @State private var message: String?

    var body: some View {
        let snapshots = movements.map { $0.snapshot(categoryName: nil) }
        let points = checkpoints.map(\.snapshot)
        let audit = ReconciliationService.audit(account, movements: snapshots, checkpoints: points)
        let pockets = accounts.first { $0.parentAccountID == account.id }
        let pocketsAudit = pockets.map { ReconciliationService.audit($0, movements: snapshots, checkpoints: points) }
        let issues = audit.segments.filter { !$0.matches }

        List {
            Section {
                HStack {
                    Text(account.kind == .credito ? "Deuda calculada" : "Saldo calculado").font(.headline)
                    Spacer()
                    Text(Money.format(audit.balance)).font(.title3.weight(.semibold)).monospacedDigit()
                }
                ConfidenceLabel(confidence: audit.confidence)
                Text(lastCheckpointText(audit.lastCheckpoint)).font(.caption).foregroundStyle(.secondary)
                ForEach(audit.reasons, id: \.self) { Text($0).font(.subheadline) }
                if let pockets, let pocketsAudit {
                    LabeledContent(pockets.name, value: Money.format(pocketsAudit.balance))
                    if pocketsAudit.lastCheckpoint == nil {
                        Text("Las cajitas todavía no están cuadradas: escribe abajo cuánto tienes en ellas.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }

            Section {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(reading ? "Leyendo la captura…" : "Leer el saldo de una captura de inicio", systemImage: "camera.viewfinder")
                }
                .disabled(reading)
                AmountField(title: account.kind == .credito ? "Deuda que muestra el banco" : "Saldo que muestra el banco",
                            value: $bankBalance)
                if ReconciliationService.allowsPockets(account) {
                    AmountField(title: "En cajitas (opcional)", value: $pocketsBalance)
                }
                DatePicker("Fecha y hora", selection: $date, in: ...Date.now)
                Button("Guardar punto de cuadre", action: save)
            } header: {
                Text("Cuadrar con el banco")
            } footer: {
                Text("Pon el saldo que ves en la app del banco y la hora en que lo viste. Desde ahí la app suma solo los movimientos posteriores. No toca ningún movimiento.")
            }

            ForEach(Array(issues.enumerated()), id: \.offset) { _, segment in
                Section {
                    segmentRows(segment)
                } header: {
                    Text(title(of: segment))
                }
            }

            let matching = audit.segments.filter { $0.end != nil && $0.matches }.count
            if matching > 0 {
                Section {
                    Label("\(matching) tramo(s) entre cuadres coinciden con el banco", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            let ownPoints = checkpoints.filter { $0.accountID == account.id }.sorted { $0.date > $1.date }
            if !ownPoints.isEmpty {
                Section("Puntos de cuadre") {
                    ForEach(ownPoints) { point in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(Fecha.diaHora(point.date))
                                Text(point.source.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Money.format(point.balance)).monospacedDigit()
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { ownPoints[$0] }.forEach { context.delete($0) }
                        try? context.save()
                    }
                }
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photo) { _, item in readPhoto(item) }
        .confirmationDialog("¿Aplicar este arreglo?", isPresented: Binding(get: { proposal != nil }, set: { if !$0 { proposal = nil } }),
                            titleVisibility: .visible) {
            Button("Aplicar") {
                proposal?.forEach { ReconciliationService.apply($0, to: account, context: context) }
                proposal = nil
            }
            Button("Cancelar", role: .cancel) { proposal = nil }
        } message: {
            Text((proposal ?? []).map { "• " + $0.summary + action(of: $0) }.joined(separator: "\n"))
        }
        .alert("Cuadre", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    @ViewBuilder
    private func segmentRows(_ segment: SegmentAudit) -> some View {
        if let end = segment.end, let difference = segment.difference {
            LabeledContent("La app calcula", value: Money.format(segment.expected))
            LabeledContent("El banco dice", value: Money.format(end.balance))
            LabeledContent(difference > 0 ? "Entró sin registrar" : "Salió sin registrar", value: Money.format(abs(difference)))
                .foregroundStyle(.orange)
        }
        if let dip = segment.dip {
            Label("El saldo calculado queda en negativo desde el \(Fecha.diaHora(dip.firstNegative)): falta al menos \(Money.format(dip.shortfall)) que entró y no está registrado.",
                  systemImage: "arrow.down.right.circle")
                .foregroundStyle(.orange)
        }
        ForEach(Array(segment.gaps.enumerated()), id: \.offset) { _, gap in
            Label("No hay movimientos entre el \(Fecha.diaHora(gap.start)) y el \(Fecha.diaHora(gap.end)). Sube una captura de ese tramo.",
                  systemImage: "clock.badge.questionmark")
                .font(.subheadline)
        }
        if let explanation = segment.explanation {
            VStack(alignment: .leading, spacing: 4) {
                Text("Esto cuadra exacto:").font(.subheadline.weight(.semibold))
                ForEach(explanation) { Text("• " + $0.summary).font(.subheadline) }
            }
            Button("Aplicar esta explicación") { proposal = explanation }
        }
        if let pocketFix = segment.pocketFix {
            Button("¿\(pocketFix.summary)? Registrarlo") { proposal = [pocketFix] }
        }
        if segment.explanation == nil && segment.pocketFix == nil {
            Text("Nada lo explica todavía. Queda a la vista hasta que subas las capturas que faltan.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func title(of segment: SegmentAudit) -> String {
        let from = segment.start.map { Fecha.diaHora($0.date) } ?? "el inicio"
        guard let end = segment.end else { return "Desde \(from) hasta hoy" }
        return "Del \(from) al \(Fecha.diaHora(end.date))"
    }

    private func lastCheckpointText(_ point: CheckpointSnapshot?) -> String {
        guard let point else { return "Sin cuadrar con el banco." }
        return "Cuadrado con el banco el \(Fecha.diaHora(point.date)) (\(point.source.displayName.lowercased()))."
    }

    private func action(of fix: Fix) -> String {
        switch fix.action {
        case .releaseHold, .removeDuplicate: return ": se borra ese movimiento."
        case .confirmPending: return ": se confirma."
        case .pocketTransfer: return ": se registra como traslado entre tus cuentas (no es ingreso ni gasto)."
        }
    }

    private func save() {
        ReconciliationService.addCheckpoint(accountID: account.id, balance: bankBalance, date: date, source: source, context: context)
        if pocketsBalance > 0 {
            let pockets = ReconciliationService.pockets(of: account, context: context)
            ReconciliationService.addCheckpoint(accountID: pockets.id, balance: pocketsBalance, date: date, source: source, context: context)
        }
        message = "Guardado. Desde el \(Fecha.diaHora(date)) el saldo parte de \(Money.format(bankBalance))."
        bankBalance = 0
        pocketsBalance = 0
        source = .manual
        date = .now
    }

    /// Lee la captura de la pantalla de inicio del banco y llena los campos para revisarlos antes de guardar.
    private func readPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reading = true
        Task {
            var text = ""
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                text = await StatementTextExtractor.ocrText(of: image)
            }
            reading = false
            photo = nil
            guard let found = HomeBalanceParser.parse(text: text) else {
                message = "No encontré el saldo en la captura. Escríbelo a mano."
                return
            }
            if let value = found.account { bankBalance = value }
            if let value = found.pockets { pocketsBalance = value }
            source = .captura
            message = "Revisa el saldo leído y la hora de la captura antes de guardar."
        }
    }
}

/// «Confianza alta», «media»… con su color.
struct ConfidenceLabel: View {
    let confidence: Confidence

    var body: some View {
        Label(confidence.title, systemImage: icon).foregroundStyle(color).font(.subheadline.weight(.semibold))
    }

    private var icon: String {
        switch confidence {
        case .verificado: return "checkmark.seal.fill"
        case .alto: return "checkmark.circle.fill"
        case .medio: return "exclamationmark.circle.fill"
        case .bajo: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch confidence {
        case .verificado, .alto: return .green
        case .medio: return .yellow
        case .bajo: return .orange
        }
    }
}
