package com.rojo1112.plataclara.core

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.temporal.ChronoUnit

/** Fecha ISO-8601 en segundos ("2026-10-04T17:00:00Z"), igual que el respaldo del iPhone. */
object InstantIsoSerializer : KSerializer<Instant> {
    override val descriptor = PrimitiveSerialDescriptor("Instant", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: Instant) =
        encoder.encodeString(value.truncatedTo(ChronoUnit.SECONDS).toString())

    override fun deserialize(decoder: Decoder): Instant = Instant.parse(decoder.decodeString())
}

// Los nombres de campo (incluido "accountID") son los del JSON de respaldo del iPhone.

@Serializable
data class Account(
    val id: String,
    val name: String,
    val bank: Bank,
    val kind: AccountKind,
    val openingBalance: Int,
    val creditLimit: Int? = null,
    val cutoffDay: Int? = null,
    val paymentDay: Int? = null,
    val last4: List<String> = emptyList(),
    val walletCardName: String? = null,
    val emailSenders: List<String> = emptyList(),
    @Serializable(with = InstantIsoSerializer::class) val createdAt: Instant,
) {
    fun snapshot() = AccountSnapshot(id, kind, openingBalance)
    fun hint() = AccountHint(id, bank, kind, last4, walletCardName, emailSenders)
}

@Serializable
data class Category(
    val id: String,
    val name: String,
    val icon: String,
    val colorHex: String,
    val isIncome: Boolean,
    val sortOrder: Int,
)

@Serializable
data class Movement(
    val id: String,
    val amount: Int,
    @Serializable(with = InstantIsoSerializer::class) val date: Instant,
    val kind: MovementKind,
    val method: PaymentMethod,
    val accountID: String? = null,
    val destinationAccountID: String? = null,
    val categoryID: String? = null,
    val merchant: String? = null,
    val note: String? = null,
    val source: CaptureSource,
    val status: MovementStatus,
    val rawText: String? = null,
    val occurrenceID: String? = null,
) {
    fun snapshot(categoryName: String? = null) =
        MovementSnapshot(id, amount, date, kind, method, accountID, destinationAccountID, categoryName, status)
}

@Serializable
data class Recurring(
    val id: String,
    val name: String,
    val amount: Int,
    val dayOfMonth: Int,
    val accountID: String? = null,
    val method: PaymentMethod,
    val categoryID: String? = null,
    val active: Boolean,
    val remind: Boolean,
) {
    fun snapshot() = RecurringSnapshot(id, name, amount, dayOfMonth, accountID, active)
}

@Serializable
data class Occurrence(
    val id: String,
    val recurringID: String,
    val monthKey: String,
    @Serializable(with = InstantIsoSerializer::class) val dueDate: Instant,
    val status: OccurrenceStatus,
    val movementID: String? = null,
)

/** Todos los datos de la app; también es el archivo de respaldo (versión 1, compatible con el iPhone). */
@Serializable
data class AppData(
    val formatVersion: Int = BackupCodec.CURRENT_VERSION,
    @Serializable(with = InstantIsoSerializer::class) val exportedAt: Instant,
    val accounts: List<Account> = emptyList(),
    val categories: List<Category> = emptyList(),
    val movements: List<Movement> = emptyList(),
    val recurring: List<Recurring> = emptyList(),
    val occurrences: List<Occurrence> = emptyList(),
)

sealed class BackupException(message: String) : Exception(message) {
    class UnsupportedVersion(val version: Int) : BackupException("Formato no compatible (versión $version).")
    class InvalidFile : BackupException("El archivo no es un respaldo válido.")
}

object BackupCodec {
    const val CURRENT_VERSION = 1

    private val json = Json {
        prettyPrint = true
        encodeDefaults = true
        explicitNulls = false
        ignoreUnknownKeys = true
    }

    fun encode(data: AppData): String = json.encodeToString(AppData.serializer(), data)

    fun decode(text: String): AppData {
        val data = try {
            json.decodeFromString(AppData.serializer(), text)
        } catch (e: SerializationException) {
            throw BackupException.InvalidFile()
        } catch (e: IllegalArgumentException) {
            throw BackupException.InvalidFile()
        } catch (e: java.time.DateTimeException) {
            throw BackupException.InvalidFile()
        }
        if (data.formatVersion != CURRENT_VERSION) throw BackupException.UnsupportedVersion(data.formatVersion)
        return data
    }
}
