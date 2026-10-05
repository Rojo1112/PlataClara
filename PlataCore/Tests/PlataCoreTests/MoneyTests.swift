import XCTest
@testable import PlataCore

final class MoneyTests: XCTestCase {
    func testFormatsColombianPesos() {
        XCTAssertEqual(Money.format(0), "$ 0")
        XCTAssertEqual(Money.format(999), "$ 999")
        XCTAssertEqual(Money.format(1000), "$ 1.000")
        XCTAssertEqual(Money.format(1_234_567), "$ 1.234.567")
        XCTAssertEqual(Money.format(-5000), "-$ 5.000")
    }
}
