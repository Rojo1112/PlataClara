package com.rojo1112.plataclara.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ActionsTests {
    private val at = Instant.parse("2026-10-04T17:00:00Z")
    private val nuAhorros = Account("nu-a", "Nu ahorros", Bank.nu, AccountKind.ahorros, 0, createdAt = at)
    private val nuTarjeta = Account("nu-t", "Nu crédito", Bank.nu, AccountKind.credito, 0, last4 = listOf("1234"), createdAt = at)
    private val base = AppData(exportedAt = at, accounts = listOf(nuAhorros, nuTarjeta))

    private fun withRent(accountId: String? = "nu-a", active: Boolean = true) = base.copy(
        recurring = listOf(Recurring("r1", "Arriendo", 1_200_000, 1, accountId, PaymentMethod.llave, null, active, true)),
    )

    @Test fun explicitNoticeWithKnownAccountIsRegistered() {
        val (d, outcome) = Actions.ingestText(
            base, "Compraste $50.000 en EXITO con tu tarjeta de crédito terminada en 1234", null,
            CaptureSource.captura, fecha(2026, 10, 5), bogota,
        )
        assertTrue(outcome is CaptureOutcome.Registered)
        assertEquals("nu-t", d.movements.single().accountID)
        assertEquals(MovementStatus.confirmado, d.movements.single().status)
    }

    @Test fun unknownAccountGoesToReviewAndUnreadableKeepsText() {
        val (d1, o1) = Actions.ingestText(base, "Pagaste $12.000 con QR en Tienda", null, CaptureSource.captura, fecha(2026, 10, 5), bogota)
        assertTrue(o1 is CaptureOutcome.Review)
        assertEquals(MovementStatus.porRevisar, d1.movements.single().status)
        val (d2, o2) = Actions.ingestText(base, "Hola mundo", null, CaptureSource.captura, fecha(2026, 10, 5), bogota)
        assertTrue(o2 is CaptureOutcome.Review)
        assertEquals("Hola mundo", d2.movements.single().rawText)
        assertEquals(0, d2.movements.single().amount)
    }

    @Test fun forcedAccountConfirmsExplicitNotice() {
        val (d, o) = Actions.ingestText(
            base, "Pagaste $12.000 con QR en Tienda", null, CaptureSource.captura, fecha(2026, 10, 5), bogota, forcedAccountId = "nu-a",
        )
        assertTrue(o is CaptureOutcome.Registered)
        assertEquals("nu-a", d.movements.single().accountID)
    }

    @Test fun duplicateMergesAccountIntoFirst() {
        val (d1, _) = Actions.ingestText(base, "Pagaste $20.000 con QR en Tienda", null, CaptureSource.captura, fecha(2026, 10, 5, 12, 0), bogota)
        assertNull(d1.movements.single().accountID)
        val (d2, o2) = Actions.ingestText(
            d1, "Pagaste $20.000 con QR en Tienda", null, CaptureSource.captura, fecha(2026, 10, 5, 12, 5), bogota, forcedAccountId = "nu-a",
        )
        assertTrue(o2 is CaptureOutcome.Duplicate)
        val m = d2.movements.single()
        assertEquals("nu-a", m.accountID)
        assertEquals(MovementStatus.confirmado, m.status)
    }

    @Test fun cardPaymentNoticeIsTransferToReview() {
        val (d, o) = Actions.ingestText(base, "Pagaste $500.000 a tu tarjeta de crédito Nu", null, CaptureSource.captura, fecha(2026, 10, 5), bogota)
        assertTrue(o is CaptureOutcome.Review)
        assertEquals(MovementKind.transferencia, d.movements.single().kind)
    }

    @Test fun markPaidThenReopenDeletesFixedMovement() {
        var d = Actions.ensureMonth(withRent(), fecha(2026, 10, 4), bogota)
        val occ = d.occurrences.single()
        assertEquals(1_200_000, Actions.pendingTotal(d, "2026-10"))
        d = Actions.markPaid(d, occ.id, 1_250_000, fecha(2026, 10, 4))
        assertEquals(0, Actions.pendingTotal(d, "2026-10"))
        assertEquals(MovementStatus.confirmado, d.movements.single().status)
        d = Actions.reopen(d, occ.id)
        assertTrue(d.movements.isEmpty())
        assertEquals(1_200_000, Actions.pendingTotal(d, "2026-10"))
    }

    @Test fun markPaidWithoutAccountIsStillConfirmed() {
        var d = Actions.ensureMonth(withRent(accountId = null), fecha(2026, 10, 4), bogota)
        d = Actions.markPaid(d, d.occurrences.single().id, 1_200_000, fecha(2026, 10, 4))
        assertEquals(MovementStatus.confirmado, d.movements.single().status)
    }

    @Test fun inactiveFixedIsNotCounted() {
        val d = Actions.ensureMonth(withRent(active = false), fecha(2026, 10, 4), bogota)
        assertEquals(0, Actions.pendingTotal(d, "2026-10"))
    }

    @Test fun expenseLinksToFixedEvenBeforeTheMonthWasOpened() {
        // El aviso del 1 de octubre llega antes de abrir la app ese mes: no hay pendiente todavía.
        val movement = Movement("m", 1_200_000, fecha(2026, 10, 1, 7), MovementKind.gasto, PaymentMethod.llave, "nu-a",
            source = CaptureSource.captura, status = MovementStatus.confirmado)
        val d = Actions.saveMovement(withRent(), movement, bogota)
        assertEquals(OccurrenceStatus.pagado, d.occurrences.single { it.monthKey == "2026-10" }.status)
        assertEquals(0, Actions.pendingTotal(d, "2026-10"))
        assertEquals(d.occurrences.single { it.monthKey == "2026-10" }.id, d.movements.single().occurrenceID)
    }

    @Test fun expenseLinksToNextMonthsFixedWithinWindow() {
        val movement = Movement("m", 1_200_000, fecha(2026, 9, 29), MovementKind.gasto, PaymentMethod.llave, "nu-a",
            source = CaptureSource.manual, status = MovementStatus.confirmado)
        val d = Actions.saveMovement(withRent(), movement, bogota)
        assertEquals(OccurrenceStatus.pagado, d.occurrences.single { it.monthKey == "2026-10" }.status)
    }

    @Test fun deletingOrChangingLinkedMovementReopensFixed() {
        val movement = Movement("m", 1_200_000, fecha(2026, 10, 1, 9), MovementKind.gasto, PaymentMethod.llave, "nu-a",
            source = CaptureSource.manual, status = MovementStatus.confirmado)
        val linked = Actions.saveMovement(withRent(), movement, bogota)
        val deleted = Actions.deleteMovement(linked, "m")
        assertEquals(OccurrenceStatus.pendiente, deleted.occurrences.single { it.monthKey == "2026-10" }.status)
        val asIncome = Actions.saveMovement(linked, linked.movements.single().copy(kind = MovementKind.ingreso), bogota)
        assertEquals(OccurrenceStatus.pendiente, asIncome.occurrences.single { it.monthKey == "2026-10" }.status)
        assertNull(asIncome.movements.single().occurrenceID)
    }

    @Test fun statementImportCreatesConfirmedMovements() {
        val entries = StatementParser.parse("04/10/2026 COMPRA EXITO -50.000,00\n05/10/2026 ABONO NOMINA 3.000.000", bogota, null)
        val d = Actions.importStatement(base, nuAhorros, entries, bogota)
        assertEquals(2, d.movements.size)
        assertEquals(listOf(MovementKind.gasto, MovementKind.ingreso), d.movements.map { it.kind })
        assertTrue(d.movements.all { it.source == CaptureSource.extracto && it.accountID == "nu-a" })
        assertEquals(2_950_000, Ledger.balance(nuAhorros.snapshot(), Actions.snapshots(d)))
    }

    @Test fun seedCreatesCategoriesOnce() {
        val seeded = Actions.seedIfNeeded(base)
        assertEquals(14, seeded.categories.size)
        assertEquals(seeded, Actions.seedIfNeeded(seeded))
    }
}
