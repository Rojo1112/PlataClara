package com.rojo1112.plataclara.core

import java.time.DateTimeException
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class StatementEntry(
    val date: Instant,
    val description: String,
    val amount: Int,
    val kind: MovementKind,
    val balance: Int?,
)

/**
 * Lee el texto de un extracto (CSV o TXT). Entiende dos formas:
 * una línea por movimiento (`04/10/2026 COMPRA EXITO -50.000,00` o `01 sep Compra en X -$4.300,00`) y
 * renglones separados (fecha, descripción y monto cada uno en su línea). Un pago a la tarjeta es una transferencia.
 */
object StatementParser {
    private val incomeWords = listOf("abono", "consignacion", "deposito", "intereses", "nomina", "reembolso", "devolucion", "ingreso")
    private val months = mapOf(
        "ene" to 1, "feb" to 2, "mar" to 3, "abr" to 4, "may" to 5, "jun" to 6,
        "jul" to 7, "ago" to 8, "sep" to 9, "oct" to 10, "nov" to 11, "dic" to 12,
    )
    private const val MONTH_NAMES = "ene|feb|mar|abr|may|jun|jul|ago|sept?|oct|nov|dic"

    private val isoDate = Regex("""^\s*(\d{4})-(\d{2})-(\d{2})""")
    private val localDate = Regex("""^\s*(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?![\d/-])""")
    private val textDate = Regex("""^\s*(\d{1,2})\s+($MONTH_NAMES)[a-z]*\.?(?:\s+(\d{4}))?(?![\w])""", RegexOption.IGNORE_CASE)
    private val wholeLineTextDate = Regex("""^(\d{1,2})\s+($MONTH_NAMES)[a-z]*\.?(?:\s+(\d{4}))?$""", RegexOption.IGNORE_CASE)
    private val periodYear = Regex("""\b\d{1,2}\s*-\s*\d{1,2}\s+(?:$MONTH_NAMES)[a-z]*\.?\s+(\d{4})\b""", RegexOption.IGNORE_CASE)
    private val pageMarker = Regex("""^\s*\d+\s*/\s*\d+\s*$""")
    private val amountOnly = Regex("""^([-+])?\s*\$?\s*(\d[\d.,]*)$""")
    private val amountToken = Regex("""(?<![\w.,/])[-+]?\(?\$?\s?\d[\d.,]*\)?-?(?![\w/])""")
    private val crWord = Regex("""\bcr\b""")
    private val dbWord = Regex("""\bdb\b""")
    private const val MARKERS = ".,$()+-"

    fun parse(text: String, zone: ZoneId, defaultYear: Int?): List<StatementEntry> {
        val year = periodYear.find(text)?.groups?.get(1)?.value?.toIntOrNull() ?: defaultYear
        val lines = text.lines()
        val single = lines.mapNotNull { parseLine(it, zone, year) }
        val stacked = parseStacked(lines, zone, year)
        return if (stacked.size > single.size) stacked else single
    }

    private data class Token(val start: Int, val text: String, val value: Int)

    private fun parseLine(raw: String, zone: ZoneId, defaultYear: Int?): StatementEntry? {
        val line = raw.replace(';', ' ').replace('\t', ' ')
        val (date, rest) = leadingDate(line, zone, defaultYear) ?: return null

        val tokens = amountToken.findAll(rest).mapNotNull { m ->
            val text = m.value
            if (text.none { it in MARKERS }) return@mapNotNull null
            val digits = text.filter { it in "0123456789.," }
            val value = AmountParser.normalize(digits) ?: return@mapNotNull null
            Token(m.range.first, text, value)
        }.toList()
        val first = tokens.firstOrNull() ?: return null
        if (first.value <= 0) return null

        val description = rest.substring(0, first.start).trim(' ', '-', '|')
        val folded = TextNormalizer.fold(rest)
        var kind = when {
            first.text.contains('-') || first.text.contains('(') -> MovementKind.gasto
            first.text.startsWith("+") -> MovementKind.ingreso
            crWord.containsMatchIn(folded) -> MovementKind.ingreso
            dbWord.containsMatchIn(folded) -> MovementKind.gasto
            incomeWords.any { folded.contains(it) } -> MovementKind.ingreso
            else -> MovementKind.gasto
        }
        kind = asTransferIfCardPayment(kind, description)
        return StatementEntry(date, description, first.value, kind, tokens.getOrNull(1)?.value)
    }

    private fun parseStacked(lines: List<String>, zone: ZoneId, year: Int?): List<StatementEntry> {
        val entries = mutableListOf<StatementEntry>()
        var date: Instant? = null
        var description = mutableListOf<String>()
        for (raw in lines) {
            val line = raw.trim()
            if (line.isEmpty()) continue
            val dateMatch = wholeLineTextDate.find(line)
            if (dateMatch != null) {
                val parsed = makeDate(
                    yearOf(dateMatch.groups[3]?.value, year), monthOf(dateMatch.groupValues[2]),
                    dateMatch.groupValues[1].toIntOrNull(), zone,
                )
                if (parsed != null) {
                    date = parsed
                    description = mutableListOf()
                    continue
                }
            }
            val open = date ?: continue
            if (pageMarker.matches(line)) continue
            val amount = amountLine(line)
            if (amount != null) {
                val text = description.joinToString(" ")
                val folded = TextNormalizer.fold(text)
                var kind = when (amount.second) {
                    '-' -> MovementKind.gasto
                    '+' -> MovementKind.ingreso
                    else -> if (incomeWords.any { folded.contains(it) }) MovementKind.ingreso else MovementKind.gasto
                }
                kind = asTransferIfCardPayment(kind, text)
                entries += StatementEntry(open, text, amount.first, kind, null)
                date = null
            } else {
                description.add(line)
            }
        }
        return entries
    }

    /** Línea que es solo un monto: debe traer `$`, signo o separador (un "2026" suelto no cuenta). */
    private fun amountLine(line: String): Pair<Int, Char?>? {
        val m = amountOnly.find(line) ?: return null
        val sign = m.groups[1]?.value?.firstOrNull()
        val digits = m.groupValues[2]
        if (!(line.contains('$') || sign != null || digits.contains('.') || digits.contains(','))) return null
        val value = AmountParser.normalize(digits) ?: return null
        return if (value > 0) value to sign else null
    }

    private fun asTransferIfCardPayment(kind: MovementKind, description: String): MovementKind =
        if (kind == MovementKind.gasto && MovementClassifier.classify(description).kind == MovementKind.transferencia) {
            MovementKind.transferencia
        } else {
            kind
        }

    private fun monthOf(text: String): Int? = text.toIntOrNull() ?: months[TextNormalizer.fold(text).take(3)]

    private fun yearOf(text: String?, default: Int?): Int? {
        val y = text?.toIntOrNull() ?: return default
        return if (y < 100) 2000 + y else y
    }

    private fun makeDate(year: Int?, month: Int?, day: Int?, zone: ZoneId): Instant? {
        if (year == null || month == null || day == null) return null
        return try {
            LocalDate.of(year, month, day).atTime(LocalTime.NOON).atZone(zone).toInstant()
        } catch (e: DateTimeException) {
            null
        }
    }

    private fun leadingDate(line: String, zone: ZoneId, defaultYear: Int?): Pair<Instant, String>? {
        isoDate.find(line)?.let { m ->
            val date = makeDate(
                m.groupValues[1].toIntOrNull(), m.groupValues[2].toIntOrNull(), m.groupValues[3].toIntOrNull(), zone,
            )
            if (date != null) return date to line.substring(m.range.last + 1)
        }
        localDate.find(line)?.let { m ->
            val date = makeDate(
                yearOf(m.groups[3]?.value, defaultYear), m.groupValues[2].toIntOrNull(), m.groupValues[1].toIntOrNull(), zone,
            )
            if (date != null) return date to line.substring(m.range.last + 1)
        }
        textDate.find(line)?.let { m ->
            val date = makeDate(
                yearOf(m.groups[3]?.value, defaultYear), monthOf(m.groupValues[2]), m.groupValues[1].toIntOrNull(), zone,
            )
            if (date != null) return date to line.substring(m.range.last + 1)
        }
        return null
    }
}

object StatementReconciler {
    /** Ya está registrado si hay un movimiento con el mismo monto y tipo, en la misma cuenta (o sin cuenta), a ≤ 1 día. */
    fun isDuplicate(entry: StatementEntry, accountId: String?, existing: List<MovementSnapshot>, zone: ZoneId): Boolean {
        val entryDay = entry.date.atZone(zone).toLocalDate()
        return existing.any { m ->
            m.amount == entry.amount && m.kind == entry.kind &&
                (accountId == null || m.accountId == null || m.accountId == accountId) &&
                Math.abs(ChronoUnit.DAYS.between(entryDay, m.date.atZone(zone).toLocalDate())) <= 1
        }
    }
}

object BackupRotation {
    private val pattern = Regex("""^PlataClara-\d{4}-\d{2}-\d{2}\.json$""")

    fun fileName(date: Instant, zone: ZoneId): String {
        val d = date.atZone(zone).toLocalDate()
        return "PlataClara-%04d-%02d-%02d.json".format(d.year, d.monthValue, d.dayOfMonth)
    }

    fun isBackupFile(name: String) = pattern.matches(name)

    fun filesToDelete(names: List<String>, keep: Int): List<String> {
        val sorted = names.filter(::isBackupFile).sortedDescending()
        return if (sorted.size > keep) sorted.drop(keep) else emptyList()
    }

    fun latest(names: List<String>): String? = names.filter(::isBackupFile).maxOrNull()

    /** Nunca se escribe un respaldo vacío: una app recién reinstalada no debe pisar el respaldo bueno. */
    fun shouldWrite(accounts: Int, movements: Int) = accounts > 0 || movements > 0
}
