package com.rojo1112.plataclara

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.AppData
import com.rojo1112.plataclara.core.MovementStatus
import com.rojo1112.plataclara.core.Occurrence
import com.rojo1112.plataclara.core.Recurring
import com.rojo1112.plataclara.data.BackupFolder
import com.rojo1112.plataclara.data.Graph
import com.rojo1112.plataclara.ui.FixedScreen
import com.rojo1112.plataclara.ui.HomeScreen
import com.rojo1112.plataclara.ui.MovementDialog
import com.rojo1112.plataclara.ui.MovementsScreen
import com.rojo1112.plataclara.ui.PayDialog
import com.rojo1112.plataclara.ui.RecurringDialog
import com.rojo1112.plataclara.ui.ReviewScreen
import com.rojo1112.plataclara.ui.SettingsScreen
import com.rojo1112.plataclara.ui.StatsScreen
import java.time.Instant
import java.time.ZoneId

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Graph.init(this)
        setContent {
            MaterialTheme(colorScheme = if (isSystemInDarkTheme()) darkColorScheme() else lightColorScheme()) {
                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) { App() }
            }
        }
    }

    override fun onStop() {
        super.onStop()
        val snapshot = Graph.store.data.value
        val context = applicationContext
        Thread { BackupFolder.autoBackup(context, snapshot) }.start()
    }
}

private data class MovementEdit(val movement: com.rojo1112.plataclara.core.Movement?)
private data class RecurringEdit(val recurring: Recurring?)

private val tabs = listOf("🏠" to "Inicio", "📋" to "Movimientos", "📥" to "Revisar", "📅" to "Fijos", "📊" to "Estadísticas", "⚙️" to "Ajustes")

@Composable
fun App() {
    val data: AppData by Graph.store.data.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val zone = ZoneId.systemDefault()
    var tab by remember { mutableIntStateOf(0) }
    var movementEdit by remember { mutableStateOf<MovementEdit?>(null) }
    var recurringEdit by remember { mutableStateOf<RecurringEdit?>(null) }
    var paying by remember { mutableStateOf<Occurrence?>(null) }
    val toReview = data.movements.count { it.status == MovementStatus.porRevisar }

    LaunchedEffect(Unit) { Graph.store.update { Actions.ensureMonth(it, Instant.now(), zone) } }

    fun persist(block: (AppData) -> AppData) {
        Graph.store.update(block)
        val snapshot = Graph.store.data.value
        val appContext = context.applicationContext
        Thread { BackupFolder.autoBackup(appContext, snapshot) }.start()
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { index, (icon, label) ->
                    NavigationBarItem(
                        selected = tab == index, onClick = { tab = index },
                        icon = { Text(icon) },
                        label = { Text(if (index == 2 && toReview > 0) "$label ($toReview)" else label, maxLines = 1) },
                        alwaysShowLabel = false,
                    )
                }
            }
        },
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (tab) {
                0 -> HomeScreen(data) { movementEdit = MovementEdit(null) }
                1 -> MovementsScreen(data, onEdit = { movementEdit = MovementEdit(it) }, onAdd = { movementEdit = MovementEdit(null) })
                2 -> ReviewScreen(data) { movementEdit = MovementEdit(it) }
                3 -> FixedScreen(
                    data,
                    onAdd = { recurringEdit = RecurringEdit(null) },
                    onEdit = { recurringEdit = RecurringEdit(it) },
                    onPay = { paying = it },
                    onSkip = { occ -> persist { Actions.skip(it, occ.id) } },
                    onReopen = { occ -> persist { Actions.reopen(it, occ.id) } },
                )
                4 -> StatsScreen(data)
                else -> SettingsScreen(data)
            }
        }
    }

    movementEdit?.let { edit ->
        MovementDialog(
            data = data, initial = edit.movement,
            onDismiss = { movementEdit = null },
            onSave = { saved -> persist { Actions.saveMovement(it, saved, zone) }; movementEdit = null },
            onDelete = if (edit.movement != null) { m -> persist { Actions.deleteMovement(it, m.id) }; movementEdit = null } else null,
        )
    }
    recurringEdit?.let { edit ->
        RecurringDialog(
            data = data, initial = edit.recurring,
            onDismiss = { recurringEdit = null },
            onSave = { saved ->
                persist { d ->
                    val exists = d.recurring.any { it.id == saved.id }
                    val updated = d.copy(recurring = if (exists) d.recurring.map { if (it.id == saved.id) saved else it } else d.recurring + saved)
                    Actions.ensureMonth(updated, Instant.now(), zone)
                }
                recurringEdit = null
            },
            onDelete = if (edit.recurring != null) { r ->
                persist { d ->
                    d.copy(
                        recurring = d.recurring.filter { it.id != r.id },
                        occurrences = d.occurrences.filter { !(it.recurringID == r.id && it.status == com.rojo1112.plataclara.core.OccurrenceStatus.pendiente) },
                    )
                }
                recurringEdit = null
            } else null,
        )
    }
    paying?.let { occ ->
        val r = data.recurring.firstOrNull { it.id == occ.recurringID }
        PayDialog(
            name = r?.name ?: "Gasto fijo", suggested = r?.amount ?: 0,
            onDismiss = { paying = null },
            onPay = { amount -> persist { Actions.markPaid(it, occ.id, amount, Instant.now()) }; paying = null },
        )
    }
}
