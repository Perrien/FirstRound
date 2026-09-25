import XCTest
@testable import First_Round

final class SteelPlateTests: XCTestCase {
    private let bulletMass: Float = 140 * 0.00006479891
    private let bulletDiameter: Float = 0.264 * 0.0254
    private let impactVelocity = Vector3D(0, 0, -700)

    func testMissHasNoImpulseAndBulletRadiusGrazeHits() throws {
        let diameter: Float = 0.1524
        let radius = diameter * 0.5
        let bulletRadius = bulletDiameter * 0.5
        let missPlate = try SteelPlate(diameterM: diameter)
        let missX = radius + bulletRadius + 0.0001
        let miss = missPlate.intersectSegment(from: Vector3D(missX, 2, -99),
                                              to: Vector3D(missX, 2, -101), bulletRadiusM: bulletRadius)
        XCTAssertNil(miss)
        XCTAssertEqual(missPlate.velocityMps, Vector3D())
        XCTAssertEqual(missPlate.angularVelocityRadPerSecond, Vector3D())

        var grazePlate = try SteelPlate(diameterM: diameter)
        let grazeX = radius + bulletRadius - 0.0001
        let graze = try XCTUnwrap(grazePlate.intersectSegment(from: Vector3D(grazeX, 2, -99),
                                                              to: Vector3D(grazeX, 2, -101), bulletRadiusM: bulletRadius))
        grazePlate.strike(at: graze.pointM, incomingVelocityMps: impactVelocity, bulletMassKg: bulletMass)
        XCTAssertLessThan(grazePlate.velocityMps.z, 0)
        XCTAssertGreaterThan(grazePlate.velocityMps.magnitude, 0)
        XCTAssertGreaterThan(grazePlate.angularVelocityRadPerSecond.magnitude, 0)
        XCTAssertTrue(grazePlate.isMoving)
    }

    func testCenteredHitSwingsDownrangeAndEdgeHitsTwistOppositeWays() throws {
        let diameter: Float = 0.1524
        var center = try SteelPlate(diameterM: diameter)
        center.strike(at: Vector3D(0, 2, -100), incomingVelocityMps: impactVelocity, bulletMassKg: bulletMass)
        center.step(0.2)
        XCTAssertLessThan(center.centerOfMassM.z, center.restPositionM.z)
        XCTAssertGreaterThan(center.pose.swingRadians, 0.01)

        var right = try SteelPlate(diameterM: diameter)
        right.strike(at: Vector3D(diameter * 0.45, 2, -100), incomingVelocityMps: impactVelocity, bulletMassKg: bulletMass)
        var left = try SteelPlate(diameterM: diameter)
        left.strike(at: Vector3D(-diameter * 0.45, 2, -100), incomingVelocityMps: impactVelocity, bulletMassKg: bulletMass)
        XCTAssertGreaterThan(right.angularVelocityRadPerSecond.y, 0)
        XCTAssertLessThan(left.angularVelocityRadPerSecond.y, 0)
    }

    func testSixInchTwoInchAndTwelveInchPlatesSettleFacingForward() throws {
        for diameter: Float in [0.0508, 0.1524, 0.3048] {
            var plate = try SteelPlate(diameterM: diameter)
            plate.strike(at: Vector3D(diameter * 0.45, 2, -100), incomingVelocityMps: impactVelocity,
                         bulletMassKg: bulletMass)
            var elapsed: Float = 0
            for _ in 0..<40 * 60 {
                if !plate.isMoving { break }
                plate.step(1 / 60)
                elapsed += 1 / 60
            }
            XCTAssertLessThan(elapsed, 40, "plate (diameter)m did not settle")
            XCTAssertFalse(plate.isMoving)
            XCTAssertGreaterThan(-plate.normal.z, 0.85, "plate (diameter)m did not face forward")
            XCTAssertLessThan(abs(plate.pose.twistRadians), SteelPlate.settleTwistRadians)
        }
    }

    func testCenteredPlateSettlesAfterReferenceSampleTimes() throws {
        var plate = try SteelPlate(diameterM: 0.1524)
        plate.strike(at: Vector3D(0, 2, -100), incomingVelocityMps: impactVelocity, bulletMassKg: bulletMass)
        for interval: Float in [0.02, 0.18, 0.8] { plate.step(interval) }
        for _ in 0..<40 * 60 {
            if !plate.isMoving { break }
            plate.step(1 / 60)
        }
        XCTAssertFalse(plate.isMoving)
        XCTAssertGreaterThan(-plate.normal.z, 0.85)
    }

    func testMassUsesSteelDensityAndLegacyMinimum() throws {
        let sixInch = try SteelPlate(diameterM: 0.1524)
        let twelveInch = try SteelPlate(diameterM: 0.3048)
        XCTAssertEqual(sixInch.massKg, 2, accuracy: 1e-6)
        XCTAssertEqual(twelveInch.massKg,
                       Float.pi * 0.1524 * 0.1524 * 0.0127 * SteelPlate.steelDensityKgPerM3,
                       accuracy: 1e-5)
        XCTAssertGreaterThan(twelveInch.inertiaKgM2.x, sixInch.inertiaKgM2.x)
    }
}
