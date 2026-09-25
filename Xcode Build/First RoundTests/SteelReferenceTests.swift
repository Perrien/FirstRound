import XCTest
@testable import First_Round

final class SteelReferenceTests: XCTestCase {
    func testCapturedSteelReactionsMatchLegacyEngine() throws {
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: fixtureURL()))
        XCTAssertEqual(fixture.sourceRevision, "a96c8f67ed2f395d111b1da5613f151823f7742c")
        XCTAssertEqual(fixture.cases.count, 5)
        for expected in fixture.cases {
            var plate = try SteelPlate(diameterM: expected.diameterM, thicknessM: expected.thicknessM,
                centerOfMassM: expected.centerM.vector)
            XCTAssertEqual(plate.massKg, expected.initialMassKg, accuracy: 1e-5, expected.id)
            plate.strike(at: expected.impactPointM.vector,
                         incomingVelocityMps: expected.incomingVelocityMps.vector,
                         bulletMassKg: expected.bulletMassKg)

            var elapsed: Float = 0
            for frame in expected.sampledFrames {
                let next = Float(frame.elapsedS)
                if next > elapsed { plate.step(next - elapsed) }
                elapsed = next
                assertPose(plate.pose, matches: frame, caseID: "\(expected.id) at \(frame.elapsedS)s")
            }

            guard expected.settle.didSettle, let settleFrame = expected.settle.pose else {
                XCTFail("Legacy case \(expected.id) did not settle before its cap")
                continue
            }
            var settleElapsed: Float = 0
            for _ in 0..<Int(fixture.physics.settleCapS * 60) {
                if !plate.isMoving { break }
                plate.step(1 / 60)
                settleElapsed += 1 / 60
            }
            XCTAssertFalse(plate.isMoving, "\(expected.id) did not settle in Swift")
            assertPose(plate.pose, matches: settleFrame, caseID: expected.id + " settled")
        }
    }

    private func assertPose(_ actual: SteelPlate.Pose, matches expected: Fixture.Frame, caseID: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.centerOfMassM.x, expected.centerOfMassM.x, accuracy: 0.001, "\(caseID) center x", file: file, line: line)
        XCTAssertEqual(actual.centerOfMassM.y, expected.centerOfMassM.y, accuracy: 0.001, "\(caseID) center y", file: file, line: line)
        XCTAssertEqual(actual.centerOfMassM.z, expected.centerOfMassM.z, accuracy: 0.001, "\(caseID) center z", file: file, line: line)
        let expectedQ = expected.orientation
        let a = actual.orientation.normalized
        let dot = abs(a.w * expectedQ.w + a.x * expectedQ.x + a.y * expectedQ.y + a.z * expectedQ.z)
        let angleError = 2 * acos(min(1, max(0, dot)))
        XCTAssertLessThanOrEqual(angleError, 0.02, "\(caseID) orientation error \(angleError)rad", file: file, line: line)
        XCTAssertEqual(actual.angularVelocityRadPerSecond.x, expected.angularVelocityRadPerSecond.x, accuracy: 0.05, "\(caseID) angular velocity x", file: file, line: line)
        XCTAssertEqual(actual.angularVelocityRadPerSecond.y, expected.angularVelocityRadPerSecond.y, accuracy: 0.05, "\(caseID) angular velocity y", file: file, line: line)
        XCTAssertEqual(actual.angularVelocityRadPerSecond.z, expected.angularVelocityRadPerSecond.z, accuracy: 0.05, "\(caseID) angular velocity z", file: file, line: line)
        XCTAssertEqual(actual.isMoving, expected.isMoving, "\(caseID) moving state", file: file, line: line)
    }

    private func fixtureURL() throws -> URL {
        try XCTUnwrap(Bundle(for: Self.self).url(forResource: "steel-reaction", withExtension: "json"))
    }

    private struct Fixture: Decodable {
        var sourceRevision: String
        var physics: Physics
        var cases: [Case]
        struct Physics: Decodable { var settleCapS: Double }
        struct Vec: Decodable { var x: Float; var y: Float; var z: Float
            var vector: Vector3D { Vector3D(x, y, z) } }
        struct Orientation: Decodable { var w: Float; var x: Float; var y: Float; var z: Float }
        struct Frame: Decodable {
            var elapsedS: Double; var centerOfMassM: Fixture.Vec; var normal: Fixture.Vec; var orientation: Fixture.Orientation
            var angularVelocityRadPerSecond: Fixture.Vec; var isMoving: Bool
        }
        struct Settle: Decodable { var elapsedS: Double; var didSettle: Bool; var pose: Fixture.Frame? }
        struct Case: Decodable {
            var id: String; var diameterM: Float; var thicknessM: Float; var centerM: Fixture.Vec
            var impactPointM: Fixture.Vec; var incomingVelocityMps: Fixture.Vec; var bulletMassKg: Float
            var initialMassKg: Float; var sampledFrames: [Fixture.Frame]; var settle: Fixture.Settle
        }
    }
}
