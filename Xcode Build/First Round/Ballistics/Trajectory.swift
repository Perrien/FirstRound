import Foundation

struct TrajectoryPoint {
    var timeS: Float
    var state: BulletState
    var wind: Vector3D

    var distanceM: Float { -state.position.z }
    var speedMps: Float { state.speedMps }
}

struct Trajectory {
    private(set) var points: [TrajectoryPoint] = []

    mutating func append(_ point: TrajectoryPoint) { points.append(point) }
    mutating func clear() { points.removeAll(keepingCapacity: true) }

    func atDistance(_ distanceM: Float) -> TrajectoryPoint? {
        guard let first = points.first, let last = points.last,
              distanceM >= first.distanceM, distanceM <= last.distanceM else { return nil }

        var left = 0
        var right = points.count - 1
        while left < right - 1 {
            let middle = left + (right - left) / 2
            if distanceM < points[middle].distanceM { right = middle } else { left = middle }
        }

        let a = points[left]
        let b = points[right]
        let d1 = a.distanceM
        let d2 = b.distanceM
        if abs(d2 - d1) < 1e-9 { return a }
        let t = (distanceM - d1) / (d2 - d1)
        let position = a.state.position.lerp(to: b.state.position, t: t)
        let velocity = a.state.velocity.lerp(to: b.state.velocity, t: t)
        let spin = a.state.spinRate + t * (b.state.spinRate - a.state.spinRate)
        let interpolatedState = BulletState(load: a.state.load, position: position, velocity: velocity, spinRate: spin)
        return TrajectoryPoint(timeS: a.timeS + t * (b.timeS - a.timeS), state: interpolatedState,
                               wind: a.wind.lerp(to: b.wind, t: t))
    }
}

struct TrajectoryRow {
    var rangeM: Float
    var dropM: Float
    var windageM: Float
    var velocityMps: Float
    var timeOfFlightS: Float
    var kineticEnergyJ: Float
}

struct ZeroResult {
    var converged: Bool
    var verticalDeviationM: Float
    var lateralDeviationM: Float
    var missDistanceM: Float
}

struct TrajectorySolution {
    var rows: [TrajectoryRow]
    var zero: ZeroResult
}
