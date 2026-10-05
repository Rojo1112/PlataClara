import XCTest
@testable import PlataCore

final class CaptureTests: XCTestCase {
    let nuAhorros = AccountHint(id: UUID(), bank: .nu, kind: .ahorros, last4: [], walletCardName: nil, emailSenders: [])
    let nuTarjeta = AccountHint(id: UUID(), bank: .nu, kind: .credito, last4: ["1234"], walletCardName: "Nu Mastercard", emailSenders: [])
    let lulo = AccountHint(id: UUID(), bank: .lulo, kind: .ahorros, last4: [], walletCardName: "Lulo Débito", emailSenders: ["alertas@lulobank.com"])
    var hints: [AccountHint] { [nuAhorros, nuTarjeta, lulo] }

    // MARK: AccountMatcher
    func testMatchByLast4() {
        XCTAssertEqual(AccountMatcher.match(bank: nil, last4: "1234", method: .credito, sender: nil, hints: hints), nuTarjeta.id)
    }

    func testMatchBySender() {
        XCTAssertEqual(AccountMatcher.match(bank: nil, last4: nil, method: .debito, sender: "ALERTAS@lulobank.com", hints: hints), lulo.id)
    }

    func testMatchByBankUsesKindWhenSeveral() {
        XCTAssertEqual(AccountMatcher.match(bank: .nu, last4: nil, method: .credito, sender: nil, hints: hints), nuTarjeta.id)
        XCTAssertEqual(AccountMatcher.match(bank: .nu, last4: nil, method: .llave, sender: nil, hints: hints), nuAhorros.id)
        XCTAssertNil(AccountMatcher.match(bank: .dale, last4: nil, method: .qr, sender: nil, hints: hints))
    }

    func testMatchWalletCard() {
        XCTAssertEqual(AccountMatcher.match(walletCardName: "nu mastercard", hints: hints)?.id, nuTarjeta.id)
        XCTAssertNil(AccountMatcher.match(walletCardName: "Visa Otro", hints: hints))
    }

    // MARK: Deduplicator
    func existing(_ account: UUID?) -> [MovementSnapshot] {
        [MovementSnapshot(amount: 50_000, date: fecha(2026, 10, 4, 12, 0), kind: .gasto, method: .credito, accountID: account)]
    }

    func testDuplicateWithinTenMinutes() {
        let e = existing(nuTarjeta.id)
        XCTAssertEqual(Deduplicator.duplicate(amount: 50_000, kind: .gasto, accountID: nuTarjeta.id, date: fecha(2026, 10, 4, 12, 9), existing: e), e[0].id)
        XCTAssertNil(Deduplicator.duplicate(amount: 50_000, kind: .gasto, accountID: nuTarjeta.id, date: fecha(2026, 10, 4, 12, 11), existing: e))
        XCTAssertNil(Deduplicator.duplicate(amount: 51_000, kind: .gasto, accountID: nuTarjeta.id, date: fecha(2026, 10, 4, 12, 1), existing: e))
        XCTAssertNil(Deduplicator.duplicate(amount: 50_000, kind: .gasto, accountID: lulo.id, date: fecha(2026, 10, 4, 12, 1), existing: e))
    }

    func testOneSideWithoutAccountStillDuplicates() {
        let e = existing(nuTarjeta.id)
        XCTAssertEqual(Deduplicator.duplicate(amount: 50_000, kind: .gasto, accountID: nil, date: fecha(2026, 10, 4, 12, 3), existing: e), e[0].id)
    }

    // MARK: Apple Pay
    func testApplePayWithKnownCard() {
        let r = ApplePayInput.parse(amount: "$50.000,00", merchant: "Éxito", cardName: "Nu Mastercard", hints: hints)
        XCTAssertEqual(r?.accountID, nuTarjeta.id)
        XCTAssertEqual(r?.movement.method, .credito)
        XCTAssertEqual(r?.movement.amount, 50_000)
        XCTAssertEqual(r?.movement.isExplicit, true)
    }

    func testApplePayPlainNumberAndDebitCard() {
        let r = ApplePayInput.parse(amount: "12000", merchant: "", cardName: "Lulo Débito", hints: hints)
        XCTAssertEqual(r?.movement.amount, 12_000)
        XCTAssertEqual(r?.movement.method, .debito)
        XCTAssertNil(r?.movement.merchant)
    }

    func testApplePayUnknownCardHasNoAccount() {
        let r = ApplePayInput.parse(amount: "$8.000", merchant: "Tienda", cardName: "Otra", hints: hints)
        XCTAssertNil(r?.accountID)
        XCTAssertNil(ApplePayInput.parse(amount: "gratis", merchant: "", cardName: "Otra", hints: hints))
    }

    // MARK: CapturePipeline
    func testPipelineDecisions() {
        let explicit = ParsedMovement(amount: 50_000, kind: .gasto, method: .credito, merchant: nil, bank: .nu, last4: nil, isExplicit: true)
        var vague = explicit
        vague.isExplicit = false
        let at = fecha(2026, 10, 5)
        XCTAssertEqual(CapturePipeline.decide(parsed: nil, accountID: nil, date: at, existing: []), .unreadable)
        XCTAssertEqual(CapturePipeline.decide(parsed: explicit, accountID: nuTarjeta.id, date: at, existing: []), .create(.confirmado))
        XCTAssertEqual(CapturePipeline.decide(parsed: explicit, accountID: nil, date: at, existing: []), .create(.porRevisar))
        XCTAssertEqual(CapturePipeline.decide(parsed: vague, accountID: nuTarjeta.id, date: at, existing: []), .create(.porRevisar))
        let e = existing(nuTarjeta.id)
        XCTAssertEqual(CapturePipeline.decide(parsed: explicit, accountID: nuTarjeta.id, date: fecha(2026, 10, 4, 12, 2), existing: e), .duplicateOf(e[0].id))
    }

    func testWalletPrefersExactNameOverContainment() {
        let ahorros = AccountHint(id: UUID(), bank: .nu, kind: .ahorros, last4: [], walletCardName: "Nu", emailSenders: [])
        let credito = AccountHint(id: UUID(), bank: .nu, kind: .credito, last4: [], walletCardName: "Nu Crédito", emailSenders: [])
        XCTAssertEqual(AccountMatcher.match(walletCardName: "Nu Crédito", hints: [ahorros, credito])?.id, credito.id)
        XCTAssertEqual(AccountMatcher.match(walletCardName: "nu", hints: [credito, ahorros])?.id, ahorros.id)
        XCTAssertNil(AccountMatcher.match(walletCardName: "Nu Cr", hints: [ahorros, credito]))
    }
}
