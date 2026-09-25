import XCTest
@testable import First_Round

final class ShotGroupReferenceTests: XCTestCase {
    func testCapturedShotGroupsMatchLegacyEngine() throws {
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL()))
        XCTAssertEqual(fixture.sourceRevision, "a96c8f67ed2f395d111b1da5613f151823f7742c")
        var worstImpact = (error: Float.zero, caseID: "", shot: 0, field: "")
        var worstMV = (error: Float.zero, caseID: "", shot: 0)
        var worstBC = (error: Float.zero, caseID: "", shot: 0)
        for expected in fixture.cases {
            let load = BallisticLoad(massKg: fixture.load.massKg, diameterM: fixture.load.diameterM,
                lengthM: fixture.load.lengthM, bc: fixture.load.bc, dragModel: .g7,
                muzzleVelocityMps: fixture.load.muzzleVelocityMps, twistM: fixture.load.twistM)
            let request = BallisticRequest(load: load,
                atmosphere: AtmosphereInput(temperatureK: fixture.atmosphere.temperatureK,
                    altitudeM: fixture.atmosphere.altitudeM, humidity: fixture.atmosphere.humidity,
                    pressurePa: fixture.atmosphere.pressurePa), wind: .calm,
                ranges: RangeRequest(zeroRangeM: Float(fixture.rangeM), maxRangeM: Float(fixture.rangeM),
                                     stepM: Float(fixture.rangeM)), zeroMode: .calmAir)
            let parameters = DispersionParameters(muzzleVelocitySDMps: expected.mvSdMps,
                ballisticCoefficientSDFraction: expected.bcSdFraction,
                rifleConeDiameterRadians: expected.rifleConeDiameterRad,
                cantLimitRadians: expected.scopeCantLimitRad,
                crosswindSDMps: expected.crosswindSdMps, headwindSDMps: expected.headwindSdMps,
                updraftSDMps: expected.updraftSdMps)
            let actual = try ShotGroupSimulator(request: request, parameters: parameters,
                targetRangeM: Float(fixture.rangeM), shotCount: expected.count, seed: expected.seed).run()
            XCTAssertEqual(actual.shots.count, expected.shots.count)
            for (a, e) in zip(actual.shots, expected.shots) {
                if abs(a.offsetM.x - e.xM) > worstImpact.error { worstImpact = (abs(a.offsetM.x - e.xM), expected.id, e.index, "x") }
                if abs(a.offsetM.y - e.yM) > worstImpact.error { worstImpact = (abs(a.offsetM.y - e.yM), expected.id, e.index, "y") }
                if abs(a.muzzleVelocityMps - e.mvMps) > worstMV.error { worstMV = (abs(a.muzzleVelocityMps - e.mvMps), expected.id, e.index) }
                if abs(a.ballisticCoefficient - e.bc) > worstBC.error { worstBC = (abs(a.ballisticCoefficient - e.bc), expected.id, e.index) }
                XCTAssertEqual(a.offsetM.x, e.xM, accuracy: 0.0001, "\(expected.id) shot \(e.index) x")
                XCTAssertEqual(a.offsetM.y, e.yM, accuracy: 0.0001, "\(expected.id) shot \(e.index) y")
                XCTAssertEqual(a.muzzleVelocityMps, e.mvMps, accuracy: 0.001, "\(expected.id) shot \(e.index) MV")
                XCTAssertEqual(a.ballisticCoefficient, e.bc, accuracy: 0.000001, "\(expected.id) shot \(e.index) BC")
            }
        }
        XCTAssertLessThanOrEqual(worstImpact.error, 0.0001,
            "Worst coordinate delta: \(worstImpact.field) at \(worstImpact.caseID) shot \(worstImpact.shot)")
        XCTAssertLessThanOrEqual(worstMV.error, 0.001,
            "Worst MV delta at \(worstMV.caseID) shot \(worstMV.shot)")
        XCTAssertLessThanOrEqual(worstBC.error, 0.000001,
            "Worst BC delta at \(worstBC.caseID) shot \(worstBC.shot)")
    }

    private func fixtureURL() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "shot-group", withExtension: "json"))
    }

    private struct Fixture: Decodable {
        var sourceRevision: String
        var load: Load
        var atmosphere: Atmosphere
        var rangeM: Double
        var cases: [Case]
        struct Load: Decodable { var massKg: Float; var diameterM: Float; var lengthM: Float; var bc: Float; var muzzleVelocityMps: Float; var twistM: Float }
        struct Atmosphere: Decodable { var temperatureK: Float; var altitudeM: Float; var humidity: Float; var pressurePa: Float }
        struct Case: Decodable {
            var id: String; var count: Int; var seed: UInt32; var mvSdMps: Float; var bcSdFraction: Float
            var rifleConeDiameterRad: Float; var scopeCantLimitRad: Float; var crosswindSdMps: Float
            var headwindSdMps: Float; var updraftSdMps: Float; var shots: [Shot]
            struct Shot: Decodable { var index: Int; var xM: Float; var yM: Float; var mvMps: Float; var bc: Float }
        }
    }
}
