import Foundation
import XCTest
@testable import First_Round

final class UnitConversionTests: XCTestCase {
    func testKnownBoxToSIValues() throws {
        XCTAssertEqual(try XCTUnwrap(UnitConversions.grainsToKilograms(300)),
                       0.019439673, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(UnitConversions.inchesToMeters(1.68)),
                       0.042672, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(UnitConversions.feetPerSecondToMetersPerSecond(2725)),
                       830.58, accuracy: 1e-10)
        XCTAssertEqual(try XCTUnwrap(UnitConversions.inchesPerTurnToMetersPerTurn(10)),
                       0.254, accuracy: 1e-12)
    }

    func testInvalidMeasurementsReturnNoResult() {
        XCTAssertNil(UnitConversions.positiveNumber(from: ""))
        XCTAssertNil(UnitConversions.positiveNumber(from: "  "))
        XCTAssertNil(UnitConversions.positiveNumber(from: "abc"))
        XCTAssertNil(UnitConversions.positiveNumber(from: "0"))
        XCTAssertNil(UnitConversions.positiveNumber(from: "-2"))
        XCTAssertNil(UnitConversions.positiveNumber(from: "nan"))
        XCTAssertEqual(UnitConversions.positiveNumber(from: " 300 "), 300)

        XCTAssertNil(UnitConversions.grainsToKilograms(0))
        XCTAssertNil(UnitConversions.grainsToKilograms(-300))
        XCTAssertNil(UnitConversions.inchesToMeters(.infinity))
        XCTAssertNil(UnitConversions.feetPerSecondToMetersPerSecond(.nan))
        XCTAssertNil(UnitConversions.inchesPerTurnToMetersPerTurn(-10))
    }
}
