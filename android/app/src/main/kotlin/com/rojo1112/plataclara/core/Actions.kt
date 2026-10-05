package com.rojo1112.plataclara.core

import java.time.Instant
import java.time.ZoneId
import java.util.UUID

sealed class CaptureOutcome {
    data class Registered(val movement: Movement) : CaptureOutcome()
    data class Review(val movement: Movement) : CaptureOutcome()
    object Duplicate : CaptureOutcome()

    val message: String
        get() = when (this) {
            is Registered -> "Registrado: ${movement.kind.label.lowercase()} de ${Money.format(movement.amount)} (${movement.method.label})."
            is Review ->
                if (movement.amount > 0) "Quedó por revisar: ${Money.format(movement.amount)}."
                else "No entendí el aviso; quedó por revisar."
            is Duplicate -> "Ese movimiento ya estaba registrado."
        }
}

/** Operaciones sobre los datos. Son funciones puras: reciben [AppData] y devuelven el nuevo estado. */
object Actions {
    fun newId(): String = UUID.randomUUID().toString()

    private val defaultCategories = listOf(
        Triple("Mercado", "cart", "#2E7D32"), Triple("Restaurantes", "fork.knife", "#EF6C00"),
        Triple("Transporte", "car", "#1565C0"), Triple("Servicios", "bolt", "#F9A825"),
        Triple("Arriendo", "house", "#6A1B9A"), Triple("Salud", "cross.case", "#C62828"),
        Triple("Ocio", "gamecontroller", "#AD1457"), Triple("Compras", "bag", "#00838F"),
        Triple("Suscripciones", "repeat", "#5D4037"), Triple("Educación", "book", "#283593"),
        Triple("Otros gastos", "ellipsis.circle", "#616161"),
    )
    private val defaultIncomeCategories = listOf(
        Triple("Salario", "banknote", "#2E7D32"), Triple("Transferencias recibidas", "arrow.down.circle", "#00695C"),
        Triple("Otros ingresos", "plus.circle", "#558B2F"),
    )

    fun seedIfNeeded(data: AppData): AppData {
        if (data.categories.isNotEmpty()) return data
        val all = defaultCategories.map { it to false } + defaultIncomeCategories.map { it to true }
        return data.copy(categories = all.mapIndexed { i, (c, income) ->
            Category(newId(), c.first, c.second, c.third, income, i)
        })
    }

    fun categoryName(data: AppData, id: String?): String? = data.categories.firstOrNull { it.id == id }?.name

    fun snapshots(data: AppData): List<MovementSnapshot> =
        data.movements.map { it.snapshot(categoryName(data, it.categoryID)) }

    fun accountInUse(data: AppData, accountId: String): Boolean =
        data.movements.any { it.accountID == accountId || it.destinationAccountID == accountId } ||
            data.recurring.any { it.accountID == accountId }

    // ---------------------------------------------------------------- movimientos

    /** Inserta o reemplaza un movimiento; si queda confirmado intenta enlazarlo con un gasto fijo. */
    fun saveMovement(data: AppData, movement: Movement, zone: ZoneId): AppData {
        val old = data.movements.firstOrNull { it.id == movement.id }
        var current = movement
        var d = data
        // Si ya estaba enlazado a un fijo y deja de ser un gasto confirmado, el fijo vuelve a pendiente.
        val linked = old?.occurrenceID
        if (linked != null && (movement.kind != MovementKind.gasto || movement.status != MovementStatus.confirmado)) {
            d = d.copy(occurrences = d.occurrences.map {
                if (it.id == linked) it.copy(status = OccurrenceStatus.pendiente, movementID = null) else it
            })
            current = current.copy(occurrenceID = null)
        }
        d = d.copy(movements = if (old == null) d.movements + current else d.movements.map { if (it.id == current.id) current else it })
        return if (current.status == MovementStatus.confirmado) linkIfMatches(d, current.id, zone) else d
    }

    /** Borra el movimiento; si estaba enlazado a un fijo, el fijo vuelve a pendiente. */
    fun deleteMovement(data: AppData, id: String): AppData {
        val m = data.movements.firstOrNull { it.id == id } ?: return data
        val occurrences = data.occurrences.map {
            if (it.id == m.occurrenceID) it.copy(status = OccurrenceStatus.pendiente, movementID = null) else it
        }
        return data.copy(movements = data.movements.filter { it.id != id }, occurrences = occurrences)
    }

    // ---------------------------------------------------------------- gastos fijos

    fun ensureMonth(data: AppData, date: Instant, zone: ZoneId): AppData {
        val key = RecurringPlanner.monthKey(date, zone)
        val created = data.occurrences.filter { it.monthKey == key }.map { it.recurringID }.toSet()
        val due = RecurringPlanner.occurrencesToCreate(date, data.recurring.map { it.snapshot() }, created, zone)
        if (due.isEmpty()) return data
        return data.copy(occurrences = data.occurrences + due.map {
            Occurrence(newId(), it.recurringId, key, it.dueDate, OccurrenceStatus.pendiente)
        })
    }

    fun pendingTotal(data: AppData, monthKey: String): Int {
        val byId = data.recurring.associateBy { it.id }
        return data.occurrences.filter { it.monthKey == monthKey && it.status == OccurrenceStatus.pendiente }
            .sumOf { occ -> byId[occ.recurringID]?.takeIf { it.active }?.amount ?: 0 }
    }

    fun markPaid(data: AppData, occurrenceId: String, amount: Int, now: Instant): AppData {
        val occ = data.occurrences.firstOrNull { it.id == occurrenceId } ?: return data
        val r = data.recurring.firstOrNull { it.id == occ.recurringID } ?: return data
        val movement = Movement(
            id = newId(), amount = amount, date = now, kind = MovementKind.gasto, method = r.method,
            accountID = r.accountID, categoryID = r.categoryID, merchant = r.name, source = CaptureSource.fijo,
            status = MovementStatus.confirmado, occurrenceID = occ.id,
        )
        return data.copy(
            movements = data.movements + movement,
            occurrences = data.occurrences.map {
                if (it.id == occurrenceId) it.copy(status = OccurrenceStatus.pagado, movementID = movement.id) else it
            },
        )
    }

    fun skip(data: AppData, occurrenceId: String): AppData = data.copy(occurrences = data.occurrences.map {
        if (it.id == occurrenceId) it.copy(status = OccurrenceStatus.omitido) else it
    })

    /** Vuelve a pendiente. Si el pago lo creó la pantalla de fijos se borra; si vino de otra fuente solo se desenlaza. */
    fun reopen(data: AppData, occurrenceId: String): AppData {
        val occ = data.occurrences.firstOrNull { it.id == occurrenceId } ?: return data
        var movements = data.movements
        val mid = occ.movementID
        if (mid != null) {
            val m = movements.firstOrNull { it.id == mid }
            if (m != null) {
                movements = if (m.source == CaptureSource.fijo) movements.filter { it.id != mid }
                else movements.map { if (it.id == mid) it.copy(occurrenceID = null) else it }
            }
        }
        return data.copy(
            movements = movements,
            occurrences = data.occurrences.map {
                if (it.id == occurrenceId) it.copy(status = OccurrenceStatus.pendiente, movementID = null) else it
            },
        )
    }

    /** Si un gasto confirmado coincide con un fijo pendiente (también del mes vecino), lo marca pagado. */
    fun linkIfMatches(data: AppData, movementId: String, zone: ZoneId): AppData {
        val m = data.movements.firstOrNull { it.id == movementId } ?: return data
        if (m.status != MovementStatus.confirmado || m.kind != MovementKind.gasto || m.occurrenceID != null) return data
        var d = ensureMonth(data, m.date, zone)
        d = ensureMonth(d, m.date.plusSeconds(RecurringPlanner.MATCH_WINDOW_SECONDS), zone)
        val byId = d.recurring.associateBy { it.id }
        val open = d.occurrences.filter { it.status == OccurrenceStatus.pendiente }
        val pending = open.mapNotNull { occ ->
            byId[occ.recurringID]?.takeIf { it.active }?.let { PendingOccurrence(occ.id, it.amount, it.accountID, occ.dueDate) }
        }
        val occId = RecurringPlanner.matchingPending(m.snapshot(), pending) ?: return d
        val recurring = byId[open.first { it.id == occId }.recurringID]
        return d.copy(
            occurrences = d.occurrences.map {
                if (it.id == occId) it.copy(status = OccurrenceStatus.pagado, movementID = m.id) else it
            },
            movements = d.movements.map {
                if (it.id == m.id) it.copy(occurrenceID = occId, categoryID = it.categoryID ?: recurring?.categoryID) else it
            },
        )
    }

    // ---------------------------------------------------------------- captura automática

    /**
     * Registra un aviso (notificación, texto compartido…). [forcedAccountId] fuerza la cuenta
     * cuando el usuario ya asoció la app de origen con una cuenta.
     */
    fun ingestText(
        data: AppData, text: String, sender: String?, source: CaptureSource, now: Instant, zone: ZoneId,
        forcedAccountId: String? = null,
    ): Pair<AppData, CaptureOutcome> {
        val parsed = GenericParser.parse(text, sender)
        val hints = data.accounts.map { it.hint() }
        val accountId = forcedAccountId ?: parsed?.let { AccountMatcher.match(it.bank, it.last4, it.method, sender, hints) }
        val since = now.minusSeconds(86_400)
        val recent = data.movements.filter { it.date >= since }.map { it.snapshot() }

        return when (val decision = CapturePipeline.decide(parsed, accountId, now, recent)) {
            is CaptureDecision.DuplicateOf -> {
                val first = data.movements.firstOrNull { it.id == decision.id }
                if (first == null) {
                    data to CaptureOutcome.Duplicate
                } else {
                    // Se fusiona con el primero: si ese no tenía cuenta y este sí, hereda cuenta y texto.
                    val gainsAccount = first.accountID == null && accountId != null
                    val merged = first.copy(
                        accountID = first.accountID ?: accountId,
                        status = if (gainsAccount && parsed?.isExplicit == true) MovementStatus.confirmado else first.status,
                        merchant = first.merchant ?: parsed?.merchant,
                        rawText = listOfNotNull(first.rawText, text).joinToString("\n---\n"),
                    )
                    saveMovement(data, merged, zone) to CaptureOutcome.Duplicate
                }
            }
            is CaptureDecision.Unreadable -> {
                val movement = Movement(
                    id = newId(), amount = 0, date = now, kind = MovementKind.gasto, method = PaymentMethod.debito,
                    source = source, status = MovementStatus.porRevisar, rawText = text,
                )
                data.copy(movements = data.movements + movement) to CaptureOutcome.Review(movement)
            }
            is CaptureDecision.Create -> {
                val p = parsed!!
                val movement = Movement(
                    id = newId(), amount = p.amount, date = now, kind = p.kind, method = p.method, accountID = accountId,
                    merchant = p.merchant, source = source, status = decision.status, rawText = text,
                )
                val next = saveMovement(data, movement, zone)
                next to if (decision.status == MovementStatus.confirmado) CaptureOutcome.Registered(movement) else CaptureOutcome.Review(movement)
            }
        }
    }

    // ---------------------------------------------------------------- extractos

    fun importStatement(data: AppData, account: Account, entries: List<StatementEntry>, zone: ZoneId): AppData {
        var d = data
        // Un «pago a tu tarjeta» va a la tarjeta de crédito del mismo banco, si es la única.
        val cards = data.accounts.filter { it.kind == AccountKind.credito && it.bank == account.bank && it.id != account.id }
        for (e in entries) {
            val method = when {
                e.kind != MovementKind.gasto -> PaymentMethod.transferencia
                account.kind == AccountKind.credito -> PaymentMethod.credito
                else -> PaymentMethod.debito
            }
            val movement = Movement(
                id = newId(), amount = e.amount, date = e.date, kind = e.kind, method = method, accountID = account.id,
                destinationAccountID = if (e.kind == MovementKind.transferencia && cards.size == 1) cards[0].id else null,
                merchant = e.description.ifEmpty { null }, source = CaptureSource.extracto, status = MovementStatus.confirmado,
            )
            d = saveMovement(d, movement, zone)
        }
        return d
    }
}
