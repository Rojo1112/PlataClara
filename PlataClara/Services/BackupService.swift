import Foundation
import SwiftData
import PlataCore

enum BackupProtectionError: LocalizedError {
    case missingKey, needsPassword, wrongPassword

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Los respaldos están cifrados pero este iPhone no tiene la llave. Vuelve a poner la contraseña en Ajustes › Cifrar respaldos."
        case .needsPassword: return "El respaldo está cifrado: escribe su contraseña."
        case .wrongPassword: return "La contraseña no abre este respaldo. No se cambió nada."
        }
    }
}

@MainActor
enum BackupService {
    static let encryptionKey = "respaldoCifrado"

    /// El usuario pidió cifrar los respaldos. Si además falta la llave en el llavero, no se escribe ninguno:
    /// nunca se vuelve a guardar en claro sin que lo decida.
    static var encryptionEnabled: Bool { UserDefaults.standard.bool(forKey: encryptionKey) }

    /// El respaldo listo para escribir: cifrado si el cifrado está activo.
    static func encoded(context: ModelContext) throws -> Data {
        let plain = try BackupCodec.encode(makeFile(context: context))
        guard encryptionEnabled else { return plain }
        guard let key = BackupKeychain.load() else { throw BackupProtectionError.missingKey }
        return try BackupCrypto.encrypt(plain, with: key)
    }

    /// Activa el cifrado con esa contraseña (o la cambia). Devuelve false si el llavero no aceptó la llave.
    static func enableEncryption(password: String) throws -> Bool {
        let key = try BackupCrypto.makeKey(password: password)
        guard BackupKeychain.save(key) else { return false }
        UserDefaults.standard.set(true, forKey: encryptionKey)
        return true
    }

    static func disableEncryption() {
        UserDefaults.standard.set(false, forKey: encryptionKey)
        BackupKeychain.delete()
    }

    /// El contenido del archivo en claro. Uno cifrado se abre con la llave de este iPhone o, si no sirve, con la
    /// contraseña; abrirlo con contraseña deja el cifrado activo con esa llave, para seguir respaldando cifrado.
    private static func plainData(of url: URL, password: String?) throws -> Data {
        let data = try Data(contentsOf: url)
        guard BackupCrypto.isEncrypted(data) else { return data }
        if let key = BackupKeychain.load(), let plain = try? BackupCrypto.decrypt(data, with: key) { return plain }
        guard let password, !password.isEmpty else { throw BackupProtectionError.needsPassword }
        do {
            let opened = try BackupCrypto.decrypt(data, password: password)
            if BackupKeychain.save(opened.key) { UserDefaults.standard.set(true, forKey: encryptionKey) }
            return opened.plain
        } catch BackupCryptoError.wrongPassword {
            throw BackupProtectionError.wrongPassword
        }
    }

    static func makeFile(context: ModelContext) -> BackupFile {
        BackupFile(
            exportedAt: .now,
            accounts: context.all(Account.self).map {
                AccountDTO(id: $0.id, name: $0.name, bank: $0.bank, kind: $0.kind, openingBalance: $0.openingBalance,
                           creditLimit: $0.creditLimit, cutoffDay: $0.cutoffDay, paymentDay: $0.paymentDay,
                           last4: $0.last4, walletCardName: $0.walletCardName, emailSenders: $0.emailSenders,
                           createdAt: $0.createdAt, parentAccountID: $0.parentAccountID)
            },
            categories: context.all(Category.self).map {
                CategoryDTO(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex, isIncome: $0.isIncome,
                            sortOrder: $0.sortOrder)
            },
            movements: context.all(Movement.self).map {
                MovementDTO(id: $0.id, amount: $0.amount, date: $0.date, kind: $0.kind, method: $0.method,
                            accountID: $0.accountID, destinationAccountID: $0.destinationAccountID,
                            categoryID: $0.categoryID, merchant: $0.merchant, note: $0.note, source: $0.source,
                            status: $0.status, rawText: $0.rawText, occurrenceID: $0.occurrenceID)
            },
            recurring: context.all(RecurringExpense.self).map {
                RecurringDTO(id: $0.id, name: $0.name, amount: $0.amount, dayOfMonth: $0.dayOfMonth,
                             accountID: $0.accountID, method: $0.method, categoryID: $0.categoryID,
                             active: $0.active, remind: $0.remind)
            },
            occurrences: context.all(RecurringOccurrence.self).map {
                OccurrenceDTO(id: $0.id, recurringID: $0.recurringID, monthKey: $0.monthKey, dueDate: $0.dueDate,
                              status: $0.status, movementID: $0.movementID)
            },
            checkpoints: context.all(BalanceCheckpoint.self).map {
                CheckpointDTO(id: $0.id, accountID: $0.accountID, date: $0.date, balance: $0.balance, source: $0.source)
            })
    }

    static func exportURL(context: ModelContext) throws -> URL {
        let data = try encoded(context: context)
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PlataClara-respaldo-\(stamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Reemplaza todos los datos por los del archivo. Devuelve cuántos movimientos se restauraron.
    static func restore(from url: URL, password: String? = nil, context: ModelContext) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let file = try BackupCodec.decode(plainData(of: url, password: password))

        do {
            context.all(Movement.self).forEach { context.delete($0) }
            context.all(RecurringOccurrence.self).forEach { context.delete($0) }
            context.all(RecurringExpense.self).forEach { context.delete($0) }
            context.all(Category.self).forEach { context.delete($0) }
            context.all(Account.self).forEach { context.delete($0) }
            context.all(BalanceCheckpoint.self).forEach { context.delete($0) }

            for dto in file.accounts {
                let a = Account(name: dto.name, bank: dto.bank, kind: dto.kind, openingBalance: dto.openingBalance)
                a.id = dto.id
                a.creditLimit = dto.creditLimit
                a.cutoffDay = dto.cutoffDay
                a.paymentDay = dto.paymentDay
                a.last4 = dto.last4
                a.walletCardName = dto.walletCardName
                a.emailSenders = dto.emailSenders
                a.createdAt = dto.createdAt
                a.parentAccountID = dto.parentAccountID
                context.insert(a)
            }
            for dto in file.categories {
                let c = Category(name: dto.name, icon: dto.icon, colorHex: dto.colorHex, isIncome: dto.isIncome, sortOrder: dto.sortOrder)
                c.id = dto.id
                context.insert(c)
            }
            for dto in file.movements {
                let m = Movement(amount: dto.amount, date: dto.date, kind: dto.kind, method: dto.method,
                                 accountID: dto.accountID, source: dto.source, status: dto.status)
                m.id = dto.id
                m.destinationAccountID = dto.destinationAccountID
                m.categoryID = dto.categoryID
                m.merchant = dto.merchant
                m.note = dto.note
                m.rawText = dto.rawText
                m.occurrenceID = dto.occurrenceID
                context.insert(m)
            }
            for dto in file.recurring {
                let r = RecurringExpense(name: dto.name, amount: dto.amount, dayOfMonth: dto.dayOfMonth)
                r.id = dto.id
                r.accountID = dto.accountID
                r.method = dto.method
                r.categoryID = dto.categoryID
                r.active = dto.active
                r.remind = dto.remind
                context.insert(r)
            }
            for dto in file.occurrences {
                let o = RecurringOccurrence(recurringID: dto.recurringID, monthKey: dto.monthKey, dueDate: dto.dueDate)
                o.id = dto.id
                o.status = dto.status
                o.movementID = dto.movementID
                context.insert(o)
            }
            for dto in file.checkpoints ?? [] {
                let cp = BalanceCheckpoint(accountID: dto.accountID, date: dto.date, balance: dto.balance, source: dto.source)
                cp.id = dto.id
                context.insert(cp)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return file.movements.count
    }
}
