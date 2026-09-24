import Foundation

/// Float-based 3D vector; cross-product order matches the C++ reference.
struct Vector3D: Equatable {
    var x: Float
    var y: Float
    var z: Float

    init(_ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z }

    static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z) }
    static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z) }
    static func * (lhs: Self, rhs: Float) -> Self { Self(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs) }
    static func * (lhs: Float, rhs: Self) -> Self { rhs * lhs }
    static func / (lhs: Self, rhs: Float) -> Self { Self(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs) }

    var magnitude: Float { sqrt(x * x + y * y + z * z) }

    var normalized: Self {
        let length = magnitude
        return length > 0 ? self / length : Self()
    }

    func dot(_ other: Self) -> Float { x * other.x + y * other.y + z * other.z }

    func cross(_ other: Self) -> Self {
        Self(y * other.z - z * other.y,
             z * other.x - x * other.z,
             x * other.y - y * other.x)
    }

    func lerp(to other: Self, t: Float) -> Self {
        Self(x + t * (other.x - x),
             y + t * (other.y - y),
             z + t * (other.z - z))
    }
}
