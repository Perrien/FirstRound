import Foundation
import XCTest

final class FixtureReaderTests: XCTestCase {
    func testLoadsCommittedGoldenVectors() throws {
        let loadsRoot = try loadObject(named: "loads")
        let goldenRoot = try loadObject(named: "golden")
        let loads = try XCTUnwrap(loadsRoot["loads"] as? [[String: Any]], "loads.json has no loads array")
        let cases = try XCTUnwrap(goldenRoot["cases"] as? [[String: Any]], "golden.json has no cases array")

        let loadIDs = Set(try loads.map { load in
            try XCTUnwrap(load["id"] as? String, "A load has no string id")
        })
        XCTAssertEqual(loads.count, 6)
        XCTAssertEqual(loadIDs.count, loads.count, "Load IDs must be unique")
        XCTAssertEqual(cases.count, 36)

        var rowCount = 0
        for (caseIndex, vectorCase) in cases.enumerated() {
            let loadID = try XCTUnwrap(vectorCase["loadId"] as? String, "Case \(caseIndex) has no loadId")
            XCTAssertTrue(loadIDs.contains(loadID), "Case \(caseIndex) refers to unknown load \(loadID)")

            let rows = try XCTUnwrap(vectorCase["rows"] as? [[String: Any]], "Case \(caseIndex) has no rows array")
            rowCount += rows.count
            for (rowIndex, row) in rows.enumerated() {
                for key in ["rangeM", "dropM", "windageM", "velocityMps", "timeOfFlightS"] {
                    XCTAssertTrue(row[key] is NSNumber, "Case \(caseIndex), row \(rowIndex) lacks numeric \(key)")
                }
            }
        }

        XCTAssertEqual(rowCount, 660)
        print("Golden fixtures: \(loads.count) loads, \(cases.count) cases, \(rowCount) rows")
    }

    private func loadObject(named name: String) throws -> [String: Any] {
        let bundle = Bundle(for: FixtureReaderTests.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"),
                                "\(name).json is missing from the First RoundTests bundle")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any],
                             "\(name).json does not contain a JSON object")
    }
}
