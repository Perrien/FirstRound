import XCTest
@testable import First_Round

final class SolverBehaviorTests: XCTestCase {
    func testCalmZeroRetainsSpinDriftAndLiveCrosswindMovesImpactRight() throws {
        let calm = try solve(wind: .calm)
        let breezy = try solve(wind: ConstantWind(xMps: 4.4704, yMps: 0, zMps: 0))
        XCTAssertGreaterThan(calm.rows.last?.windageM ?? 0, 0, "Right-hand spin drift should be rightward")
        XCTAssertGreaterThan(breezy.rows.first?.windageM ?? 0, 0, "A +x crosswind should move impact right at the zero range")
        XCTAssertGreaterThan(breezy.rows.first?.windageM ?? 0, calm.rows.first?.windageM ?? 0)
    }

    func testHigherAirDensityReducesRetainedVelocity() throws {
        let load = referenceLoad()
        let coldDense = try solve(load: load, atmosphere: AtmosphereInput(temperatureK: 263.15, altitudeM: 0, humidity: 0.8, pressurePa: 0), wind: .calm)
        let hotHigh = try solve(load: load, atmosphere: AtmosphereInput(temperatureK: 308.15, altitudeM: 1500, humidity: 0.2, pressurePa: 0), wind: .calm)
        XCTAssertLessThan(coldDense.rows[5].velocityMps, hotHigh.rows[5].velocityMps)
    }

    func testUnconvergedZeroReportsClosestDeviation() throws {
        var request = sampleRequest()
        request.maxZeroIterations = 1
        let result = try TrajectorySolver(request: request).solve()
        XCTAssertFalse(result.zero.converged)
        XCTAssertGreaterThan(result.zero.missDistanceM, request.zeroToleranceM)
        XCTAssertEqual(result.zero.missDistanceM,
                       hypot(result.zero.lateralDeviationM, result.zero.verticalDeviationM), accuracy: 1e-6)
        XCTAssertFalse(result.rows.isEmpty, "Closest trajectory should still be available")
    }

    func testInvalidInputsAreRejected() throws {
        var request = sampleRequest()
        request.load.massKg = 0
        XCTAssertThrowsError(try TrajectorySolver(request: request))
    }

    func testSpecificRangeIsSampledFromFreshTrajectoryBetweenIntervalRows() throws {
        var request = sampleRequest()
        request.ranges.maxRangeM = 700
        request.ranges.requestedRangesM = [625]
        let rows = try TrajectorySolver(request: request).solve().rows

        let row600 = try XCTUnwrap(rows.first { abs($0.rangeM - 600) < 1e-5 })
        let row625 = try XCTUnwrap(rows.first { abs($0.rangeM - 625) < 1e-5 })
        let row700 = try XCTUnwrap(rows.first { abs($0.rangeM - 700) < 1e-5 })
        XCTAssertNotEqual(row625.dropM, row600.dropM)
        XCTAssertNotEqual(row625.dropM, row700.dropM)
        XCTAssertEqual(rows.filter { abs($0.rangeM - 625) < 1e-5 }.count, 1)
    }

    func testChangingBulletWeightChangesCalculatedEnergy() throws {
        let original = try solve(wind: .calm)
        var heavierLoad = referenceLoad()
        heavierLoad.massKg *= 700.0 / 661.0
        let heavier = try solve(load: heavierLoad, wind: .calm)
        XCTAssertNotEqual(original.rows[5].kineticEnergyJ, heavier.rows[5].kineticEnergyJ)
    }

    func testDisplayConversionsRemainIndependent() {
        XCTAssertEqual(DistanceUnitSystem.imperial.range(fromMeters: 600), 656.167979, accuracy: 1e-5)
        XCTAssertEqual(DistanceUnitSystem.imperial.displacement(fromMeters: 1), 39.3700787, accuracy: 1e-6)
        XCTAssertEqual(AngleUnit.mil.value(fromRadians: 0.1), 100, accuracy: 1e-10)
        XCTAssertEqual(AngleUnit.moa.value(fromRadians: 0.1), 343.774677, accuracy: 1e-5)
        XCTAssertEqual(DistanceUnitSystem.imperial.temperatureKelvin(fromDisplay: 59), 288.15, accuracy: 1e-10)
        XCTAssertEqual(DistanceUnitSystem.metric.temperatureKelvin(fromDisplay: 15), 288.15, accuracy: 1e-10)
        XCTAssertEqual(SolverDisplay.correctionText(displacementM: 0, rangeM: 100, axis: .elevation, unit: .mil), "0.00 MIL")
        XCTAssertEqual(SolverDisplay.correctionText(displacementM: -1, rangeM: 100, axis: .elevation, unit: .mil), "Up 10.00 MIL")
        XCTAssertEqual(SolverDisplay.correctionText(displacementM: 1, rangeM: 100, axis: .windage, unit: .mil), "Left 10.00 MIL")
    }

    func testTrajectoryDistanceInterpolation() throws {
        let load = referenceLoad()
        let a = BulletState(load: load, position: Vector3D(0, 0, 0), velocity: Vector3D(0, 0, -100), spinRate: 10)
        let b = BulletState(load: load, position: Vector3D(2, 4, -10), velocity: Vector3D(4, 8, -80), spinRate: 20)
        var trajectory = Trajectory()
        trajectory.append(TrajectoryPoint(timeS: 0, state: a, wind: Vector3D()))
        trajectory.append(TrajectoryPoint(timeS: 1, state: b, wind: Vector3D()))
        let midpoint = try XCTUnwrap(trajectory.atDistance(5))
        XCTAssertEqual(midpoint.state.position, Vector3D(1, 2, -5))
        XCTAssertEqual(midpoint.state.velocity, Vector3D(2, 4, -90))
        XCTAssertEqual(midpoint.timeS, 0.5, accuracy: 1e-6)
    }

    private func solve(load: BallisticLoad? = nil, atmosphere: AtmosphereInput? = nil, wind: ConstantWind) throws -> TrajectorySolution {
        var request = sampleRequest()
        if let load { request.load = load }
        if let atmosphere { request.atmosphere = atmosphere }
        request.wind = wind
        return try TrajectorySolver(request: request).solve()
    }

    private func sampleRequest() -> BallisticRequest {
        BallisticRequest(load: referenceLoad(),
                         atmosphere: AtmosphereInput(temperatureK: 288.15, altitudeM: 0, humidity: 0.5, pressurePa: 0),
                         wind: .calm,
                         ranges: RangeRequest(zeroRangeM: 100, maxRangeM: 600, stepM: 100),
                         zeroMode: .calmAir)
    }

    private func referenceLoad() -> BallisticLoad {
        BallisticLoad(massKg: 0.0090718474, diameterM: 0.0067056, lengthM: 0.0353568,
                      bc: 0.326, dragModel: .g7, muzzleVelocityMps: 826.008, twistM: 0.2032)
    }
}
