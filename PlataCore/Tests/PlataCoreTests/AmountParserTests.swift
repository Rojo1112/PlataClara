import XCTest
@testable import PlataCore

final class AmountParserTests: XCTestCase {
    func testColombianFormats() {
        XCTAssertEqual(AmountParser.firstAmount(in: "Compraste $ 1.500.000 en ÉXITO"), 1_500_000)
        XCTAssertEqual(AmountParser.firstAmount(in: "por $12.345,67 con tu tarjeta"), 12_345)
        XCTAssertEqual(AmountParser.firstAmount(in: "Recibiste 12.000 COP"), 12_000)
        XCTAssertEqual(AmountParser.firstAmount(in: "Pago de COP 45000 aprobado"), 45_000)
        XCTAssertEqual(AmountParser.firstAmount(in: "Enviaste $50.000."), 50_000)
        XCTAssertEqual(AmountParser.firstAmount(in: "Total $5"), 5)
        XCTAssertEqual(AmountParser.firstAmount(in: "USD style $1,234.56"), 1_234)
        XCTAssertEqual(AmountParser.firstAmount(in: "son 20.000 pesos"), 20_000)
    }

    func testNoAmount() {
        XCTAssertNil(AmountParser.firstAmount(in: "Tienes un nuevo mensaje"))
        XCTAssertNil(AmountParser.firstAmount(in: "Saldo $0"))
    }

    func testNormalizeWithoutSymbol() {
        XCTAssertEqual(AmountParser.normalize("12.000,00"), 12_000)
        XCTAssertEqual(AmountParser.normalize("12000"), 12_000)
    }

    func testFoldRemovesAccentsAndCase() {
        XCTAssertEqual(TextNormalizer.fold("Débito ÁÉÍ Ualá"), "debito aei uala")
    }

    func testDotDecimalsWithoutComma() {
        XCTAssertEqual(AmountParser.normalize("50000.00"), 50_000)
        XCTAssertEqual(AmountParser.firstAmount(in: "Total $ 5.00"), 5)
        XCTAssertEqual(AmountParser.firstAmount(in: "Total $1.500"), 1_500)
    }
}
