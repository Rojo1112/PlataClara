package com.rojo1112.plataclara.core

import java.text.Normalizer
import java.time.Instant

object TextNormalizer {
    private val marks = Regex("\\p{Mn}+")

    /** Sin tildes y en minúsculas. */
    fun fold(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD).replace(marks, "").lowercase()
}

object AmountParser {
    private val regex = Regex(
        """(?:\$|COP)\s*([0-9](?:[0-9.,]*[0-9])?)|([0-9](?:[0-9.,]*[0-9])?)\s*(?:COP|pesos)""",
        RegexOption.IGNORE_CASE,
    )
    private val commaDecimals = Regex(""",\d{1,2}$""")
    private val dotDecimals = Regex("""\.\d{1,2}$""")

    /** Primer monto mayor que cero. Formato colombiano: punto de miles, coma decimal (se descartan centavos). */
    fun firstAmount(text: String): Int? {
        for (match in regex.findAll(text)) {
            for (group in 1..2) {
                val raw = match.groups[group]?.value ?: continue
                val value = normalize(raw)
                if (value != null && value > 0) return value
            }
        }
        return null
    }

    /** "12.345,67" -> 12345; "1,234.56" -> 1234; "50000.00" -> 50000; "12000" -> 12000. */
    fun normalize(raw: String): Int? {
        var s = raw.trim()
        if (commaDecimals.containsMatchIn(s)) {
            s = s.replace(commaDecimals, "")
        } else if (dotDecimals.containsMatchIn(s) && (s.contains(",") || s.count { it == '.' } == 1)) {
            s = s.replace(dotDecimals, "")
        }
        s = s.replace(".", "").replace(",", "")
        return s.toIntOrNull()
    }
}

object BankDetector {
    private val rules: List<Pair<Bank, List<String>>> = listOf(
        Bank.nu to listOf("nubank", "nu.com.co", "nu colombia", "tarjeta nu", "cuenta nu", "cajita nu"),
        Bank.lulo to listOf("lulo bank", "lulobank", "lulo"),
        Bank.uala to listOf("uala"),
        Bank.dale to listOf("dale!", "dale.com.co", "app dale"),
    )

    fun detect(text: String, sender: String?): Bank? {
        val haystack = TextNormalizer.fold((sender ?: "") + " " + text)
        return rules.firstOrNull { (_, keys) -> keys.any { haystack.contains(it) } }?.first
    }
}

data class Classification(val kind: MovementKind, val method: PaymentMethod, val explicit: Boolean)

object MovementClassifier {
    private val cardPaymentWords = listOf(
        "pago a tu tarjeta", "pago de tu tarjeta", "abono a tu tarjeta", "pagaste tu tarjeta",
        "a tu tarjeta", "a tu credito", "abonamos",
    )
    private val incomeWords = listOf(
        "recibiste", "te enviaron", "te transfirieron", "te llego", "te llegaron", "abono",
        "consignacion", "deposito", "ingreso de", "te pagaron",
    )
    private val llaveWords = listOf("llave", "bre-b", "breb")
    private val outgoingTransferWords = listOf("transferiste", "enviaste", "transferencia")
    private val purchaseWords = listOf("compra", "pagaste", "pago")
    private val qr = Regex("""\bqr\b""")

    fun classify(text: String): Classification {
        val t = TextNormalizer.fold(text)
        fun has(words: List<String>) = words.any { t.contains(it) }
        return when {
            has(cardPaymentWords) -> Classification(MovementKind.transferencia, PaymentMethod.transferencia, false)
            has(incomeWords) ->
                Classification(MovementKind.ingreso, if (has(llaveWords)) PaymentMethod.llave else PaymentMethod.transferencia, true)
            has(llaveWords) -> Classification(MovementKind.gasto, PaymentMethod.llave, true)
            qr.containsMatchIn(t) -> Classification(MovementKind.gasto, PaymentMethod.qr, true)
            t.contains("credito") && (t.contains("tarjeta") || t.contains("tc")) ->
                Classification(MovementKind.gasto, PaymentMethod.credito, true)
            t.contains("debito") -> Classification(MovementKind.gasto, PaymentMethod.debito, true)
            has(outgoingTransferWords) -> Classification(MovementKind.gasto, PaymentMethod.transferencia, true)
            has(purchaseWords) -> Classification(MovementKind.gasto, PaymentMethod.debito, false)
            else -> Classification(MovementKind.gasto, PaymentMethod.debito, false)
        }
    }
}

data class ParsedMovement(
    val amount: Int,
    val kind: MovementKind,
    val method: PaymentMethod,
    val merchant: String?,
    val bank: Bank?,
    val last4: String?,
    val isExplicit: Boolean,
)

object GenericParser {
    private val last4Regex = Regex("""(?:\*{1,4}|terminada en|termina en|finalizada en|x{2,4})\s?(\d{4})""")
    private val merchantRegex = Regex(
        """\ben\s+([A-Za-zÁÉÍÓÚÑáéíóúñ][^\n,.]{1,39}?)(?=\s+(?:el|con|por|desde|a las)\b|[,.\n]|$)""",
        RegexOption.IGNORE_CASE,
    )

    fun parse(text: String, sender: String? = null): ParsedMovement? {
        val amount = AmountParser.firstAmount(text) ?: return null
        val c = MovementClassifier.classify(text)
        return ParsedMovement(
            amount = amount, kind = c.kind, method = c.method, merchant = merchant(text),
            bank = BankDetector.detect(text, sender), last4 = last4(text), isExplicit = c.explicit,
        )
    }

    fun last4(text: String): String? = last4Regex.find(TextNormalizer.fold(text))?.groupValues?.get(1)

    fun merchant(text: String): String? =
        merchantRegex.find(text)?.groupValues?.get(1)?.trim()?.takeIf { it.isNotEmpty() }
}

data class AccountHint(
    val id: String,
    val bank: Bank,
    val kind: AccountKind,
    val last4: List<String> = emptyList(),
    val walletCardName: String? = null,
    val emailSenders: List<String> = emptyList(),
)

object AccountMatcher {
    /** Orden: últimos 4 dígitos → remitente → banco. Si hay varias, desempata por tipo (crédito/ahorros). */
    fun match(bank: Bank?, last4: String?, method: PaymentMethod, sender: String?, hints: List<AccountHint>): String? {
        if (last4 != null) hints.firstOrNull { last4 in it.last4 }?.let { return it.id }

        var candidates = emptyList<AccountHint>()
        if (!sender.isNullOrEmpty()) {
            val s = TextNormalizer.fold(sender)
            candidates = hints.filter { h -> h.emailSenders.any { it.isNotEmpty() && s.contains(TextNormalizer.fold(it)) } }
        }
        if (candidates.isEmpty() && bank != null) candidates = hints.filter { it.bank == bank }
        if (candidates.size == 1) return candidates[0].id
        val wanted = if (method == PaymentMethod.credito) AccountKind.credito else AccountKind.ahorros
        val byKind = candidates.filter { it.kind == wanted }
        return if (byKind.size == 1) byKind[0].id else null
    }
}

object Deduplicator {
    const val WINDOW_SECONDS = 600L

    /** Mismo monto y tipo, misma cuenta (o una de las dos desconocida), a ≤ 10 minutos. */
    fun duplicate(amount: Int, kind: MovementKind, accountId: String?, date: Instant, existing: List<MovementSnapshot>): String? =
        existing.firstOrNull { m ->
            m.amount == amount && m.kind == kind &&
                (accountId == null || m.accountId == null || m.accountId == accountId) &&
                Math.abs(m.date.epochSecond - date.epochSecond) <= WINDOW_SECONDS
        }?.id
}

sealed class CaptureDecision {
    data class Create(val status: MovementStatus) : CaptureDecision()
    data class DuplicateOf(val id: String) : CaptureDecision()
    object Unreadable : CaptureDecision()
}

object CapturePipeline {
    fun decide(parsed: ParsedMovement?, accountId: String?, date: Instant, existing: List<MovementSnapshot>): CaptureDecision {
        if (parsed == null) return CaptureDecision.Unreadable
        Deduplicator.duplicate(parsed.amount, parsed.kind, accountId, date, existing)?.let { return CaptureDecision.DuplicateOf(it) }
        return CaptureDecision.Create(
            if (parsed.isExplicit && accountId != null) MovementStatus.confirmado else MovementStatus.porRevisar,
        )
    }
}
