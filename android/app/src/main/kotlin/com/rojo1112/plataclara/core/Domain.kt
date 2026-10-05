package com.rojo1112.plataclara.core

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.YearMonth

// Los nombres de las constantes coinciden con los valores del respaldo JSON del iPhone.

@Serializable
enum class Bank(val label: String) {
    nu("Nu"), dale("Dale!"), uala("Ualá"), lulo("Lulo Bank"), efectivo("Efectivo"), otro("Otro")
}

@Serializable
enum class AccountKind(val label: String) { ahorros("Cuenta de ahorros"), credito("Tarjeta de crédito") }

@Serializable
enum class MovementKind(val label: String) { gasto("Gasto"), ingreso("Ingreso"), transferencia("Transferencia") }

@Serializable
enum class PaymentMethod(val label: String) {
    debito("Tarjeta débito"), credito("Tarjeta crédito"), qr("QR"), llave("Llave Bre-B"),
    transferencia("Transferencia"), efectivo("Efectivo")
}

@Serializable
enum class CaptureSource(val label: String) {
    manual("Manual"), correo("Correo"), applePay("Apple Pay"), captura("Captura"), fijo("Gasto fijo"),
    extracto("Extracto")
}

@Serializable
enum class MovementStatus(val label: String) { confirmado("Confirmado"), porRevisar("Por revisar") }

@Serializable
enum class OccurrenceStatus(val label: String) { pendiente("Pendiente"), pagado("Pagado"), omitido("Omitido") }

object Money {
    /** 1234567 -> "$ 1.234.567"; -5000 -> "-$ 5.000". */
    fun format(amount: Int): String {
        val digits = Math.abs(amount.toLong()).toString()
        val grouped = digits.reversed().chunked(3).joinToString(".").reversed()
        return (if (amount < 0) "-" else "") + "\$ " + grouped
    }
}

data class AccountSnapshot(val id: String, val kind: AccountKind, val openingBalance: Int)

data class MovementSnapshot(
    val id: String,
    val amount: Int,
    val date: Instant,
    val kind: MovementKind,
    val method: PaymentMethod,
    val accountId: String?,
    val destinationAccountId: String? = null,
    val categoryName: String? = null,
    val status: MovementStatus = MovementStatus.confirmado,
)

object Ledger {
    /** Ahorros: dinero disponible. Crédito: deuda (positivo = lo que debes). */
    fun balance(account: AccountSnapshot, movements: List<MovementSnapshot>): Int =
        movements.filter { it.status == MovementStatus.confirmado }
            .fold(account.openingBalance) { total, m -> total + effect(m, account) }

    fun totalCash(accounts: List<AccountSnapshot>, movements: List<MovementSnapshot>): Int =
        accounts.filter { it.kind == AccountKind.ahorros }.sumOf { balance(it, movements) }

    fun totalDebt(accounts: List<AccountSnapshot>, movements: List<MovementSnapshot>): Int =
        accounts.filter { it.kind == AccountKind.credito }.sumOf { balance(it, movements) }

    private fun effect(m: MovementSnapshot, account: AccountSnapshot): Int {
        var delta = 0
        if (m.accountId == account.id) delta += if (m.kind == MovementKind.ingreso) m.amount else -m.amount
        if (m.kind == MovementKind.transferencia && m.destinationAccountId == account.id) delta += m.amount
        return if (account.kind == AccountKind.ahorros) delta else -delta
    }
}

enum class MovementValidationError(val message: String) {
    montoInvalido("El monto debe ser mayor que cero."),
    faltaCuenta("Elige la cuenta."),
    faltaDestino("Elige la cuenta de destino."),
    mismaCuenta("La cuenta de origen y la de destino deben ser distintas."),
}

object MovementValidator {
    fun validate(amount: Int, kind: MovementKind, accountId: String?, destinationId: String?): List<MovementValidationError> {
        val errors = mutableListOf<MovementValidationError>()
        if (amount <= 0) errors += MovementValidationError.montoInvalido
        if (accountId == null) errors += MovementValidationError.faltaCuenta
        if (kind == MovementKind.transferencia) {
            if (destinationId == null) errors += MovementValidationError.faltaDestino
            else if (destinationId == accountId) errors += MovementValidationError.mismaCuenta
        }
        return errors
    }
}

data class Interval(val start: Instant, val end: Instant) {
    fun contains(date: Instant) = date >= start && date < end
}

data class MonthSummary(val income: Int, val expenses: Int, val pendingFixed: Int) {
    val saved: Int get() = income - expenses
    val possibleSaving: Int get() = saved - pendingFixed
    val savingsRate: Double get() = if (income > 0) saved.toDouble() / income else 0.0
}

data class CategoryTotal(val name: String, val amount: Int)
data class MethodTotal(val method: PaymentMethod, val amount: Int)

object Stats {
    const val UNCATEGORIZED = "Sin categoría"

    fun monthInterval(date: Instant, zone: ZoneId): Interval {
        val month = YearMonth.from(date.atZone(zone))
        return Interval(
            month.atDay(1).atStartOfDay(zone).toInstant(),
            month.plusMonths(1).atDay(1).atStartOfDay(zone).toInstant(),
        )
    }

    private fun confirmed(ms: List<MovementSnapshot>, interval: Interval) =
        ms.filter { it.status == MovementStatus.confirmado && interval.contains(it.date) }

    private fun expenses(ms: List<MovementSnapshot>, interval: Interval) =
        confirmed(ms, interval).filter { it.kind == MovementKind.gasto }

    fun summary(movements: List<MovementSnapshot>, interval: Interval, pendingFixed: Int): MonthSummary {
        val ms = confirmed(movements, interval)
        return MonthSummary(
            income = ms.filter { it.kind == MovementKind.ingreso }.sumOf { it.amount },
            expenses = ms.filter { it.kind == MovementKind.gasto }.sumOf { it.amount },
            pendingFixed = pendingFixed,
        )
    }

    fun expensesByCategory(movements: List<MovementSnapshot>, interval: Interval): List<CategoryTotal> =
        expenses(movements, interval).groupBy { it.categoryName ?: UNCATEGORIZED }
            .map { CategoryTotal(it.key, it.value.sumOf { m -> m.amount }) }
            .sortedWith(compareByDescending<CategoryTotal> { it.amount }.thenBy { it.name })

    fun expensesByMethod(movements: List<MovementSnapshot>, interval: Interval): List<MethodTotal> =
        expenses(movements, interval).groupBy { it.method }
            .map { MethodTotal(it.key, it.value.sumOf { m -> m.amount }) }
            .sortedWith(compareByDescending<MethodTotal> { it.amount }.thenBy { it.method.name })

    fun averageDailyExpense(expenses: Int, interval: Interval, today: Instant, zone: ZoneId): Int {
        val first = interval.start.atZone(zone).toLocalDate()
        val total = java.time.temporal.ChronoUnit.DAYS.between(first, interval.end.atZone(zone).toLocalDate()).toInt()
        val days = when {
            today >= interval.end -> total
            today < interval.start -> 1
            else -> java.time.temporal.ChronoUnit.DAYS.between(first, today.atZone(zone).toLocalDate()).toInt() + 1
        }
        return expenses / maxOf(days, 1)
    }
}

data class RecurringSnapshot(
    val id: String, val name: String, val amount: Int, val dayOfMonth: Int, val accountId: String?, val active: Boolean,
)

data class DueOccurrence(val recurringId: String, val dueDate: Instant)

data class PendingOccurrence(val id: String, val amount: Int, val accountId: String?, val dueDate: Instant)

object RecurringPlanner {
    const val MATCH_WINDOW_SECONDS = 5L * 86_400

    fun monthKey(date: Instant, zone: ZoneId): String {
        val m = YearMonth.from(date.atZone(zone))
        return "%04d-%02d".format(m.year, m.monthValue)
    }

    /** Vencimiento a medianoche; el día 31 en un mes más corto cae en el último día. */
    fun dueDate(day: Int, monthOf: Instant, zone: ZoneId): Instant {
        val month = YearMonth.from(monthOf.atZone(zone))
        val clamped = day.coerceIn(1, month.lengthOfMonth())
        return month.atDay(clamped).atStartOfDay(zone).toInstant()
    }

    fun occurrencesToCreate(
        month: Instant, recurring: List<RecurringSnapshot>, alreadyCreated: Set<String>, zone: ZoneId,
    ): List<DueOccurrence> =
        recurring.filter { it.active && it.id !in alreadyCreated }
            .map { DueOccurrence(it.id, dueDate(it.dayOfMonth, month, zone)) }

    /** Fijo pendiente que corresponde a este gasto: monto ±10 %, misma cuenta (si ambas se conocen), ≤ 5 días. */
    fun matchingPending(movement: MovementSnapshot, pending: List<PendingOccurrence>): String? {
        if (movement.kind != MovementKind.gasto) return null
        return pending.filter { p ->
            if (p.accountId != null && movement.accountId != null && p.accountId != movement.accountId) return@filter false
            val tolerance = maxOf(p.amount / 10, 1)
            if (Math.abs(movement.amount - p.amount) > tolerance) return@filter false
            Math.abs(movement.date.epochSecond - p.dueDate.epochSecond) <= MATCH_WINDOW_SECONDS
        }.minByOrNull { Math.abs(it.amount - movement.amount) }?.id
    }
}
