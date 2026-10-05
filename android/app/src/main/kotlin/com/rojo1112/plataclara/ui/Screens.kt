package com.rojo1112.plataclara.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.AccountKind
import com.rojo1112.plataclara.core.AppData
import com.rojo1112.plataclara.core.Ledger
import com.rojo1112.plataclara.core.Money
import com.rojo1112.plataclara.core.Movement
import com.rojo1112.plataclara.core.MovementKind
import com.rojo1112.plataclara.core.MovementStatus
import com.rojo1112.plataclara.core.OccurrenceStatus
import com.rojo1112.plataclara.core.RecurringPlanner
import com.rojo1112.plataclara.core.Stats
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

private val green = Color(0xFF2E7D32)
private val orange = Color(0xFFEF6C00)

@Composable
fun HomeScreen(data: AppData, onAdd: () -> Unit) {
    val zone = ZoneId.systemDefault()
    val snapshots = Actions.snapshots(data)
    val accounts = data.accounts.map { it.snapshot() }
    val key = RecurringPlanner.monthKey(Instant.now(), zone)
    val pending = Actions.pendingTotal(data, key)
    val summary = Stats.summary(snapshots, Stats.monthInterval(Instant.now(), zone), pending)
    val toReview = data.movements.count { it.status == MovementStatus.porRevisar }
    val error = MaterialTheme.colorScheme.error

    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("PlataClara", style = MaterialTheme.typography.headlineSmall)
                Button(onClick = onAdd) { Text("+ Movimiento") }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    TextRow("Dinero disponible", Money.format(Ledger.totalCash(accounts, snapshots)), bold = true)
                    TextRow("Deuda en tarjetas", Money.format(Ledger.totalDebt(accounts, snapshots)), error, bold = true)
                }
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    SectionTitle("Este mes")
                    TextRow("Ingresos", Money.format(summary.income), green)
                    TextRow("Gastos", Money.format(summary.expenses))
                    TextRow("Ahorro", Money.format(summary.saved), if (summary.saved < 0) error else Color.Unspecified)
                    TextRow("Fijos pendientes", Money.format(pending), orange)
                    TextRow("Ahorro posible", Money.format(summary.possibleSaving), if (summary.possibleSaving < 0) error else green, bold = true)
                }
            }
        }
        if (toReview > 0) item { Text("$toReview movimiento(s) por revisar", color = orange) }
        item { SectionTitle("Cuentas") }
        if (data.accounts.isEmpty()) item { Hint("Agrega tu primera cuenta en Ajustes › Cuentas.") }
        items(data.accounts, key = { it.id }) { account ->
            val balance = Ledger.balance(account.snapshot(), snapshots)
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    TextRow(account.name, Money.format(balance), if (account.kind == AccountKind.credito) error else Color.Unspecified, bold = true)
                    val limit = account.creditLimit
                    if (account.kind == AccountKind.credito && limit != null && limit > 0) Hint("Cupo disponible: ${Money.format(limit - balance)}")
                }
            }
        }
        item { Box(Modifier.height(16.dp)) }
    }
}

@Composable
fun MovementRow(m: Movement, data: AppData, onClick: () -> Unit) {
    val zone = ZoneId.systemDefault()
    val category = data.categories.firstOrNull { it.id == m.categoryID }
    val account = data.accounts.firstOrNull { it.id == m.accountID }
    val sign = when (m.kind) { MovementKind.ingreso -> "+"; MovementKind.gasto -> "-"; MovementKind.transferencia -> "" }
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(m.merchant ?: category?.name ?: m.kind.label, maxLines = 1)
            Hint("${m.method.label} · ${account?.name ?: "Sin cuenta"} · ${m.date.atZone(zone).format(listFormat)}")
        }
        Text(
            sign + Money.format(m.amount),
            color = when (m.kind) { MovementKind.ingreso -> green; else -> Color.Unspecified },
        )
    }
}

@Composable
fun MovementsScreen(data: AppData, onEdit: (Movement) -> Unit, onAdd: () -> Unit) {
    var accountFilter by remember { mutableStateOf<String?>(null) }
    val visible = data.movements
        .filter { it.status == MovementStatus.confirmado }
        .filter { accountFilter == null || it.accountID == accountFilter || it.destinationAccountID == accountFilter }
        .sortedByDescending { it.date }

    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Movimientos", style = MaterialTheme.typography.headlineSmall)
                Button(onClick = onAdd) { Text("+ Nuevo") }
            }
        }
        item {
            Picker("Cuenta", accountFilter, listOf<Pair<String?, String>>(null to "Todas") + data.accounts.map { it.id to it.name }, { accountFilter = it })
        }
        if (visible.isEmpty()) item { Empty("Sin movimientos. Toca «+ Nuevo» para registrar uno.") }
        items(visible, key = { it.id }) { m ->
            MovementRow(m, data) { onEdit(m) }
            HorizontalDivider()
        }
    }
}

@Composable
fun ReviewScreen(data: AppData, onEdit: (Movement) -> Unit) {
    val items = data.movements.filter { it.status == MovementStatus.porRevisar }.sortedByDescending { it.date }
    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        item { Text("Por revisar", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(top = 16.dp)) }
        item { Hint("Aquí llegan los avisos que la app no pudo registrar sola. Tócalos para corregirlos y confirmarlos.") }
        if (items.isEmpty()) item { Empty("Todo al día") }
        items(items, key = { it.id }) { m ->
            Column(Modifier.clickable { onEdit(m) }) {
                MovementRow(m, data) { onEdit(m) }
                m.rawText?.let { Hint(it.take(160)) }
            }
            HorizontalDivider()
        }
    }
}

@Composable
fun FixedScreen(
    data: AppData,
    onAdd: () -> Unit,
    onEdit: (com.rojo1112.plataclara.core.Recurring) -> Unit,
    onPay: (com.rojo1112.plataclara.core.Occurrence) -> Unit,
    onSkip: (com.rojo1112.plataclara.core.Occurrence) -> Unit,
    onReopen: (com.rojo1112.plataclara.core.Occurrence) -> Unit,
) {
    val zone = ZoneId.systemDefault()
    val key = RecurringPlanner.monthKey(Instant.now(), zone)
    val thisMonth = data.occurrences.filter { it.monthKey == key }.sortedBy { it.dueDate }
    val byId = data.recurring.associateBy { it.id }

    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text("Gastos fijos", style = MaterialTheme.typography.headlineSmall)
                Button(onClick = onAdd) { Text("+ Nuevo") }
            }
        }
        item { TextRow("Pendiente este mes", Money.format(Actions.pendingTotal(data, key)), orange, bold = true) }
        item { SectionTitle("Este mes") }
        if (thisMonth.isEmpty()) item { Empty("Agrega arriendo, servicios, suscripciones… lo que pagas sí o sí cada mes.") }
        items(thisMonth, key = { it.id }) { occ ->
            val r = byId[occ.recurringID]
            if (r != null) {
                Column(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                    TextRow(r.name, Money.format(r.amount), bold = occ.status == OccurrenceStatus.pendiente)
                    Hint("${occ.status.label} · vence el ${occ.dueDate.atZone(zone).format(dayFormat)}")
                    Row {
                        if (occ.status == OccurrenceStatus.pendiente) {
                            TextButton(onClick = { onPay(occ) }) { Text("Marcar pagado") }
                            TextButton(onClick = { onSkip(occ) }) { Text("Omitir") }
                        } else {
                            TextButton(onClick = { onReopen(occ) }) { Text("Reabrir") }
                        }
                    }
                }
                HorizontalDivider()
            }
        }
        item { SectionTitle("Todos mis fijos") }
        items(data.recurring.sortedBy { it.dayOfMonth }, key = { "r" + it.id }) { r ->
            Row(Modifier.fillMaxWidth().clickable { onEdit(r) }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(r.name)
                    Hint("Día ${r.dayOfMonth} · ${r.method.label}${if (r.active) "" else " · inactivo"}")
                }
                Text(Money.format(r.amount))
            }
        }
        item { Box(Modifier.height(16.dp)) }
    }
}

@Composable
fun StatsScreen(data: AppData) {
    val zone = ZoneId.systemDefault()
    var offset by remember { mutableIntStateOf(0) }
    val reference: ZonedDateTime = ZonedDateTime.now(zone).plusMonths(offset.toLong())
    val refInstant = reference.toInstant()
    val month = Stats.monthInterval(refInstant, zone)
    val snapshots = Actions.snapshots(data)
    val pending = Actions.pendingTotal(data, RecurringPlanner.monthKey(refInstant, zone))
    val summary = Stats.summary(snapshots, month, pending)
    val byCategory = Stats.expensesByCategory(snapshots, month)
    val byMethod = Stats.expensesByMethod(snapshots, month)
    val history = (5 downTo 0).map { back ->
        val d = reference.minusMonths(back.toLong())
        d to Stats.summary(snapshots, Stats.monthInterval(d.toInstant(), zone), 0)
    }
    val maxHistory = history.maxOf { maxOf(it.second.income, it.second.expenses) }.coerceAtLeast(1)

    LazyColumn(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        item { Text("Estadísticas", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(top = 16.dp)) }
        item {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = { offset -= 1 }) { Text("‹") }
                Text(reference.format(java.time.format.DateTimeFormatter.ofPattern("MMMM yyyy", java.util.Locale("es", "CO"))), style = MaterialTheme.typography.titleMedium)
                OutlinedButton(onClick = { offset += 1 }, enabled = offset < 0) { Text("›") }
            }
        }
        item { SectionTitle("Resumen") }
        item { TextRow("Ingresos", Money.format(summary.income)) }
        item { TextRow("Gastos", Money.format(summary.expenses)) }
        item { TextRow("Ahorro", Money.format(summary.saved)) }
        item { TextRow("Ahorro posible", Money.format(summary.possibleSaving)) }
        item { TextRow("Tasa de ahorro", "${Math.round(summary.savingsRate * 100)} %") }
        item { TextRow("Gasto diario promedio", Money.format(Stats.averageDailyExpense(summary.expenses, month, Instant.now(), zone))) }

        item { SectionTitle("Gastos por categoría") }
        if (byCategory.isEmpty()) item { Hint("Sin gastos este mes") }
        val maxCategory = byCategory.maxOfOrNull { it.amount }?.coerceAtLeast(1) ?: 1
        items(byCategory, key = { "c" + it.name }) { c ->
            Column(Modifier.padding(vertical = 4.dp)) {
                TextRow(c.name, Money.format(c.amount))
                Bar(c.amount.toFloat() / maxCategory, MaterialTheme.colorScheme.primary)
            }
        }

        item { SectionTitle("Por método de pago") }
        items(byMethod, key = { "m" + it.method.name }) { TextRow(it.method.label, Money.format(it.amount)) }

        item { SectionTitle("Últimos 6 meses") }
        items(history, key = { "h" + it.first.toString() }) { (d, s) ->
            Column(Modifier.padding(vertical = 4.dp)) {
                Text(d.format(java.time.format.DateTimeFormatter.ofPattern("MMM yyyy", java.util.Locale("es", "CO"))), style = MaterialTheme.typography.labelMedium)
                Bar(s.income.toFloat() / maxHistory, green)
                Bar(s.expenses.toFloat() / maxHistory, MaterialTheme.colorScheme.error)
            }
        }
        item { Hint("Verde: ingresos · Rojo: gastos") }
        item { Box(Modifier.height(16.dp)) }
    }
}

@Composable
private fun Bar(fraction: Float, color: Color) {
    Box(Modifier.fillMaxWidth().height(8.dp).background(MaterialTheme.colorScheme.surfaceVariant)) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).height(8.dp).background(color))
    }
}
