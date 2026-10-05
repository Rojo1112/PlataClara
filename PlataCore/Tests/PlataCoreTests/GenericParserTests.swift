import XCTest
@testable import PlataCore

final class GenericParserTests: XCTestCase {
    func testCreditCardPurchaseWithLast4() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Compraste $50.000 en EXITO CALLE 80 con tu tarjeta de crédito terminada en 1234",
                                    sender: "notificaciones@nu.com.co")
        XCTAssertEqual(p, ParsedMovement(amount: 50_000, kind: .gasto, method: .credito, merchant: "EXITO CALLE 80",
                                         bank: .nu, last4: "1234", isExplicit: true))
    }

    func testIncomeByTransfer() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Recibiste $ 1.500.000 de EMPRESA SAS en tu cuenta Lulo Bank")
        XCTAssertEqual(p?.amount, 1_500_000)
        XCTAssertEqual(p?.kind, .ingreso)
        XCTAssertEqual(p?.method, .transferencia)
        XCTAssertEqual(p?.bank, .lulo)
        XCTAssertEqual(p?.isExplicit, true)
    }

    func testIncomeByLlave() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Te enviaron $80.000 a tu llave @juank desde Bre-B")
        XCTAssertEqual(p?.kind, .ingreso)
        XCTAssertEqual(p?.method, .llave)
    }

    func testOutgoingLlave() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Enviaste $80.000 a la llave 3001234567 desde Dale!")
        XCTAssertEqual(p?.kind, .gasto)
        XCTAssertEqual(p?.method, .llave)
        XCTAssertEqual(p?.bank, .dale)
    }

    func testQrPaymentWithoutBankIsNotFullyKnown() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Pagaste $ 12.000 con QR en Tienda Don Pepe.")
        XCTAssertEqual(p?.method, .qr)
        XCTAssertEqual(p?.merchant, "Tienda Don Pepe")
        XCTAssertNil(p?.bank)
    }

    func testDebitCard() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Compra con tarjeta débito Ualá por $35.900 en RAPPI", sender: nil)
        XCTAssertEqual(p?.method, .debito)
        XCTAssertEqual(p?.bank, .uala)
        XCTAssertEqual(p?.isExplicit, true)
    }

    func testCardPaymentIsTransferNotIncome() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Recibimos el abono a tu tarjeta de crédito por $300.000")
        XCTAssertEqual(p?.kind, .transferencia)
        XCTAssertEqual(p?.method, .transferencia)
        XCTAssertEqual(p?.isExplicit, false)
    }

    func testGenericPurchaseIsNotExplicit() {
        // Ejemplo sintético
        let p = GenericParser.parse(text: "Compra aprobada por $20.000")
        XCTAssertEqual(p?.kind, .gasto)
        XCTAssertEqual(p?.isExplicit, false)
    }

    func testTextWithoutAmount() {
        XCTAssertNil(GenericParser.parse(text: "Hola, tienes un nuevo mensaje"))
    }

    func testBankFromSenderOnly() {
        XCTAssertEqual(BankDetector.detect(text: "Hiciste un pago", sender: "alertas@lulobank.com"), .lulo)
        XCTAssertNil(BankDetector.detect(text: "Hiciste un pago nuevo", sender: nil))
    }

    func testOutgoingCardPaymentIsTransferNotPurchase() {
        // Ejemplo sintético
        for text in ["Pagaste $500.000 a tu tarjeta de crédito Nu", "Abonamos $200.000 a tu tarjeta de crédito",
                     "Realizaste un abono de $300.000 a tu crédito de libre inversión"] {
            let p = GenericParser.parse(text: text)
            XCTAssertEqual(p?.kind, .transferencia, text)
            XCTAssertEqual(p?.isExplicit, false, text)
        }
    }
}
