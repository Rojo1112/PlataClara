package com.rojo1112.plataclara.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

val bogota: ZoneId = ZoneId.of("America/Bogota")

fun fecha(y: Int, m: Int, d: Int, h: Int = 12, min: Int = 0): Instant =
    LocalDateTime.of(y, m, d, h, min).atZone(bogota).toInstant()

class MoneyAndLedgerTests {
    private val nu = AccountSnapshot("nu", AccountKind.ahorros, 100_000)
    private val lulo = AccountSnapshot("lulo", AccountKind.ahorros, 0)
    private val tarjeta = AccountSnapshot("tc", AccountKind.credito, 0)

    private fun mov(
        amount: Int, kind: MovementKind, method: PaymentMethod, from: String?, to: String? = null,
        status: MovementStatus = MovementStatus.confirmado,
    ) = MovementSnapshot("m${amount}${kind}", amount, fecha(2026, 10, 4), kind, method, from, to, null, status)

    @Test fun formatsColombianPesos() {
        assertEquals("$ 0", Money.format(0))
        assertEquals("$ 1.000", Money.format(1000))
        assertEquals("$ 1.234.567", Money.format(1_234_567))
        assertEquals("-$ 5.000", Money.format(-5000))
    }

    @Test fun incomeDebitAndQrChangeSavingsBalance() {
        val ms = listOf(
            mov(50_000, MovementKind.ingreso, PaymentMethod.transferencia, "nu"),
            mov(20_000, MovementKind.gasto, PaymentMethod.debito, "nu"),
            mov(5_000, MovementKind.gasto, PaymentMethod.qr, "nu"),
        )
        assertEquals(125_000, Ledger.balance(nu, ms))
    }

    @Test fun creditPurchaseRaisesDebtAndNotCash() {
        val ms = listOf(mov(80_000, MovementKind.gasto, PaymentMethod.credito, "tc"))
        assertEquals(80_000, Ledger.balance(tarjeta, ms))
        assertEquals(100_000, Ledger.totalCash(listOf(nu, tarjeta), ms))
        assertEquals(80_000, Ledger.totalDebt(listOf(nu, tarjeta), ms))
    }

    @Test fun payingTheCardReducesCashAndDebt() {
        val ms = listOf(
            mov(80_000, MovementKind.gasto, PaymentMethod.credito, "tc"),
            mov(50_000, MovementKind.transferencia, PaymentMethod.transferencia, "nu", "tc"),
        )
        assertEquals(50_000, Ledger.totalCash(listOf(nu, tarjeta), ms))
        assertEquals(30_000, Ledger.totalDebt(listOf(nu, tarjeta), ms))
    }

    @Test fun transferBetweenOwnAccountsKeepsTotal() {
        val ms = listOf(mov(30_000, MovementKind.transferencia, PaymentMethod.transferencia, "nu", "lulo"))
        assertEquals(70_000, Ledger.balance(nu, ms))
        assertEquals(30_000, Ledger.balance(lulo, ms))
    }

    @Test fun movementsToReviewAreIgnored() {
        val ms = listOf(mov(10_000, MovementKind.gasto, PaymentMethod.debito, "nu", status = MovementStatus.porRevisar))
        assertEquals(100_000, Ledger.balance(nu, ms))
    }

    @Test fun validator() {
        assertEquals(emptyList<MovementValidationError>(), MovementValidator.validate(10, MovementKind.gasto, "a", null))
        assertEquals(
            listOf(MovementValidationError.montoInvalido, MovementValidationError.faltaCuenta),
            MovementValidator.validate(0, MovementKind.gasto, null, null),
        )
        assertEquals(listOf(MovementValidationError.mismaCuenta), MovementValidator.validate(5, MovementKind.transferencia, "a", "a"))
    }
}

class StatsAndPlannerTests {
    private val octubre = Stats.monthInterval(fecha(2026, 10, 15), bogota)

    private fun gasto(amount: Int, d: Int, method: PaymentMethod, cat: String? = null, status: MovementStatus = MovementStatus.confirmado, month: Int = 10) =
        MovementSnapshot("g$amount$d$month", amount, fecha(2026, month, d), MovementKind.gasto, method, "nu", null, cat, status)

    private val movimientos = listOf(
        MovementSnapshot("i", 3_000_000, fecha(2026, 10, 1), MovementKind.ingreso, PaymentMethod.transferencia, "nu", null, "Salario"),
        gasto(200_000, 5, PaymentMethod.credito, "Mercado"),
        gasto(50_000, 6, PaymentMethod.qr, "Restaurantes"),
        gasto(10_000, 7, PaymentMethod.llave),
        MovementSnapshot("t", 200_000, fecha(2026, 10, 20), MovementKind.transferencia, PaymentMethod.transferencia, "nu", "tc"),
        gasto(999, 8, PaymentMethod.debito, status = MovementStatus.porRevisar),
        MovementSnapshot("sep", 70_000, fecha(2026, 9, 30, 23), MovementKind.gasto, PaymentMethod.debito, "nu"),
    )

    @Test fun summaryCountsCardPurchasesNotCardPayments() {
        val s = Stats.summary(movimientos, octubre, 1_000_000)
        assertEquals(3_000_000, s.income)
        assertEquals(260_000, s.expenses)
        assertEquals(2_740_000, s.saved)
        assertEquals(1_740_000, s.possibleSaving)
    }

    @Test fun byCategoryAndMethod() {
        assertEquals(
            listOf(CategoryTotal("Mercado", 200_000), CategoryTotal("Restaurantes", 50_000), CategoryTotal("Sin categoría", 10_000)),
            Stats.expensesByCategory(movimientos, octubre),
        )
        assertEquals(
            listOf(MethodTotal(PaymentMethod.credito, 200_000), MethodTotal(PaymentMethod.qr, 50_000), MethodTotal(PaymentMethod.llave, 10_000)),
            Stats.expensesByMethod(movimientos, octubre),
        )
    }

    @Test fun averageDailyExpense() {
        assertEquals(31_000, Stats.averageDailyExpense(310_000, octubre, fecha(2026, 10, 10), bogota))
        assertEquals(10_000, Stats.averageDailyExpense(310_000, octubre, fecha(2026, 11, 5), bogota))
    }

    @Test fun savingsRateZeroWithoutIncome() {
        assertEquals(0.0, MonthSummary(0, 5_000, 0).savingsRate, 0.0)
    }

    @Test fun monthKeyAndDay31() {
        assertEquals("2026-10", RecurringPlanner.monthKey(fecha(2026, 10, 4), bogota))
        assertEquals(fecha(2026, 2, 28, 0), RecurringPlanner.dueDate(31, fecha(2026, 2, 10), bogota))
        assertEquals(fecha(2026, 11, 30, 0), RecurringPlanner.dueDate(31, fecha(2026, 11, 3), bogota))
    }

    @Test fun createsOnlyActiveAndMissing() {
        val arriendo = RecurringSnapshot("a", "Arriendo", 1_200_000, 5, null, true)
        val netflix = RecurringSnapshot("n", "Netflix", 40_000, 12, null, false)
        val internet = RecurringSnapshot("i", "Internet", 90_000, 15, null, true)
        val r = RecurringPlanner.occurrencesToCreate(fecha(2026, 10, 4), listOf(arriendo, netflix, internet), setOf("i"), bogota)
        assertEquals(listOf(DueOccurrence("a", fecha(2026, 10, 5, 0))), r)
    }

    @Test fun matchesExpenseNearDueDate() {
        val p = PendingOccurrence("p", 1_200_000, "nu", fecha(2026, 10, 5, 0))
        fun g(amount: Int, day: Int, account: String? = "nu", kind: MovementKind = MovementKind.gasto) =
            MovementSnapshot("x", amount, fecha(2026, 10, day), kind, PaymentMethod.llave, account)
        assertEquals("p", RecurringPlanner.matchingPending(g(1_150_000, 6), listOf(p)))
        assertNull(RecurringPlanner.matchingPending(g(1_000_000, 6), listOf(p)))
        assertNull(RecurringPlanner.matchingPending(g(1_200_000, 6, account = "otra"), listOf(p)))
        assertNull(RecurringPlanner.matchingPending(g(1_200_000, 6, kind = MovementKind.ingreso), listOf(p)))
        assertNull(RecurringPlanner.matchingPending(g(1_200_000, 20), listOf(p)))
    }
}

class ParsingTests {
    @Test fun colombianAmounts() {
        assertEquals(1_500_000, AmountParser.firstAmount("Compraste $ 1.500.000 en ÉXITO"))
        assertEquals(12_345, AmountParser.firstAmount("por $12.345,67 con tu tarjeta"))
        assertEquals(12_000, AmountParser.firstAmount("Recibiste 12.000 COP"))
        assertEquals(45_000, AmountParser.firstAmount("Pago de COP 45000 aprobado"))
        assertEquals(50_000, AmountParser.firstAmount("Enviaste $50.000."))
        assertEquals(1_234, AmountParser.firstAmount("USD style $1,234.56"))
        assertEquals(20_000, AmountParser.firstAmount("son 20.000 pesos"))
        assertNull(AmountParser.firstAmount("Tienes un nuevo mensaje"))
        assertNull(AmountParser.firstAmount("Saldo $0"))
    }

    @Test fun dotDecimalsWithoutComma() {
        assertEquals(50_000, AmountParser.normalize("50000.00"))
        assertEquals(5, AmountParser.firstAmount("Total $ 5.00"))
        assertEquals(1_500, AmountParser.firstAmount("Total $1.500"))
    }

    @Test fun foldRemovesAccents() {
        assertEquals("debito aei uala", TextNormalizer.fold("Débito ÁÉÍ Ualá"))
    }

    @Test fun creditCardPurchase() {
        val p = GenericParser.parse("Compraste $50.000 en EXITO CALLE 80 con tu tarjeta de crédito terminada en 1234", "notificaciones@nu.com.co")
        assertEquals(
            ParsedMovement(50_000, MovementKind.gasto, PaymentMethod.credito, "EXITO CALLE 80", Bank.nu, "1234", true), p,
        )
    }

    @Test fun incomeAndLlave() {
        val a = GenericParser.parse("Recibiste $ 1.500.000 de EMPRESA SAS en tu cuenta Lulo Bank")!!
        assertEquals(MovementKind.ingreso, a.kind)
        assertEquals(PaymentMethod.transferencia, a.method)
        assertEquals(Bank.lulo, a.bank)
        val b = GenericParser.parse("Te enviaron $80.000 a tu llave @juank desde Bre-B")!!
        assertEquals(MovementKind.ingreso, b.kind)
        assertEquals(PaymentMethod.llave, b.method)
        val c = GenericParser.parse("Enviaste $80.000 a la llave 3001234567 desde Dale!")!!
        assertEquals(MovementKind.gasto, c.kind)
        assertEquals(PaymentMethod.llave, c.method)
        assertEquals(Bank.dale, c.bank)
    }

    @Test fun qrAndDebit() {
        val q = GenericParser.parse("Pagaste $ 12.000 con QR en Tienda Don Pepe.")!!
        assertEquals(PaymentMethod.qr, q.method)
        assertEquals("Tienda Don Pepe", q.merchant)
        assertNull(q.bank)
        val d = GenericParser.parse("Compra con tarjeta débito Ualá por $35.900 en RAPPI")!!
        assertEquals(PaymentMethod.debito, d.method)
        assertEquals(Bank.uala, d.bank)
        assertTrue(d.isExplicit)
    }

    @Test fun cardPaymentsAreTransfersNotPurchases() {
        for (text in listOf(
            "Recibimos el abono a tu tarjeta de crédito por $300.000",
            "Pagaste $500.000 a tu tarjeta de crédito Nu",
            "Abonamos $200.000 a tu tarjeta de crédito",
            "Realizaste un abono de $300.000 a tu crédito de libre inversión",
        )) {
            val p = GenericParser.parse(text)!!
            assertEquals(text, MovementKind.transferencia, p.kind)
            assertFalse(text, p.isExplicit)
        }
    }

    @Test fun noAmountNoMovement() {
        assertNull(GenericParser.parse("Hola, tienes un nuevo mensaje"))
    }
}

class CaptureTests {
    private val nuAhorros = AccountHint("nu-a", Bank.nu, AccountKind.ahorros)
    private val nuTarjeta = AccountHint("nu-t", Bank.nu, AccountKind.credito, last4 = listOf("1234"))
    private val lulo = AccountHint("lulo", Bank.lulo, AccountKind.ahorros, emailSenders = listOf("alertas@lulobank.com"))
    private val hints = listOf(nuAhorros, nuTarjeta, lulo)

    @Test fun matchByLast4SenderAndBank() {
        assertEquals("nu-t", AccountMatcher.match(null, "1234", PaymentMethod.credito, null, hints))
        assertEquals("lulo", AccountMatcher.match(null, null, PaymentMethod.debito, "ALERTAS@lulobank.com", hints))
        assertEquals("nu-t", AccountMatcher.match(Bank.nu, null, PaymentMethod.credito, null, hints))
        assertEquals("nu-a", AccountMatcher.match(Bank.nu, null, PaymentMethod.llave, null, hints))
        assertNull(AccountMatcher.match(Bank.dale, null, PaymentMethod.qr, null, hints))
    }

    private val existing = listOf(
        MovementSnapshot("e", 50_000, fecha(2026, 10, 4, 12, 0), MovementKind.gasto, PaymentMethod.credito, "nu-t"),
    )

    @Test fun duplicates() {
        assertEquals("e", Deduplicator.duplicate(50_000, MovementKind.gasto, "nu-t", fecha(2026, 10, 4, 12, 9), existing))
        assertNull(Deduplicator.duplicate(50_000, MovementKind.gasto, "nu-t", fecha(2026, 10, 4, 12, 11), existing))
        assertNull(Deduplicator.duplicate(51_000, MovementKind.gasto, "nu-t", fecha(2026, 10, 4, 12, 1), existing))
        assertNull(Deduplicator.duplicate(50_000, MovementKind.gasto, "lulo", fecha(2026, 10, 4, 12, 1), existing))
        assertEquals("e", Deduplicator.duplicate(50_000, MovementKind.gasto, null, fecha(2026, 10, 4, 12, 3), existing))
    }

    @Test fun pipelineDecisions() {
        val explicit = ParsedMovement(50_000, MovementKind.gasto, PaymentMethod.credito, null, Bank.nu, null, true)
        val vague = explicit.copy(isExplicit = false)
        val at = fecha(2026, 10, 5)
        assertEquals(CaptureDecision.Unreadable, CapturePipeline.decide(null, null, at, emptyList()))
        assertEquals(CaptureDecision.Create(MovementStatus.confirmado), CapturePipeline.decide(explicit, "nu-t", at, emptyList()))
        assertEquals(CaptureDecision.Create(MovementStatus.porRevisar), CapturePipeline.decide(explicit, null, at, emptyList()))
        assertEquals(CaptureDecision.Create(MovementStatus.porRevisar), CapturePipeline.decide(vague, "nu-t", at, emptyList()))
        assertEquals(CaptureDecision.DuplicateOf("e"), CapturePipeline.decide(explicit, "nu-t", fecha(2026, 10, 4, 12, 2), existing))
    }
}

class StatementAndBackupTests {
    private fun parse(text: String, year: Int? = null) = StatementParser.parse(text, bogota, year)

    @Test fun purchaseWithBalance() {
        assertEquals(
            listOf(StatementEntry(fecha(2026, 10, 4), "COMPRA EXITO CALLE 80", 50_000, MovementKind.gasto, 1_234_567)),
            parse("04/10/2026 COMPRA EXITO CALLE 80 -50.000,00 1.234.567,00"),
        )
    }

    @Test fun incomeDebitMarkersAndShortDate() {
        val a = parse("05/10/2026 ABONO NOMINA $ 3.000.000").first()
        assertEquals(MovementKind.ingreso, a.kind)
        assertNull(a.balance)
        val b = parse("06-10-2026 PAGO QR TIENDA 12.000 DB").first()
        assertEquals(MovementKind.gasto, b.kind)
        val c = parse("07/10 COMPRA RAPPI (35.900)", 2026).first()
        assertEquals(fecha(2026, 10, 7), c.date)
        assertEquals(35_900, c.amount)
        assertTrue(parse("07/10 COMPRA RAPPI (35.900)").isEmpty())
    }

    @Test fun skipsLinesWithoutDateAndStoreNumbers() {
        assertTrue(parse("SALDO ANTERIOR 1.000.000\nPágina 1 de 3\nTotal débitos 500.000").isEmpty())
        val e = parse("08/10/2026 COMPRA TIENDA 1234 -20.000").first()
        assertEquals("COMPRA TIENDA 1234", e.description)
        assertEquals(20_000, e.amount)
    }

    @Test fun semicolonCsv() {
        assertEquals(
            listOf(StatementEntry(fecha(2026, 10, 9), "COMPRA D1", 8_500, MovementKind.gasto, 1_200_000)),
            parse("2026-10-09;COMPRA D1;-8.500;1.200.000"),
        )
    }

    @Test fun stackedLayoutWithPeriodYearAndPageMarkers() {
        // Ejemplo sintético con la estructura de un extracto real: fecha, descripción y monto en renglones separados.
        val text = """
            Período
            01 - 30 SEP 2026
            Dinero en tu cuenta
            ${'$'}11.752,29
            Movimientos
            01 sep
            Compra en UBER*RIDES con tarjeta débito
            -${'$'}4.300,00
            01 sep
            Reembolso realizado
            +${'$'}4.300,00
            02 sep
            Pagaste tu tarjeta
            -${'$'}7.500,00
            2 / 13
            03 sep
            Recibiste de Fulano de Tal
            +${'$'}250.000,00
        """.trimIndent()
        val e = parse(text, 2025)
        assertEquals(listOf(4_300, 4_300, 7_500, 250_000), e.map { it.amount })
        assertEquals(
            listOf(MovementKind.gasto, MovementKind.ingreso, MovementKind.transferencia, MovementKind.ingreso), e.map { it.kind },
        )
        assertEquals("Compra en UBER*RIDES con tarjeta débito", e.first().description)
        assertEquals(fecha(2026, 9, 1), e.first().date)
    }

    @Test fun sameLineTextualMonthAndCardPayment() {
        val e = parse("01 sep Compra en UBER*RIDES con tarjeta débito -${'$'}4.300,00\n02 sep Recibiste de Mengano +${'$'}250.000,00", 2026)
        assertEquals(listOf(4_300, 250_000), e.map { it.amount })
        assertEquals(listOf(MovementKind.gasto, MovementKind.ingreso), e.map { it.kind })
        assertEquals(MovementKind.transferencia, parse("02/09/2026 PAGASTE TU TARJETA -7.500,00").first().kind)
        assertTrue(parse("01 sep\nCompra en X\n-${'$'}1.000,00").isEmpty())
    }

    @Test fun reconcilerDuplicates() {
        val existing = listOf(MovementSnapshot("m", 50_000, fecha(2026, 10, 4, 18), MovementKind.gasto, PaymentMethod.debito, "c"))
        fun entry(amount: Int, day: Int) = StatementEntry(fecha(2026, 10, day, 0), "X", amount, MovementKind.gasto, null)
        assertTrue(StatementReconciler.isDuplicate(entry(50_000, 5), "c", existing, bogota))
        assertFalse(StatementReconciler.isDuplicate(entry(51_000, 4), "c", existing, bogota))
        assertFalse(StatementReconciler.isDuplicate(entry(50_000, 7), "c", existing, bogota))
        assertFalse(StatementReconciler.isDuplicate(entry(50_000, 5), "otra", existing, bogota))
    }

    @Test fun backupRotation() {
        assertEquals("PlataClara-2026-10-04.json", BackupRotation.fileName(fecha(2026, 10, 4, 23, 30), bogota))
        assertTrue(BackupRotation.isBackupFile("PlataClara-2026-10-04.json"))
        assertFalse(BackupRotation.isBackupFile("PlataClara-respaldo-2026-10-04.json"))
        assertFalse(BackupRotation.isBackupFile("PlataClara-2026-10-04.json.icloud"))
        val names = (1..10).map { "PlataClara-2026-10-%02d.json".format(it) } + "notas.txt"
        assertEquals(
            setOf("PlataClara-2026-10-01.json", "PlataClara-2026-10-02.json", "PlataClara-2026-10-03.json"),
            BackupRotation.filesToDelete(names, 7).toSet(),
        )
        assertEquals("PlataClara-2026-10-02.json", BackupRotation.latest(listOf("x.json", "PlataClara-2026-09-30.json", "PlataClara-2026-10-02.json")))
        assertFalse(BackupRotation.shouldWrite(0, 0))
        assertTrue(BackupRotation.shouldWrite(1, 0))
    }

    private fun sample(version: Int = BackupCodec.CURRENT_VERSION): AppData {
        val at = Instant.parse("2026-10-04T17:00:00Z")
        return AppData(
            formatVersion = version, exportedAt = at,
            accounts = listOf(Account("a1", "Nu", Bank.nu, AccountKind.credito, 0, 2_000_000, 20, 5, listOf("1234"), "Nu Mastercard", emptyList(), at)),
            categories = listOf(Category("c1", "Mercado", "cart", "#2E7D32", false, 0)),
            movements = listOf(Movement("m1", 50_000, at, MovementKind.gasto, PaymentMethod.credito, "a1", null, "c1", "Éxito", null, CaptureSource.applePay, MovementStatus.confirmado)),
            recurring = listOf(Recurring("r1", "Arriendo", 1_200_000, 5, "a1", PaymentMethod.llave, null, true, true)),
            occurrences = listOf(Occurrence("o1", "r1", "2026-10", at, OccurrenceStatus.pendiente)),
        )
    }

    @Test fun backupRoundTripAndIosFieldNames() {
        val text = BackupCodec.encode(sample())
        assertEquals(sample(), BackupCodec.decode(text))
        assertTrue(text.contains("\"accountID\""))
        assertTrue(text.contains("\"2026-10-04T17:00:00Z\""))
        assertFalse(text.contains("\"note\""))
    }

    @Test fun decodesIosFile() {
        val ios = """{"formatVersion":1,"exportedAt":"2026-10-04T17:00:00Z","accounts":[],"categories":[],"movements":[],"recurring":[],"occurrences":[]}"""
        assertEquals(0, BackupCodec.decode(ios).movements.size)
    }

    @Test fun rejectsOtherVersionAndGarbage() {
        try { BackupCodec.decode(BackupCodec.encode(sample(99))); fail("debía rechazar la versión") }
        catch (e: BackupException.UnsupportedVersion) { assertEquals(99, e.version) }
        try { BackupCodec.decode("no soy json"); fail("debía rechazar el archivo") }
        catch (e: BackupException.InvalidFile) { }
    }
}
