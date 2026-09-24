import Foundation

/// Float-based rotation quaternion with the same handedness as the C++ reference.
struct Quaternion: Equatable {
    var w: Float
    var x: Float
    var y: Float
    var z: Float

    init(_ w: Float = 1, _ x: Float = 0, _ y: Float = 0, _ z: Float = 0) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.w == rhs.w && lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z }

    static var identity: Self { Self() }

    static func fromAxisAngle(axis: Vector3D, angle: Float) -> Self {
        let half = angle * 0.5
        let sine = sin(half)
        return Self(cos(half), axis.x * sine, axis.y * sine, axis.z * sine)
    }

    static func * (lhs: Self, rhs: Self) -> Self {
        Self(lhs.w * rhs.w - lhs.x * rhs.x - lhs.y * rhs.y - lhs.z * rhs.z,
             lhs.w * rhs.x + lhs.x * rhs.w + lhs.y * rhs.z - lhs.z * rhs.y,
             lhs.w * rhs.y - lhs.x * rhs.z + lhs.y * rhs.w + lhs.z * rhs.x,
             lhs.w * rhs.z + lhs.x * rhs.y - lhs.y * rhs.x + lhs.z * rhs.w)
    }

    var magnitude: Float { sqrt(w * w + x * x + y * y + z * z) }

    var normalized: Self {
        let length = magnitude
        guard length > 1e-8 else { return self }
        let inverse = 1 / length
        return Self(w * inverse, x * inverse, y * inverse, z * inverse)
    }

    var conjugate: Self { Self(w, -x, -y, -z) }

    func rotate(_ vector: Vector3D) -> Vector3D {
        let imaginary = Vector3D(x, y, z)
        let firstCross = imaginary.cross(vector)
        let secondCross = imaginary.cross(firstCross)
        return vector + firstCross * (2 * w) + secondCross * 2
    }

    func slerp(to other: Self, t: Float) -> Self {
        var target = other
        var dot = w * other.w + x * other.x + y * other.y + z * other.z

        if dot < 0 {
            target = Self(-other.w, -other.x, -other.y, -other.z)
            dot = -dot
        }
        if dot > 0.9995 {
            return Self(w + t * (target.w - w),
                        x + t * (target.x - x),
                        y + t * (target.y - y),
                        z + t * (target.z - z)).normalized
        }

        let theta0 = acos(dot)
        let theta = theta0 * t
        let sineTheta = sin(theta)
        let sineTheta0 = sin(theta0)
        let startWeight = cos(theta) - dot * sineTheta / sineTheta0
        let endWeight = sineTheta / sineTheta0
        return Self(startWeight * w + endWeight * target.w,
                    startWeight * x + endWeight * target.x,
                    startWeight * y + endWeight * target.y,
                    startWeight * z + endWeight * target.z)
    }
}
