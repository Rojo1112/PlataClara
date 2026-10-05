package com.rojo1112.plataclara.data

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.rojo1112.plataclara.core.Actions
import com.rojo1112.plataclara.core.CaptureSource
import java.time.Instant
import java.time.ZoneId

/**
 * Lee las notificaciones de las apps de banco que el usuario eligió en Ajustes y las registra.
 * Las demás apps solo se anotan por nombre (para que aparezcan en la lista); su contenido no se toca.
 */
class BankNotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        Graph.init(applicationContext)

        if (pkg !in Prefs.monitored(this)) {
            Prefs.noteSeen(this, pkg, labelOf(pkg))
            return
        }
        val notification = sbn.notification ?: return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val body = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT) ?: extras.getCharSequence(Notification.EXTRA_TEXT))
            ?.toString().orEmpty()
        val text = listOf(title, body).filter { it.isNotBlank() }.joinToString(". ")
        if (text.isBlank()) return

        val forced = Prefs.appAccount(this, pkg)
        Graph.store.transact { data ->
            Actions.ingestText(data, text, pkg, CaptureSource.captura, Instant.now(), ZoneId.systemDefault(), forced)
        }
        BackupFolder.autoBackup(this, Graph.store.data.value)
    }

    private fun labelOf(pkg: String): String = try {
        packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }
}
