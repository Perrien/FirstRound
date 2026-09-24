import Foundation

/// Float-based 2D vector used by the native ballistics model.
struct Vector2D: Equatable {
    var x: Float
    var y: Float

    init(_ x: Float = 0, _ y: Float = 0) {
        self.x = x
        self.y = y
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.x == rhs.x && lhs.y == rhs.y }

    static func + (lhs: Self, rhs: Self) -> Self { Self(lhs.x + rhs.x, lhs.y + rhs.y) }
    static func - (lhs: Self, rhs: Self) -> Self { Self(lhs.x - rhs.x, lhs.y - rhs.y) }
    static func * (lhs: Self, rhs: Float) -> Self { Self(lhs.x * rhs, lhs.y * rhs) }
    static func * (lhs: Float, rhs: Self) -> Self { rhs * lhs }
    static func / (lhs: Self, rhs: Float) -> Self { Self(lhs.x / rhs, lhs.y / rhs) }

    var magnitude: Float { sqrt(x * x + y * y) }

    var normalized: Self {
        let length = magnitude
        return length > 0 ? self / length : Self()
    }

    func dot(_ other: Self) -> Float { x * other.x + y * other.y }

    func lerp(to other: Self, t: Float) -> Self {
        Self(x + t * (other.x - x), y + t * (other.y - y))
    }
}
