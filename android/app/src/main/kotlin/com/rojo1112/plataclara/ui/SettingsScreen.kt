package com.rojo1112.plataclara.ui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.rojo1112.plataclara.core.Account
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.AppData
import com.rojo1112.plataclara.core.BackupCodec
import com.rojo1112.plataclara.core.BackupException
import com.rojo1112.plataclara.core.Category
import com.rojo1112.plataclara.core.Money
import com.rojo1112.plataclara.core.MovementKind
import com.rojo1112.plataclara.core.StatementEntry
import com.rojo1112.plataclara.core.StatementParser
import com.rojo1112.plataclara.core.StatementReconciler
import com.rojo1112.plataclara.data.BackupFolder
import com.rojo1112.plataclara.data.Graph
import com.rojo1112.plataclara.data.Prefs
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

private fun readText(context: Context, uri: Uri): ByteArray? =
    context.contentResolver.openInputStream(uri)?.use { it.readBytes() }

/** UTF-8 y, si hay caracteres inválidos, ISO-8859-1 (muchos CSV de bancos). */
private fun decodeText(bytes: ByteArray): String {
    val utf8 = bytes.toString(Charsets.UTF_8)
    return if (utf8.contains('�')) bytes.toString(Charsets.ISO_8859_1) else utf8
}

@Composable
fun SettingsScreen(data: AppData) {
    val context = LocalContext.current
    var message by remember { mutableStateOf<String?>(null) }
    var accountDialog by remember { mutableStateOf<Account?>(null) }
    var creatingAccount by remember { mutableStateOf(false) }
    var pendingRestore by remember { mutableStateOf<AppData?>(null) }
    var tick by remember { mutableIntStateOf(0) }

    LifecycleResumeEffect(Unit) {
        tick += 1
        onPauseOrDispose {}
    }

    fun backupNow(): Boolean = BackupFolder.autoBackup(context, Graph.store.data.value)

    val pickFolder = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) {
            try {
                BackupFolder.setFolder(context, uri)
                val existing = BackupFolder.latestName(context)
                val saved = backupNow()
                message = if (existing != null && !saved) {
                    "Carpeta elegida. Encontré respaldos anteriores: toca «Restaurar el último respaldo» para recuperar tus datos."
                } else {
                    "Carpeta elegida. El respaldo se guardará automáticamente."
                }
            } catch (e: Exception) {
                message = "No se pudo usar esa carpeta: ${e.message}"
            }
            tick += 1
        }
    }
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) {
            try {
                context.contentResolver.openOutputStream(uri, "wt")?.use {
                    it.write(BackupCodec.encode(Graph.store.data.value.copy(exportedAt = Instant.now())).toByteArray(Charsets.UTF_8))
                }
                message = "Respaldo guardado."
            } catch (e: Exception) {
                message = "No se pudo guardar el respaldo: ${e.message}"
            }
        }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            try {
                pendingRestore = BackupCodec.decode(decodeText(readText(context, uri) ?: ByteArray(0)))
            } catch (e: BackupException.UnsupportedVersion) {
                message = "El archivo usa un formato no compatible (versión ${e.version}). No se cambió nada."
            } catch (e: Exception) {
                message = "El archivo no es un respaldo válido. No se cambió nada."
            }
        }
    }

    Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("Ajustes", style = MaterialTheme.typography.headlineSmall)

        // ------------------------------------------------------------ cuentas
        SectionTitle("Cuentas")
        if (data.accounts.isEmpty()) Hint("Agrega tus cuentas de Nu, Dale!, Ualá o Lulo Bank.")
        data.accounts.forEach { account ->
            Row(Modifier.fillMaxWidth().clickable { accountDialog = account }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(account.name)
                    Hint("${account.bank.label} · ${account.kind.label}")
                }
                TextButton(onClick = {
                    if (Actions.accountInUse(Graph.store.data.value, account.id)) {
                        message = "Esta cuenta tiene movimientos o gastos fijos. Bórralos o cámbialos de cuenta antes."
                    } else {
                        Graph.store.update { it.copy(accounts = it.accounts.filter { a -> a.id != account.id }) }
                    }
                }) { Text("Borrar") }
            }
            HorizontalDivider()
        }
        OutlinedButton(onClick = { creatingAccount = true }) { Text("+ Agregar cuenta") }

        // ------------------------------------------------------------ categorías
        SectionTitle("Categorías")
        CategoriesSection(data)

        // ------------------------------------------------------------ notificaciones
        SectionTitle("Registro automático (notificaciones)")
        NotificationsSection(data, tick)

        // ------------------------------------------------------------ respaldo
        SectionTitle("Respaldo automático")
        Hint("Elige una carpeta (en el teléfono o en tu nube). La app guarda ahí una copia cada vez que la cierras y después de cada registro automático, y conserva las 7 últimas. Si desinstalas PlataClara, vuelve a elegir la misma carpeta y restaura.")
        val hasFolder = BackupFolder.hasFolder(context)
        Text(if (hasFolder) "Carpeta elegida" else "Sin carpeta", modifier = Modifier.padding(top = 8.dp))
        val last = BackupFolder.lastBackup(context)
        if (last > 0) Hint("Último respaldo: ${java.time.Instant.ofEpochMilli(last).atZone(ZoneId.systemDefault()).format(listFormat)}")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
            OutlinedButton(onClick = { pickFolder.launch(null) }) { Text(if (hasFolder) "Cambiar carpeta" else "Elegir carpeta") }
            if (hasFolder) {
                OutlinedButton(onClick = {
                    message = if (backupNow()) "Respaldo guardado en la carpeta." else "No se pudo guardar (¿aún no hay datos o la carpeta ya no está disponible?)."
                    tick += 1
                }) { Text("Respaldar ahora") }
            }
        }
        if (hasFolder) {
            TextButton(onClick = {
                try {
                    pendingRestore = BackupFolder.readLatest(context)
                } catch (e: BackupException.UnsupportedVersion) {
                    message = "El respaldo usa un formato no compatible (versión ${e.version}). No se cambió nada."
                } catch (e: Exception) {
                    message = e.message ?: "No se pudo leer el respaldo."
                }
            }) { Text("Restaurar el último respaldo de la carpeta") }
        }

        SectionTitle("Respaldo manual")
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = { exportLauncher.launch("PlataClara-respaldo.json") }) { Text("Exportar") }
            OutlinedButton(onClick = { importLauncher.launch(arrayOf("*/*")) }) { Text("Importar") }
        }
        Hint("Usa el mismo formato que la app del iPhone: puedes pasar tus datos de un sistema al otro.")

        // ------------------------------------------------------------ extractos
        SectionTitle("Importar extracto bancario")
        StatementSection(data)

        SectionTitle("Acerca de")
        Hint("PlataClara 0.3.1 · Todo se guarda en tu teléfono. Sin servidor, sin cuenta, sin analítica.")
        Box(Modifier.height(24.dp))
    }

    if (creatingAccount) {
        AccountDialog(null, onDismiss = { creatingAccount = false }, onSave = { saved ->
            Graph.store.update { it.copy(accounts = it.accounts + saved) }
            creatingAccount = false
        })
    }
    accountDialog?.let { current ->
        AccountDialog(current, onDismiss = { accountDialog = null }, onSave = { saved ->
            Graph.store.update { d -> d.copy(accounts = d.accounts.map { if (it.id == saved.id) saved else it }) }
            accountDialog = null
        })
    }
    pendingRestore?.let { restored ->
        AlertDialog(
            onDismissRequest = { pendingRestore = null },
            title = { Text("¿Reemplazar todos los datos?") },
            text = { Text("Se cargarán ${restored.accounts.size} cuentas y ${restored.movements.size} movimientos del respaldo, y se perderán los datos actuales.") },
            confirmButton = {
                TextButton(onClick = {
                    Graph.store.replaceAll(restored)
                    pendingRestore = null
                    message = "Respaldo restaurado: ${restored.movements.size} movimientos."
                }) { Text("Reemplazar") }
            },
            dismissButton = { TextButton(onClick = { pendingRestore = null }) { Text("Cancelar") } },
        )
    }
    message?.let {
        AlertDialog(
            onDismissRequest = { message = null },
            confirmButton = { TextButton(onClick = { message = null }) { Text("OK") } },
            text = { Text(it) },
        )
    }
}

@Composable
private fun CategoriesSection(data: AppData) {
    var newName by remember { mutableStateOf("") }
    var newIsIncome by remember { mutableStateOf(false) }
    OutlinedTextField(newName, { newName = it }, label = { Text("Nueva categoría") }, singleLine = true, modifier = Modifier.fillMaxWidth())
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Switch(checked = newIsIncome, onCheckedChange = { newIsIncome = it })
        Text("Es de ingreso")
        Box(Modifier.weight(1f))
        OutlinedButton(enabled = newName.isNotBlank(), onClick = {
            Graph.store.update {
                it.copy(categories = it.categories + Category(
                    Actions.newId(), newName.trim(), "tag", "#607D8B", newIsIncome, (it.categories.maxOfOrNull { c -> c.sortOrder } ?: 0) + 1,
                ))
            }
            newName = ""
        }) { Text("Agregar") }
    }
    data.categories.sortedBy { it.sortOrder }.forEach { c ->
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("${c.name}${if (c.isIncome) " (ingreso)" else ""}", modifier = Modifier.weight(1f))
            TextButton(onClick = { Graph.store.update { d -> d.copy(categories = d.categories.filter { it.id != c.id }) } }) { Text("Borrar") }
        }
    }
}

@Composable
private fun NotificationsSection(data: AppData, tick: Int) {
    val context = LocalContext.current
    val enabled = remember(tick) { NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName) }
    val seen = remember(tick) { Prefs.seen(context).entries.sortedBy { it.value.lowercase() } }
    val monitored = remember(tick) { Prefs.monitored(context) }

    Hint("PlataClara puede leer las notificaciones de tus apps de banco para registrar cada pago o ingreso. Solo lee las apps que marques abajo; las demás se ignoran, y nada sale del teléfono.")
    Text(if (enabled) "Acceso a notificaciones: activado" else "Acceso a notificaciones: desactivado", modifier = Modifier.padding(top = 8.dp))
    if (!enabled) {
        Button(onClick = { context.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }) {
            Text("Dar acceso a las notificaciones")
        }
        Hint("Si Android dice «Ajuste restringido», abre Ajustes › Apps › PlataClara › ⋮ › Permitir ajustes restringidos, y vuelve a intentar.")
    }
    if (seen.isEmpty()) {
        Hint("Cuando llegue una notificación de tu banco, su app aparecerá aquí para que la marques.")
    } else {
        Hint("Marca las apps de tu banco y, si quieres, asocia cada una con su cuenta.")
    }
    seen.forEach { (pkg, label) ->
        var checked by remember(tick) { mutableStateOf(pkg in monitored) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = checked, onCheckedChange = {
                Prefs.setMonitored(context, pkg, it)
                checked = it
            })
            Column {
                Text(label)
                if (label != pkg) Hint(pkg)
            }
        }
        if (checked) {
            var accountId by remember(pkg) { mutableStateOf(Prefs.appAccount(context, pkg)) }
            Picker(
                "Cuenta", accountId, listOf<Pair<String?, String>>(null to "Detectar por el texto") + data.accounts.map { it.id to it.name },
                { accountId = it; Prefs.setAppAccount(context, pkg, it) },
            )
        }
    }
}

@Composable
private fun StatementSection(data: AppData) {
    val context = LocalContext.current
    val zone = ZoneId.systemDefault()
    var accountId by remember { mutableStateOf<String?>(null) }
    var entries by remember { mutableStateOf(emptyList<StatementEntry>()) }
    var selected by remember { mutableStateOf(setOf<Int>()) }
    var duplicates by remember { mutableStateOf(setOf<Int>()) }
    var note by remember { mutableStateOf<String?>(null) }

    fun process(text: String) {
        val parsed = StatementParser.parse(text, zone, LocalDate.now(zone).year)
        val snapshots = Actions.snapshots(Graph.store.data.value)
        val dup = parsed.indices.filter { StatementReconciler.isDuplicate(parsed[it], accountId, snapshots, zone) }.toSet()
        entries = parsed
        duplicates = dup
        selected = parsed.indices.toSet() - dup
        if (parsed.isEmpty()) {
            note = "No encontré movimientos. Cada renglón debe empezar con la fecha. Los PDF no se pueden leer en esta versión: descarga el extracto en CSV o TXT desde la app del banco."
        }
    }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            val bytes = readText(context, uri)
            when {
                bytes == null -> note = "No se pudo leer el archivo."
                bytes.size >= 4 && String(bytes, 0, 4, Charsets.ISO_8859_1) == "%PDF" ->
                    note = "Los PDF no se pueden leer en esta versión. Descarga el extracto en CSV o TXT desde la app del banco."
                else -> process(decodeText(bytes))
            }
        }
    }

    Hint("Sirve con archivos CSV o TXT del banco. Los movimientos que ya tenías registrados aparecen desmarcados.")
    Picker("Cuenta del extracto", accountId, data.accounts.map { it.id to it.name }, { accountId = it })
    OutlinedButton(enabled = accountId != null, onClick = { launcher.launch(arrayOf("*/*")) }) { Text("Elegir archivo del extracto") }

    if (entries.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = { entries = emptyList() },
            title = { Text("Movimientos encontrados (${selected.size} de ${entries.size})") },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    entries.forEachIndexed { index, e ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = index in selected, onCheckedChange = { on -> selected = if (on) selected + index else selected - index })
                            Column(Modifier.weight(1f)) {
                                Text(e.description.ifEmpty { "(sin descripción)" }, maxLines = 2)
                                Hint("${e.date.atZone(zone).format(dayFormat)} · ${e.kind.label}${if (index in duplicates) " · ya registrado" else ""}")
                            }
                            Text((if (e.kind == MovementKind.ingreso) "+" else "-") + Money.format(e.amount))
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(enabled = selected.isNotEmpty(), onClick = {
                    val account = data.accounts.firstOrNull { it.id == accountId }
                    if (account != null) {
                        val chosen = selected.sorted().map { entries[it] }
                        Graph.store.update { Actions.importStatement(it, account, chosen, zone) }
                        BackupFolder.autoBackup(context, Graph.store.data.value)
                        note = "Importados ${chosen.size} movimientos."
                    }
                    entries = emptyList()
                }) { Text("Importar ${selected.size}") }
            },
            dismissButton = { TextButton(onClick = { entries = emptyList() }) { Text("Cancelar") } },
        )
    }
    note?.let {
        AlertDialog(
            onDismissRequest = { note = null },
            confirmButton = { TextButton(onClick = { note = null }) { Text("OK") } },
            text = { Text(it) },
        )
    }
}
