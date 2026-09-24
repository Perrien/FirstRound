import XCTest
@testable import First_Round

final class WindReferenceTests: XCTestCase {
    func testGeneratedFieldMatchesCapturedSamples() throws {
        let fixture = try generatedFixture()
        let first = try sampleField(fixture)
        _ = try sampleField(fixture, seed: fixture.seed &+ 1)
        let again = try sampleField(fixture)

        for (a, b) in zip(first, again) {
            XCTAssertEqual(a.x, b.x, accuracy: 1e-7)
            XCTAssertEqual(a.y, b.y, accuracy: 1e-7)
            XCTAssertEqual(a.z, b.z, accuracy: 1e-7)
        }

        for (actual, expected) in zip(first, fixture.samples) {
            XCTAssertEqual(actual.x, Float(expected.gustMps.x), accuracy: 1e-4,
                           "seeded Moderate field x at \(expected.position)")
            XCTAssertEqual(actual.y, Float(expected.gustMps.y), accuracy: 1e-4)
            XCTAssertEqual(actual.z, Float(expected.gustMps.z), accuracy: 1e-4,
                           "seeded Moderate field z at \(expected.position)")
        }
    }

    func testGeneratedFieldShotMatchesCapturedRows() throws {
        let fixture = try generatedFixture()
        let config = fixture.trajectory
        let actual = try fieldSolution(fixture, clock: fixture.fieldClockS,
                                       mean: config.meanWindMps).rows
        XCTAssertEqual(actual.count, config.rows.count)
        for (a, e) in zip(actual, config.rows) {
            XCTAssertEqual(a.rangeM, Float(e.rangeM), accuracy: 1e-4)
            XCTAssertEqual(a.dropM, Float(e.dropM), accuracy: 5e-4, "drop at \(e.rangeM) m")
            XCTAssertEqual(a.windageM, Float(e.windageM), accuracy: 5e-4, "windage at \(e.rangeM) m")
            XCTAssertEqual(a.velocityMps, Float(e.velocityMps), accuracy: 2e-3, "velocity at \(e.rangeM) m")
            XCTAssertEqual(a.timeOfFlightS, Float(e.timeOfFlightS), accuracy: 2e-5, "time at \(e.rangeM) m")
        }
    }

    func testFieldClockAndMeanWindChangeOutputAndSeedIsOrderIndependent() throws {
        let fixture = try generatedFixture()
        let referenceMean = fixture.trajectory.meanWindMps
        let baseline = try fieldSolution(fixture, clock: fixture.fieldClockS, mean: referenceMean)
        _ = try fieldSolution(fixture, clock: fixture.fieldClockS + 1,
                              mean: RefVector(x: 0, y: 0, z: 0))
        let repeated = try fieldSolution(fixture, clock: fixture.fieldClockS, mean: referenceMean)
        XCTAssertEqual(baseline.rows.count, repeated.rows.count)
        for (a, b) in zip(baseline.rows, repeated.rows) {
            XCTAssertEqual(a.dropM, b.dropM, accuracy: 1e-7)
            XCTAssertEqual(a.windageM, b.windageM, accuracy: 1e-7)
            XCTAssertEqual(a.velocityMps, b.velocityMps, accuracy: 1e-7)
        }
        let shiftedClock = try fieldSolution(fixture, clock: fixture.fieldClockS + 1, mean: referenceMean)
        XCTAssertNotEqual(baseline.rows[1].windageM, shiftedClock.rows[1].windageM)
        let noMean = try fieldSolution(fixture, clock: fixture.fieldClockS,
                                       mean: RefVector(x: 0, y: 0, z: 0))
        XCTAssertNotEqual(baseline.rows[1].windageM, noMean.rows[1].windageM)
    }

    func testCurrentWebShotReferenceUsesCalmZeroThenLiveWind() throws {
        let fixture = try webShotFixture()
        let request = makeRequest(load: fixture.load, atmosphere: fixture.atmosphere,
                                  wind: fixture.liveWindMps, zeroRangeM: fixture.zeroRangeM,
                                  requestedRanges: fixture.sampleRangesM)
        let actual = try TrajectorySolver(request: request).solve().rows
        XCTAssertEqual(actual.count, fixture.rows.count)
        for (a, e) in zip(actual, fixture.rows) {
            XCTAssertEqual(a.rangeM, Float(e.rangeM), accuracy: 1e-4)
            XCTAssertEqual(a.dropM, Float(e.dropM), accuracy: 5e-5)
            XCTAssertEqual(a.windageM, Float(e.windageM), accuracy: 5e-5)
            XCTAssertEqual(a.velocityMps, Float(e.velocityMps), accuracy: 5e-4)
            XCTAssertEqual(a.timeOfFlightS, Float(e.timeOfFlightS), accuracy: 2e-5)
        }
        XCTAssertGreaterThan(actual[0].windageM, 0, "Live crosswind should move impact at the calm-air zero range.")
    }

    private func sampleField(_ fixture: GeneratedFixture, seed: UInt32? = nil) throws -> [Vector3D] {
        let field = makeField(fixture, seed: seed)
        field.advance(to: Float(fixture.fieldClockS))
        return fixture.samples.map { sample in
            field.sample(Vector3D(Float(sample.position.x), Float(sample.position.y), Float(sample.position.z)))
        }
    }

    private func fieldSolution(_ fixture: GeneratedFixture, clock: Double,
                               mean: RefVector) throws -> TrajectorySolution {
        let config = fixture.trajectory
        let field = makeField(fixture)
        field.advance(to: Float(clock))
        let request = makeRequest(load: config.load, atmosphere: config.atmosphere,
                                  wind: mean, zeroRangeM: config.zeroRangeM,
                                  requestedRanges: config.rows.map { $0.rangeM })
        return try TrajectorySolver(request: request,
                                    windSampler: { position, _ in field.sample(position) }).solve()
    }

    private func makeField(_ fixture: GeneratedFixture, seed: UInt32? = nil) -> WindField {
        let bounds = WindField.Bounds(
            minimum: Vector3D(Float(fixture.fieldBoundsM.min.x), Float(fixture.fieldBoundsM.min.y), Float(fixture.fieldBoundsM.min.z)),
            maximum: Vector3D(Float(fixture.fieldBoundsM.max.x), Float(fixture.fieldBoundsM.max.y), Float(fixture.fieldBoundsM.max.z)))
        return WindField(seed: seed ?? fixture.seed, bounds: bounds)
    }

    private func makeRequest(load: RefLoad, atmosphere: RefAtmosphere, wind: RefVector,
                             zeroRangeM: Double, requestedRanges: [Double]) -> BallisticRequest {
        BallisticRequest(
            load: BallisticLoad(massKg: Float(load.massKg), diameterM: Float(load.diameterM),
                                lengthM: Float(load.lengthM), bc: Float(load.bc),
                                dragModel: load.dragModel, muzzleVelocityMps: Float(load.muzzleVelocityMps),
                                twistM: Float(load.twistM)),
            atmosphere: AtmosphereInput(temperatureK: Float(atmosphere.temperatureK),
                                        altitudeM: Float(atmosphere.altitudeM), humidity: Float(atmosphere.humidity),
                                        pressurePa: Float(atmosphere.pressurePa)),
            wind: ConstantWind(xMps: Float(wind.x), yMps: Float(wind.y), zMps: Float(wind.z)),
            ranges: RangeRequest(zeroRangeM: Float(zeroRangeM), maxRangeM: 600, stepM: 600,
                                 requestedRangesM: requestedRanges.map(Float.init)),
            zeroMode: .calmAir)
    }

    private func generatedFixture() throws -> GeneratedFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "generated-wind", withExtension: "json"))
        return try JSONDecoder().decode(GeneratedFixture.self, from: Data(contentsOf: url))
    }

    private func webShotFixture() throws -> WebShotFixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "web-shot", withExtension: "json"))
        return try JSONDecoder().decode(WebShotFixture.self, from: Data(contentsOf: url))
    }
}

private struct RefVector: Codable {
    var x: Double
    var y: Double
    var z: Double
}

private struct RefLoad: Codable {
    var massKg: Double
    var diameterM: Double
    var lengthM: Double
    var bc: Double
    var dragModel: DragModel
    var muzzleVelocityMps: Double
    var twistM: Double
}

private struct RefAtmosphere: Codable {
    var temperatureK: Double
    var altitudeM: Double
    var humidity: Double
    var pressurePa: Double
}

private struct RefRangeRow: Codable {
    var rangeM: Double
    var dropM: Double
    var windageM: Double
    var velocityMps: Double
    var timeOfFlightS: Double
}

private struct GeneratedFixture: Decodable {
    struct Bounds: Decodable { var min: RefVector; var max: RefVector }
    struct Sample: Decodable { var position: RefVector; var timeS: Double; var gustMps: RefVector }
    struct Trajectory: Decodable {
        var load: RefLoad
        var atmosphere: RefAtmosphere
        var zeroRangeM: Double
        var meanWindMps: RefVector
        var rows: [RefRangeRow]
    }
    var sourceRevision: String
    var seed: UInt32
    var fieldClockS: Double
    var fieldBoundsM: Bounds
    var meanWindMps: RefVector
    var samples: [Sample]
    var trajectory: Trajectory
}

private struct WebShotFixture: Decodable {
    var load: RefLoad
    var atmosphere: RefAtmosphere
    var zeroRangeM: Double
    var liveWindMps: RefVector
    var sampleRangesM: [Double]
    var rows: [RefRangeRow]
}
