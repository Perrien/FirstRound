import Foundation

/// Rendering-independent port of the legacy round, two-chain steel target.
/// Coordinates use +x right, +y up, and -z downrange, matching the solver.
struct SteelPlate {
    static let steelDensityKgPerM3: Float = 7_850
    static let minimumMassKg: Float = 2
    static let chainSpringNPerM: Float = 10_000
    static let chainDampingNsPerM: Float = 200
    static let linearDampingPerSecond: Float = 0.5
    static let angularDampingPerSecond: Float = 0.5
    static let twistDampingPerSecond: Float = 0.03
    static let twistStiffnessPerRad: Float = 60
    static let maximumAngularSpeedRadPerSecond: Float = 12
    static let maximumTwistRadians: Float = 1.658
    static let settleVelocityMps: Float = 0.2
    static let settleAngularVelocityRadPerSecond: Float = 0.2
    static let settleTwistRadians: Float = 0.05
    static let settleTimeS: Float = 1
    static let maximumInternalSubstepS: Float = 0.001
    static let chainAnchorAngleRadians: Float = 0.6
    static let chainOutwardOffsetM: Float = 0.05
    static let chainLengthM: Float = 0.5

    struct Hit: Equatable {
        var pointM: Vector3D
        var distanceM: Float
    }

    struct Pose: Equatable {
        var centerOfMassM: Vector3D
        var orientation: Quaternion
        var normal: Vector3D
        var velocityMps: Vector3D
        var angularVelocityRadPerSecond: Vector3D
        var isMoving: Bool

        var swingRadians: Float {
            acos(min(1, max(-1, -normal.z)))
        }

        var twistRadians: Float {
            var qw = orientation.w
            var qy = orientation.y
            if qw < 0 { qw = -qw; qy = -qy }
            return 2 * atan2(qy, qw)
        }
    }

    private struct ChainAnchor {
        var localAttachment: Vector3D
        var worldFixed: Vector3D
        var restLength: Float
    }

    let diameterM: Float
    let thicknessM: Float
    let restPositionM: Vector3D
    let beamHeightM: Float
    let massKg: Float
    let inertiaKgM2: Vector3D

    private(set) var centerOfMassM: Vector3D
    private(set) var orientation = Quaternion.identity
    private(set) var velocityMps = Vector3D()
    private(set) var angularVelocityRadPerSecond = Vector3D()
    private(set) var isMoving = true
    private var timeBelowSettleThresholdS: Float = 0
    private var anchors: [ChainAnchor] = []

    init(diameterM: Float, thicknessM: Float = 0.0127,
         centerOfMassM: Vector3D = Vector3D(0, 2, -100)) throws {
        guard diameterM.isFinite, diameterM > 0 else { throw SolverError.invalidInput("plate diameter") }
        guard thicknessM.isFinite, thicknessM > 0 else { throw SolverError.invalidInput("plate thickness") }
        guard [centerOfMassM.x, centerOfMassM.y, centerOfMassM.z].allSatisfy(\.isFinite) else {
            throw SolverError.invalidInput("plate position")
        }

        self.diameterM = diameterM
        self.thicknessM = thicknessM
        self.restPositionM = centerOfMassM
        self.centerOfMassM = centerOfMassM
        let radius = diameterM * 0.5
        let attachX = radius * sin(Self.chainAnchorAngleRadians)
        let attachY = radius * cos(Self.chainAnchorAngleRadians)
        self.beamHeightM = centerOfMassM.y + attachY + Self.chainLengthM

        let calculatedMass = Float.pi * radius * radius * thicknessM * Self.steelDensityKgPerM3
        let actualMass = max(calculatedMass, Self.minimumMassKg)
        self.massKg = actualMass
        let massRatio = calculatedMass > 0 ? actualMass / calculatedMass : 1
        self.inertiaKgM2 = Vector3D(
            0.25 * calculatedMass * radius * radius * massRatio,
            0.25 * calculatedMass * radius * radius * massRatio,
            0.5 * calculatedMass * radius * radius * massRatio
        )

        for side: Float in [-1, 1] {
            let local = Vector3D(side * attachX, attachY, -thicknessM * 0.5)
            let world = centerOfMassM + local
            let fixed = Vector3D(world.x - side * Self.chainOutwardOffsetM,
                                 self.beamHeightM, world.z)
            anchors.append(ChainAnchor(localAttachment: local, worldFixed: fixed,
                                       restLength: (fixed - world).magnitude))
        }
    }

    var normal: Vector3D { orientation.rotate(Vector3D(0, 0, -1)) }
    var pose: Pose {
        Pose(centerOfMassM: centerOfMassM, orientation: orientation, normal: normal,
             velocityMps: velocityMps, angularVelocityRadPerSecond: angularVelocityRadPerSecond,
             isMoving: isMoving)
    }

    /// Intersects a segment with the current circular plate plane. Bullet radius
    /// expands the plate radius, preserving the legacy line-break rule.
    func intersectSegment(from start: Vector3D, to end: Vector3D, bulletRadiusM: Float) -> Hit? {
        guard bulletRadiusM.isFinite, bulletRadiusM >= 0 else { return nil }
        let inverse = orientation.conjugate
        let startLocal = inverse.rotate(start - centerOfMassM)
        let endLocal = inverse.rotate(end - centerOfMassM)
        let direction = endLocal - startLocal
        guard abs(direction.z) >= 1e-6 else { return nil }
        let t = -startLocal.z / direction.z
        guard (0...1).contains(t) else { return nil }
        let pointLocal = startLocal + direction * t
        let expandedRadius = diameterM * 0.5 + bulletRadiusM
        guard pointLocal.x * pointLocal.x + pointLocal.y * pointLocal.y <= expandedRadius * expandedRadius else {
            return nil
        }
        let pointWorld = centerOfMassM + orientation.rotate(pointLocal)
        return Hit(pointM: pointWorld, distanceM: (end - start).magnitude * t)
    }

    /// Applies the legacy momentum transfer at a confirmed impact point.
    mutating func strike(at impactPointM: Vector3D, incomingVelocityMps: Vector3D,
                         bulletMassKg: Float) {
        let speed = incomingVelocityMps.magnitude
        guard speed >= 1e-6, bulletMassKg.isFinite, bulletMassKg > 0 else { return }
        let angleCosine = abs((incomingVelocityMps / speed).dot(normal))
        let transferRatio = max(0.1, angleCosine * angleCosine)
        let impulse = incomingVelocityMps * (bulletMassKg * transferRatio)
        isMoving = true
        timeBelowSettleThresholdS = 0
        applyImpulse(impulse, at: impactPointM)
    }

    /// Advances the body with the old target's 1 ms maximum internal step.
    mutating func step(_ elapsedS: Float) {
        guard elapsedS.isFinite, elapsedS > 0 else { return }
        let dt = min(elapsedS, 1)
        let substepCount = max(1, Int(ceil(dt / Self.maximumInternalSubstepS)))
        let substep = dt / Float(substepCount)

        for _ in 0..<substepCount {
            applyForce(Vector3D(0, -9.80665 * massKg, 0), at: centerOfMassM, dt: substep)

            let twistRate = angularVelocityRadPerSecond.y
            applyChainForces(dt: substep)
            angularVelocityRadPerSecond.y = twistRate
            angularVelocityRadPerSecond.y -= Self.twistStiffnessPerRad * pose.twistRadians * substep

            velocityMps = velocityMps * pow(Self.linearDampingPerSecond, substep)
            angularVelocityRadPerSecond = angularVelocityRadPerSecond * pow(Self.angularDampingPerSecond, substep)
            angularVelocityRadPerSecond.y *= pow(Self.twistDampingPerSecond, substep)

            let angularSpeed = angularVelocityRadPerSecond.magnitude
            if angularSpeed > Self.maximumAngularSpeedRadPerSecond {
                angularVelocityRadPerSecond = angularVelocityRadPerSecond * (Self.maximumAngularSpeedRadPerSecond / angularSpeed)
            }

            centerOfMassM = centerOfMassM + velocityMps * substep
            let speed = angularVelocityRadPerSecond.magnitude
            if speed > 1e-6 {
                let rotation = Quaternion.fromAxisAngle(axis: angularVelocityRadPerSecond / speed,
                                                       angle: speed * substep)
                orientation = (rotation * orientation).normalized
            }

            let twist = pose.twistRadians
            if abs(twist) > Self.maximumTwistRadians {
                let clamped = twist > 0 ? Self.maximumTwistRadians : -Self.maximumTwistRadians
                let correction = Quaternion.fromAxisAngle(axis: Vector3D(0, 1, 0), angle: clamped - twist)
                orientation = (orientation * correction).normalized
                angularVelocityRadPerSecond.y = 0
            }
        }

        let linearSpeed = velocityMps.magnitude
        let angularSpeed = angularVelocityRadPerSecond.magnitude
        let facingForward = abs(pose.twistRadians) < Self.settleTwistRadians
        if linearSpeed < Self.settleVelocityMps,
           angularSpeed < Self.settleAngularVelocityRadPerSecond, facingForward {
            timeBelowSettleThresholdS += dt
            if timeBelowSettleThresholdS >= Self.settleTimeS { isMoving = false }
        } else {
            timeBelowSettleThresholdS = 0
            isMoving = true
        }
    }

    private mutating func applyImpulse(_ impulse: Vector3D, at worldPoint: Vector3D) {
        velocityMps = velocityMps + impulse / massKg
        let torqueWorld = (worldPoint - centerOfMassM).cross(impulse)
        applyTorqueImpulse(torqueWorld)
    }

    private mutating func applyForce(_ force: Vector3D, at worldPoint: Vector3D, dt: Float) {
        applyImpulse(force * dt, at: worldPoint)
    }

    private mutating func applyTorqueImpulse(_ torqueWorld: Vector3D) {
        let torqueLocal = orientation.conjugate.rotate(torqueWorld)
        let accelerationLocal = Vector3D(torqueLocal.x / inertiaKgM2.x,
                                         torqueLocal.y / inertiaKgM2.y,
                                         torqueLocal.z / inertiaKgM2.z)
        angularVelocityRadPerSecond = angularVelocityRadPerSecond + orientation.rotate(accelerationLocal)
    }

    private mutating func applyChainForces(dt: Float) {
        for anchor in anchors {
            let worldAttachment = centerOfMassM + orientation.rotate(anchor.localAttachment)
            let vector = worldAttachment - anchor.worldFixed
            let distance = vector.magnitude
            guard distance >= 1e-6 else { continue }
            let extensionM = distance - anchor.restLength
            guard extensionM > 0 else { continue }
            let direction = (anchor.worldFixed - worldAttachment) / distance
            let radius = worldAttachment - centerOfMassM
            let attachmentVelocity = velocityMps + angularVelocityRadPerSecond.cross(radius)
            let velocityAlongChain = attachmentVelocity.dot(direction)
            var force = direction * (Self.chainSpringNPerM * extensionM)
            if velocityAlongChain > 0 {
                force = force + direction * (-Self.chainDampingNsPerM * velocityAlongChain)
            }
            applyForce(force, at: worldAttachment, dt: dt)
        }
    }
}
