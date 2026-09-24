import Foundation
import XCTest
@testable import First_Round

final class TrajectoryVectorTests: XCTestCase {
    func testEveryLegacyCaseMatchesAllGoldenRows() throws {
        let loadsRoot = try loadObject(named: "loads")
        let goldenRoot = try loadObject(named: "golden")
        let validation = try XCTUnwrap(loadsRoot["validation"] as? [String: Any])
        let zeroRangeM = try number(validation, "zeroRangeM", as: Double.self)
        let loads = try XCTUnwrap(loadsRoot["loads"] as? [[String: Any]])
        let cases = try XCTUnwrap(goldenRoot["cases"] as? [[String: Any]])
        let atmospheres = try XCTUnwrap(validation["atmospheres"] as? [[String: Any]])
        let winds = try XCTUnwrap(validation["windCases"] as? [[String: Any]])
        let loadByID = Dictionary(uniqueKeysWithValues: try loads.map { load -> (String, [String: Any]) in
            (try XCTUnwrap(load["id"] as? String), load)
        })

        var comparedRows = 0
        var worstDifference = 0.0
        var worstLabel = ""
        var worstAbsoluteDifference = 0.0
        var worstAbsoluteLabel = ""
        var worstAbsoluteUnit = ""
        var comparisonFailures = 0
        var zeroRowAbsoluteComparisons = 0
        for (caseIndex, vectorCase) in cases.enumerated() {
            let loadID = try XCTUnwrap(vectorCase["loadId"] as? String)
            let atmosphereName = try XCTUnwrap(vectorCase["atmosphere"] as? String)
            let windName = try XCTUnwrap(vectorCase["wind"] as? String)
            let loadRecord = try XCTUnwrap(loadByID[loadID])
            let si = try XCTUnwrap(loadRecord["si"] as? [String: Any])
            let loadRanges = try XCTUnwrap(loadRecord["ranges"] as? [String: Any])
            let atmosphereRecord = try XCTUnwrap(atmospheres.first { $0["name"] as? String == atmosphereName })
            let windRecord = try XCTUnwrap(winds.first { $0["name"] as? String == windName })
            let expectedRows = try XCTUnwrap(vectorCase["rows"] as? [[String: Any]])
            let atmosphereValues = atmosphereRecord
            let windValues = try XCTUnwrap(windRecord["windVec"] as? [String: Any])
            let muzzleVelocityDouble = try number(si, "muzzleVelocityMps", as: Double.self)
            let twistDouble = try number(si, "twistM", as: Double.self)
            let matrixSpinRate = Float((2 * Double.pi * muzzleVelocityDouble) / twistDouble)

            let request = BallisticRequest(
                load: BallisticLoad(
                    massKg: try number(si, "massKg"), diameterM: try number(si, "diameterM"),
                    lengthM: try number(si, "lengthM"), bc: try number(si, "bc"),
                    dragModel: try dragModel(si), muzzleVelocityMps: try number(si, "muzzleVelocityMps"),
                    twistM: try number(si, "twistM"), spinRateOverrideRadPerSecond: matrixSpinRate),
                atmosphere: AtmosphereInput(
                    temperatureK: try number(atmosphereValues, "temperatureK"),
                    altitudeM: try number(atmosphereValues, "altitudeM"),
                    humidity: try number(atmosphereValues, "humidity"),
                    pressurePa: try number(atmosphereValues, "pressurePa")),
                wind: ConstantWind(xMps: try number(windValues, "x"), yMps: try number(windValues, "y"), zMps: try number(windValues, "z")),
                ranges: RangeRequest(zeroRangeM: Float(zeroRangeM),
                                    maxRangeM: try number(loadRanges, "maxRangeM"),
                                    stepM: try number(loadRanges, "stepM")),
                zeroMode: .legacyWindAware)

            let actualRows = try TrajectorySolver(request: request).solve().rows
            XCTAssertEqual(actualRows.count, expectedRows.count,
                           "Case \(caseIndex) \(loadID), \(atmosphereName), \(windName) row count")
            for (rowIndex, pair) in zip(actualRows, expectedRows).enumerated() {
                let actual = pair.0
                let expected = pair.1
                for (field, actualValue, key) in [
                    ("rangeM", actual.rangeM, "rangeM"), ("dropM", actual.dropM, "dropM"),
                    ("windageM", actual.windageM, "windageM"), ("velocityMps", actual.velocityMps, "velocityMps"),
                    ("timeOfFlightS", actual.timeOfFlightS, "timeOfFlightS")
                ] {
                    let expectedValue = try number(expected, key, as: Double.self)
                    let actualDouble = Double(actualValue)
                    let scale = max(abs(actualDouble), abs(expectedValue), 1e-12)
                    let absoluteDifference = abs(actualDouble - expectedValue)
                    let difference = absoluteDifference / scale
                    let isZeroRowDisplacement = abs(Double(actual.rangeM) - zeroRangeM) <= 1e-6
                        && (field == "dropM" || field == "windageM")
                    if absoluteDifference > worstAbsoluteDifference {
                        worstAbsoluteDifference = absoluteDifference
                        worstAbsoluteLabel = "\(loadID) / \(atmosphereName) / \(windName), row \(rowIndex), \(field)"
                        worstAbsoluteUnit = field == "velocityMps" ? "m/s" : (field == "timeOfFlightS" ? "s" : "m")
                    }
                    let passes: Bool
                    if isZeroRowDisplacement {
                        zeroRowAbsoluteComparisons += 1
                        passes = absoluteDifference <= 5e-8
                    } else {
                        passes = difference <= 1e-4
                    }
                    if !passes { comparisonFailures += 1 }
                    comparedRows += field == "rangeM" ? 1 : 0
                    if difference > worstDifference {
                        worstDifference = difference
                        worstLabel = "\(loadID) / \(atmosphereName) / \(windName), row \(rowIndex), \(field)"
                    }
                    XCTAssertTrue(passes,
                        "\(loadID) / \(atmosphereName) / \(windName), range \(actual.rangeM), \(field): expected \(expectedValue), actual \(actualDouble), absolute difference \(absoluteDifference), relative difference \(difference), zero-row absolute exception \(isZeroRowDisplacement)")
                }
            }
        }
        XCTAssertEqual(comparedRows, 660)
        print("Golden matrix: \(cases.count) cases, \(comparedRows) rows; \(comparisonFailures) field failures; \(zeroRowAbsoluteComparisons) zero-row drop/windage comparisons used the 5e-8 m absolute limit; worst relative difference \(worstDifference) at \(worstLabel); worst absolute difference \(worstAbsoluteDifference) \(worstAbsoluteUnit) at \(worstAbsoluteLabel)")
    }

    private func loadObject(named name: String) throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func number<T: BinaryFloatingPoint>(_ values: [String: Any], _ key: String, as: T.Type = Float.self) throws -> T {
        let value = try XCTUnwrap(values[key] as? NSNumber, "Missing number \(key)")
        return T(value.doubleValue)
    }

    private func dragModel(_ values: [String: Any]) throws -> DragModel {
        let label = try XCTUnwrap(values["dragModel"] as? String)
        return try XCTUnwrap(DragModel(rawValue: label))
    }
}
