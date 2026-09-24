import Foundation
import XCTest
@testable import First_Round

final class MathTests: XCTestCase {
    func testVector2DMagnitudeAndZeroNormalization() {
        let vector = Vector2D(3, 4)
        XCTAssertEqual(vector.magnitude, 5, accuracy: 1e-6)
        XCTAssertEqual(vector.normalized.x, 0.6, accuracy: 1e-6)
        XCTAssertEqual(vector.normalized.y, 0.8, accuracy: 1e-6)
        XCTAssertEqual(Vector2D().normalized, Vector2D())
        XCTAssertEqual(vector.dot(Vector2D(1, 2)), 11)
    }

    func testVector3DCrossProductAndInterpolation() {
        let x = Vector3D(1, 0, 0)
        let y = Vector3D(0, 1, 0)
        XCTAssertEqual(x.cross(y), Vector3D(0, 0, 1))
        XCTAssertEqual(y.cross(x), Vector3D(0, 0, -1))
        XCTAssertEqual(Vector3D().normalized, Vector3D())
        XCTAssertEqual(Vector3D(2, 4, 6).lerp(to: Vector3D(6, 8, 10), t: 0.25),
                       Vector3D(3, 5, 7))
        XCTAssertEqual((x + y) * 2, Vector3D(2, 2, 0))
    }

    func testQuaternionIdentityAndRightHandedRotation() {
        let forward = Vector3D(0, 0, -1)
        XCTAssertEqual(Quaternion.identity.rotate(forward), forward)

        let quarterTurn = Quaternion.fromAxisAngle(axis: Vector3D(0, 1, 0),
                                                   angle: Float.pi / 2)
        let rotated = quarterTurn.rotate(forward)
        XCTAssertEqual(rotated.x, -1, accuracy: 1e-6)
        XCTAssertEqual(rotated.y, 0, accuracy: 1e-6)
        XCTAssertEqual(rotated.z, 0, accuracy: 1e-6)

        let product = quarterTurn * quarterTurn.conjugate
        XCTAssertEqual(product.w, 1, accuracy: 1e-6)
        XCTAssertEqual(product.x, 0, accuracy: 1e-6)
        XCTAssertEqual(product.y, 0, accuracy: 1e-6)
        XCTAssertEqual(product.z, 0, accuracy: 1e-6)
    }

    func testQuaternionSlerpHalfway() {
        let quarterTurn = Quaternion.fromAxisAngle(axis: Vector3D(0, 1, 0),
                                                   angle: Float.pi / 2)
        let halfway = Quaternion.identity.slerp(to: quarterTurn, t: 0.5)
        let rotated = halfway.rotate(Vector3D(0, 0, -1))
        let halfRootTwo: Float = 0.70710678118
        XCTAssertEqual(rotated.x, -halfRootTwo, accuracy: 1e-6)
        XCTAssertEqual(rotated.z, -halfRootTwo, accuracy: 1e-6)
        XCTAssertEqual(halfway.magnitude, 1, accuracy: 1e-6)
    }
}
