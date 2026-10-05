package com.rojo1112.plataclara.data

import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.AppData
import com.rojo1112.plataclara.core.BackupCodec
import com.rojo1112.plataclara.core.BackupRotation
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.io.File
import java.time.Instant
import java.time.ZoneId

/** Datos de la app: un archivo JSON en el almacenamiento privado, con el mismo formato del respaldo. */
class Store(private val file: File) {
    private val lock = Any()
    private val state = MutableStateFlow(Actions.seedIfNeeded(load()))
    val data: StateFlow<AppData> = state.asStateFlow()

    private fun load(): AppData {
        if (!file.exists()) return AppData(exportedAt = Instant.now())
        return try {
            BackupCodec.decode(file.readText())
        } catch (e: Exception) {
            // No se pierde nada: el archivo dañado se conserva aparte.
            file.renameTo(File(file.parentFile, "datos.corrupto-${System.currentTimeMillis()}.json"))
            AppData(exportedAt = Instant.now())
        }
    }

    fun <T> transact(block: (AppData) -> Pair<AppData, T>): T = synchronized(lock) {
        val (next, result) = block(state.value)
        if (next != state.value) {
            state.value = next
            save(next)
        }
        result
    }

    fun update(block: (AppData) -> AppData) {
        transact { block(it) to Unit }
    }

    fun replaceAll(data: AppData) = update { Actions.seedIfNeeded(data) }

    private fun save(data: AppData) {
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(BackupCodec.encode(data.copy(exportedAt = Instant.now())))
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }
}

object Graph {
    lateinit var store: Store
        private set

    @Synchronized
    fun init(context: Context) {
        if (!::store.isInitialized) store = Store(File(context.applicationContext.filesDir, "datos.json"))
    }
}

class PlataApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Graph.init(this)
    }
}

object Prefs {
    private fun sp(c: Context) = c.getSharedPreferences("plataclara", Context.MODE_PRIVATE)

    fun monitored(c: Context): Set<String> = sp(c).getStringSet("monitoreadas", emptySet())?.toSet() ?: emptySet()

    fun setMonitored(c: Context, pkg: String, on: Boolean) {
        val set = monitored(c).toMutableSet()
        if (on) set += pkg else set -= pkg
        sp(c).edit().putStringSet("monitoreadas", set).apply()
    }

    /** Apps que han publicado notificaciones: solo se guarda el paquete y el nombre, nunca el contenido. */
    fun seen(c: Context): Map<String, String> =
        (sp(c).getStringSet("vistas", emptySet()) ?: emptySet())
            .mapNotNull { it.split("|", limit = 2).takeIf { p -> p.size == 2 }?.let { p -> p[0] to p[1] } }
            .toMap()

    fun noteSeen(c: Context, pkg: String, label: String) {
        val current = seen(c)
        if (current[pkg] == label || current.size >= 300) return
        val next = (current + (pkg to label)).map { "${it.key}|${it.value}" }.toSet()
        sp(c).edit().putStringSet("vistas", next).apply()
    }

    fun appAccount(c: Context, pkg: String): String? = sp(c).getString("cuenta_$pkg", null)

    fun setAppAccount(c: Context, pkg: String, accountId: String?) {
        sp(c).edit().apply { if (accountId == null) remove("cuenta_$pkg") else putString("cuenta_$pkg", accountId) }.apply()
    }

    var Context.folderUri: String?
        get() = sp(this).getString("carpetaRespaldo", null)
        set(value) { sp(this).edit().putString("carpetaRespaldo", value).apply() }

    var Context.lastBackup: Long
        get() = sp(this).getLong("ultimoRespaldo", 0L)
        set(value) { sp(this).edit().putLong("ultimoRespaldo", value).apply() }
}

/** Respaldo automático en una carpeta elegida por el usuario: sobrevive a desinstalar la app. */
object BackupFolder {
    const val KEEP = 7

    fun hasFolder(c: Context): Boolean = with(Prefs) { c.folderUri != null }

    fun lastBackup(c: Context): Long = with(Prefs) { c.lastBackup }

    fun setFolder(c: Context, uri: Uri) {
        c.contentResolver.takePersistableUriPermission(
            uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        with(Prefs) { c.folderUri = uri.toString() }
    }

    private fun folder(c: Context): DocumentFile? {
        val uri = with(Prefs) { c.folderUri } ?: return null
        return DocumentFile.fromTreeUri(c, Uri.parse(uri))?.takeIf { it.canWrite() }
    }

    private fun names(dir: DocumentFile): List<String> = dir.listFiles().mapNotNull { it.name }

    fun latestName(c: Context): String? = folder(c)?.let { BackupRotation.latest(names(it)) }

    /** Escribe el respaldo del día y conserva los 7 más recientes. Nunca escribe un respaldo vacío. */
    fun autoBackup(c: Context, data: AppData): Boolean {
        val dir = folder(c) ?: return false
        if (!BackupRotation.shouldWrite(data.accounts.size, data.movements.size)) return false
        return try {
            val name = BackupRotation.fileName(Instant.now(), ZoneId.systemDefault())
            val file = dir.findFile(name) ?: dir.createFile("application/json", name) ?: return false
            c.contentResolver.openOutputStream(file.uri, "wt")?.use {
                it.write(BackupCodec.encode(data.copy(exportedAt = Instant.now())).toByteArray(Charsets.UTF_8))
            } ?: return false
            BackupRotation.filesToDelete(names(dir), KEEP).forEach { dir.findFile(it)?.delete() }
            with(Prefs) { c.lastBackup = System.currentTimeMillis() }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Lee el respaldo más reciente de la carpeta; lanza excepción si no hay o está dañado. */
    fun readLatest(c: Context): AppData {
        val dir = folder(c) ?: throw IllegalStateException("Primero elige la carpeta de respaldo.")
        val name = BackupRotation.latest(names(dir)) ?: throw IllegalStateException("La carpeta no tiene respaldos de PlataClara.")
        val file = dir.findFile(name) ?: throw IllegalStateException("No se pudo abrir $name.")
        val text = c.contentResolver.openInputStream(file.uri)?.use { it.readBytes().toString(Charsets.UTF_8) }
            ?: throw IllegalStateException("No se pudo leer $name.")
        return BackupCodec.decode(text)
    }
}
