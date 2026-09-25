import XCTest
@testable import First_Round

final class DispersionTests: XCTestCase {
    func testSameSeedRepeatsAndDifferentSeedChangesGroup() throws {
        let first = try simulator(seed: 42, shots: 8).run()
        let repeated = try simulator(seed: 42, shots: 8).run()
        let different = try simulator(seed: 43, shots: 8).run()
        XCTAssertEqual(first.shots.map(\.offsetM), repeated.shots.map(\.offsetM))
        XCTAssertNotEqual(first.shots.map(\.offsetM), different.shots.map(\.offsetM))
    }

    func testZeroDispersionInputsProduceZeroScatter() throws {
        var sim = try simulator(seed: 1, shots: 3)
        sim = try ShotGroupSimulator(request: sim.request, parameters: DispersionParameters(
            muzzleVelocitySDMps: 0, ballisticCoefficientSDFraction: 0, rifleConeDiameterRadians: 0,
            cantLimitRadians: 0, crosswindSDMps: 0, headwindSDMps: 0, updraftSDMps: 0),
            targetRangeM: 100, shotCount: 3, seed: 1)
        let group = try sim.run()
        for shot in group.shots {
            XCTAssertEqual(shot.offsetM.x, group.shots[0].offsetM.x, accuracy: 1e-7)
            XCTAssertEqual(shot.offsetM.y, group.shots[0].offsetM.y, accuracy: 1e-7)
        }
    }

    func testHandCalculatedStatisticsAndEdgeGraze() {
        let points = [
            sample(1, 0, 0), sample(2, 2, 0), sample(3, 0, 2)
        ]
        let group = ShotGroupResult.summarize(shots: points, seed: 9, plateDiameterM: 2,
                                               bulletDiameterM: 0, bulletMassKg: 0.009)
        XCTAssertEqual(group.statistics.centerM.x, 2 / 3, accuracy: 1e-6)
        XCTAssertEqual(group.statistics.centerM.y, 2 / 3, accuracy: 1e-6)
        XCTAssertEqual(group.statistics.meanRadiusAboutGroupCenterM,
                       (sqrt(8.0 / 9.0) + sqrt(20.0 / 9.0) + sqrt(20.0 / 9.0)) / 3, accuracy: 1e-6)
        XCTAssertEqual(group.statistics.extremeSpreadM, sqrt(8), accuracy: 1e-6)
        XCTAssertEqual(group.statistics.rmsRadiusFromAimM, sqrt(8.0 / 3.0), accuracy: 1e-6)

        let graze = ShotGroupResult.summarize(shots: [sample(1, 1.01, 0)], seed: 1,
                                               plateDiameterM: 2, bulletDiameterM: 0.02, bulletMassKg: 0.009)
        XCTAssertEqual(graze.statistics.hitCount, 1)
    }

    func testLargerRifleConeOpensGroup() throws {
        let narrow = try simulator(seed: 712, shots: 20, coneMOA: 0.2).run()
        let wide = try simulator(seed: 712, shots: 20, coneMOA: 2).run()
        XCTAssertGreaterThan(wide.statistics.extremeSpreadM, narrow.statistics.extremeSpreadM)
    }

    private func simulator(seed: UInt32, shots: Int, coneMOA: Float = 0.5) throws -> ShotGroupSimulator {
        let load = BallisticLoad(massKg: 0.0090718474, diameterM: 0.0067056, lengthM: 0.0353568,
                                 bc: 0.326, dragModel: .g7, muzzleVelocityMps: 826.008, twistM: 0.2032)
        let request = BallisticRequest(load: load,
            atmosphere: AtmosphereInput(temperatureK: 288.15, altitudeM: 0, humidity: 0.5, pressurePa: 0),
            wind: .calm, ranges: RangeRequest(zeroRangeM: 100, maxRangeM: 300, stepM: 100), zeroMode: .calmAir)
        let params = DispersionParameters(muzzleVelocitySDMps: 2.7, ballisticCoefficientSDFraction: 0.005,
            rifleConeDiameterRadians: coneMOA * Float.pi / (180 * 60), cantLimitRadians: 0,
            crosswindSDMps: 0, headwindSDMps: 0, updraftSDMps: 0)
        return try ShotGroupSimulator(request: request, parameters: params, targetRangeM: 100,
                                      shotCount: shots, seed: seed)
    }

    private func sample(_ id: Int, _ x: Float, _ y: Float) -> ShotSample {
        ShotSample(id: id, offsetM: Vector2D(x, y), muzzleVelocityMps: 800, ballisticCoefficient: 0.3,
                   rifleAngle: Vector2D(), cantRadians: 0, crosswindMps: 0, headwindMps: 0,
                   updraftMps: 0, impactVelocityMps: 700, incomingVelocityMps: Vector3D(0, 0, -700))
    }
}
