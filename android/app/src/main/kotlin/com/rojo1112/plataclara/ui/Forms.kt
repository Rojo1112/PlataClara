package com.rojo1112.plataclara.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.rojo1112.plataclara.core.Account
import com.rojo1112.plataclara.core.AccountKind
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.AppData
import com.rojo1112.plataclara.core.Bank
import com.rojo1112.plataclara.core.CaptureSource
import com.rojo1112.plataclara.core.Movement
import com.rojo1112.plataclara.core.MovementKind
import com.rojo1112.plataclara.core.MovementStatus
import com.rojo1112.plataclara.core.MovementValidator
import com.rojo1112.plataclara.core.PaymentMethod
import com.rojo1112.plataclara.core.Recurring
import java.time.Instant
import java.time.ZoneId

@Composable
fun MovementDialog(
    data: AppData,
    initial: Movement?,
    onDismiss: () -> Unit,
    onSave: (Movement) -> Unit,
    onDelete: ((Movement) -> Unit)?,
) {
    val zone = ZoneId.systemDefault()
    val isReview = initial?.status == MovementStatus.porRevisar
    var kind by remember { mutableStateOf(initial?.kind ?: MovementKind.gasto) }
    var amount by remember { mutableIntStateOf(initial?.amount ?: 0) }
    var method by remember { mutableStateOf(initial?.method ?: PaymentMethod.debito) }
    var accountId by remember { mutableStateOf(initial?.accountID ?: data.accounts.singleOrNull()?.id) }
    var destinationId by remember { mutableStateOf(initial?.destinationAccountID) }
    var categoryId by remember { mutableStateOf(initial?.categoryID) }
    var merchant by remember { mutableStateOf(initial?.merchant ?: "") }
    var note by remember { mutableStateOf(initial?.note ?: "") }
    var dateText by remember { mutableStateOf(formatInput(initial?.date ?: Instant.now(), zone)) }
    var errors by remember { mutableStateOf(emptyList<String>()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "Nuevo movimiento" else if (isReview) "Revisar" else "Editar movimiento") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (isReview && initial?.rawText != null) {
                    Text("Texto recibido:", style = MaterialTheme.typography.labelMedium)
                    Text(initial.rawText, style = MaterialTheme.typography.bodySmall)
                }
                Picker("Tipo", kind, MovementKind.values().map { it to it.label }, { kind = it ?: kind })
                AmountField("Monto", amount) { amount = it }
                if (kind != MovementKind.transferencia) {
                    Picker("Método", method, PaymentMethod.values().map { it to it.label }, { method = it ?: method })
                }
                Picker(
                    if (kind == MovementKind.transferencia) "Desde" else "Cuenta", accountId,
                    data.accounts.map { it.id to it.name },
                    { id ->
                        accountId = id
                        val account = data.accounts.firstOrNull { it.id == id }
                        if (kind == MovementKind.gasto && account != null) {
                            if (account.kind == AccountKind.credito) method = PaymentMethod.credito
                            else if (method == PaymentMethod.credito) method = PaymentMethod.debito
                        }
                    },
                )
                if (kind == MovementKind.transferencia) {
                    Picker("Hacia", destinationId, data.accounts.map { it.id to it.name }, { destinationId = it })
                    Text("Para pagar una tarjeta de crédito elige la tarjeta en «Hacia». No cuenta como gasto.", style = MaterialTheme.typography.bodySmall)
                } else {
                    Picker(
                        "Categoría", categoryId,
                        listOf<Pair<String?, String>>(null to "Sin categoría") +
                            data.categories.filter { it.isIncome == (kind == MovementKind.ingreso) }.map { it.id to it.name },
                        { categoryId = it },
                    )
                    OutlinedTextField(
                        merchant, { merchant = it }, label = { Text(if (kind == MovementKind.ingreso) "De quién" else "Comercio o destinatario") },
                        singleLine = true, modifier = Modifier.fillMaxWidth(),
                    )
                }
                OutlinedTextField(dateText, { dateText = it }, label = { Text("Fecha (aaaa-mm-dd hh:mm)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(note, { note = it }, label = { Text("Nota") }, modifier = Modifier.fillMaxWidth())
                errors.forEach { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val destination = if (kind == MovementKind.transferencia) destinationId else null
                val problems = MovementValidator.validate(amount, kind, accountId, destination).map { it.message }.toMutableList()
                val date = parseInput(dateText, zone)
                if (date == null) problems += "La fecha debe tener el formato aaaa-mm-dd hh:mm."
                errors = problems
                if (problems.isEmpty() && date != null) {
                    onSave(
                        Movement(
                            id = initial?.id ?: Actions.newId(), amount = amount, date = date, kind = kind,
                            method = if (kind == MovementKind.transferencia) PaymentMethod.transferencia else method,
                            accountID = accountId, destinationAccountID = destination,
                            categoryID = if (kind == MovementKind.transferencia) null else categoryId,
                            merchant = merchant.trim().ifEmpty { null }, note = note.trim().ifEmpty { null },
                            source = initial?.source ?: CaptureSource.manual, status = MovementStatus.confirmado,
                            rawText = initial?.rawText, occurrenceID = initial?.occurrenceID,
                        ),
                    )
                }
            }) { Text(if (isReview) "Confirmar" else "Guardar") }
        },
        dismissButton = {
            Row {
                if (onDelete != null && initial != null) TextButton(onClick = { onDelete(initial) }) { Text("Borrar") }
                TextButton(onClick = onDismiss) { Text("Cancelar") }
            }
        },
    )
}

@Composable
fun RecurringDialog(data: AppData, initial: Recurring?, onDismiss: () -> Unit, onSave: (Recurring) -> Unit, onDelete: ((Recurring) -> Unit)?) {
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var amount by remember { mutableIntStateOf(initial?.amount ?: 0) }
    var day by remember { mutableIntStateOf(initial?.dayOfMonth ?: 1) }
    var accountId by remember { mutableStateOf(initial?.accountID) }
    var method by remember { mutableStateOf(initial?.method ?: PaymentMethod.debito) }
    var categoryId by remember { mutableStateOf(initial?.categoryID) }
    var active by remember { mutableStateOf(initial?.active ?: true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "Nuevo gasto fijo" else "Editar gasto fijo") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Nombre (ej. Arriendo)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                AmountField("Monto", amount) { amount = it }
                NumberField("Día del mes (1-31)", day) { day = it }
                Picker("Cuenta", accountId, listOf<Pair<String?, String>>(null to "Sin definir") + data.accounts.map { it.id to it.name }, { accountId = it })
                Picker("Método", method, PaymentMethod.values().map { it to it.label }, { method = it ?: method })
                Picker(
                    "Categoría", categoryId,
                    listOf<Pair<String?, String>>(null to "Sin categoría") + data.categories.filter { !it.isIncome }.map { it.id to it.name },
                    { categoryId = it },
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Switch(checked = active, onCheckedChange = { active = it })
                    Text("Activo")
                }
            }
        },
        confirmButton = {
            TextButton(
                enabled = name.isNotBlank() && amount > 0 && day in 1..31,
                onClick = {
                    onSave(
                        Recurring(
                            id = initial?.id ?: Actions.newId(), name = name.trim(), amount = amount, dayOfMonth = day,
                            accountID = accountId, method = method, categoryID = categoryId, active = active,
                            remind = initial?.remind ?: true,
                        ),
                    )
                },
            ) { Text("Guardar") }
        },
        dismissButton = {
            Row {
                if (onDelete != null && initial != null) TextButton(onClick = { onDelete(initial) }) { Text("Borrar") }
                TextButton(onClick = onDismiss) { Text("Cancelar") }
            }
        },
    )
}

@Composable
fun PayDialog(name: String, suggested: Int, onDismiss: () -> Unit, onPay: (Int) -> Unit) {
    var amount by remember { mutableIntStateOf(suggested) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(name) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                AmountField("Monto pagado", amount) { amount = it }
                Text("Si este mes el valor cambió (por ejemplo, servicios), corrígelo aquí.", style = MaterialTheme.typography.bodySmall)
            }
        },
        confirmButton = { TextButton(enabled = amount > 0, onClick = { onPay(amount) }) { Text("Marcar pagado") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}

@Composable
fun AccountDialog(initial: Account?, onDismiss: () -> Unit, onSave: (Account) -> Unit) {
    var name by remember { mutableStateOf(initial?.name ?: "") }
    var bank by remember { mutableStateOf(initial?.bank ?: Bank.nu) }
    var kind by remember { mutableStateOf(initial?.kind ?: AccountKind.ahorros) }
    var opening by remember { mutableIntStateOf(initial?.openingBalance ?: 0) }
    var limit by remember { mutableIntStateOf(initial?.creditLimit ?: 0) }
    var cutoff by remember { mutableIntStateOf(initial?.cutoffDay ?: 1) }
    var payment by remember { mutableIntStateOf(initial?.paymentDay ?: 15) }
    var last4 by remember { mutableStateOf(initial?.last4?.joinToString(", ") ?: "") }
    var senders by remember { mutableStateOf(initial?.emailSenders?.joinToString(", ") ?: "") }

    fun split(text: String) = text.split(",").map { it.trim() }.filter { it.isNotEmpty() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (initial == null) "Nueva cuenta" else "Editar cuenta") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(name, { name = it }, label = { Text("Nombre (ej. Nu ahorros)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                Picker("Banco", bank, Bank.values().map { it to it.label }, { bank = it ?: bank })
                Picker("Tipo", kind, AccountKind.values().map { it to it.label }, { kind = it ?: kind })
                AmountField(if (kind == AccountKind.credito) "Deuda actual" else "Saldo actual", opening) { opening = it }
                if (kind == AccountKind.credito) {
                    AmountField("Cupo", limit) { limit = it }
                    NumberField("Día de corte", cutoff) { cutoff = it }
                    NumberField("Día de pago", payment) { payment = it }
                }
                OutlinedTextField(
                    last4, { last4 = it }, label = { Text("Últimos 4 dígitos de tarjetas (coma)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text), singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    senders, { senders = it }, label = { Text("Remitentes o apps del banco (coma)") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            TextButton(
                enabled = name.isNotBlank(),
                onClick = {
                    onSave(
                        Account(
                            id = initial?.id ?: Actions.newId(), name = name.trim(), bank = bank, kind = kind,
                            openingBalance = opening, creditLimit = if (kind == AccountKind.credito) limit else null,
                            cutoffDay = if (kind == AccountKind.credito) cutoff else null,
                            paymentDay = if (kind == AccountKind.credito) payment else null,
                            last4 = split(last4), walletCardName = initial?.walletCardName, emailSenders = split(senders),
                            createdAt = initial?.createdAt ?: Instant.now(),
                        ),
                    )
                },
            ) { Text("Guardar") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
    )
}
