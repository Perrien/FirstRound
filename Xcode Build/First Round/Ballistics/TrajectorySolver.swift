import Foundation

struct TrajectorySolver {
    private static let retardationK: Float = 4795.4
    private let request: BallisticRequest
    private let atmosphere: Atmosphere
    private let windSampler: ((Vector3D, Float) -> Vector3D)?

    init(request: BallisticRequest, windSampler: ((Vector3D, Float) -> Vector3D)? = nil) throws {
        try Self.validate(request)
        self.request = request
        self.atmosphere = Atmosphere(request.atmosphere)
        self.windSampler = windSampler
        guard atmosphere.pressurePa.isFinite, atmosphere.pressurePa > 0,
              atmosphere.densityKgPerM3.isFinite, atmosphere.densityKgPerM3 > 0,
              atmosphere.speedOfSoundMps.isFinite, atmosphere.speedOfSoundMps > 0 else {
            throw SolverError.invalidInput("atmosphere")
        }
    }

    func solve() throws -> TrajectorySolution {
        let zeroWind = request.zeroMode == .legacyWindAware ? request.wind.vector : Vector3D()
        let zero = try findZero(wind: zeroWind)
        let liveTrajectory = try simulate(initial: zero.initialState, meanWind: request.wind.vector,
                                          maxDistanceM: request.ranges.maxRangeM * 1.05)

        var sampleRanges: [Float] = []
        var range = request.ranges.stepM
        while range <= request.ranges.maxRangeM + 1e-6 {
            sampleRanges.append(range)
            range += request.ranges.stepM
        }
        sampleRanges.append(request.ranges.zeroRangeM)
        sampleRanges.append(contentsOf: request.ranges.requestedRangesM)
        sampleRanges.sort()
        var uniqueSampleRanges: [Float] = []
        for sampleRange in sampleRanges {
            if uniqueSampleRanges.last.map({ abs($0 - sampleRange) <= 1e-5 }) != true {
                uniqueSampleRanges.append(sampleRange)
            }
        }

        var rows: [TrajectoryRow] = []
        for range in uniqueSampleRanges {
            guard let point = liveTrajectory.atDistance(range) else {
                throw SolverError.requestedRangeUnreachable(range)
            }
            let position = point.state.position
            let speed = point.speedMps
            let energy = 0.5 * request.load.massKg * speed * speed
            let row = TrajectoryRow(rangeM: range,
                                    dropM: position.y - request.sightHeightM,
                                    windageM: position.x,
                                    velocityMps: speed,
                                    timeOfFlightS: point.timeS,
                                    kineticEnergyJ: energy)
            guard row.rangeM.isFinite, row.dropM.isFinite, row.windageM.isFinite,
                  row.velocityMps.isFinite, row.timeOfFlightS.isFinite, row.kineticEnergyJ.isFinite else {
                throw SolverError.nonFiniteResult
            }
            rows.append(row)
        }
        return TrajectorySolution(rows: rows, zero: zero.result)
    }

    /// Reuses this solver's validated launch model for a cached target-range zero.
    /// Group sampling creates a request whose zero range is its selected target
    /// range, then keeps this exact launch state for every shot.
    func calmAirZeroedLaunchState() throws -> BulletState {
        try findZero(wind: Vector3D()).initialState
    }

    /// Flies an already prepared launch state without recalculating its zero.
    /// The caller supplies per-shot wind variance; deterministic mean wind and
    /// the owner's computed center remain outside this scatter calculation.
    func impact(initial: BulletState, at rangeM: Float) throws -> TrajectoryPoint {
        guard rangeM.isFinite, rangeM > 0 else { throw SolverError.invalidInput("target range") }
        let trajectory = try simulate(initial: initial, meanWind: request.wind.vector,
                                      maxDistanceM: rangeM * 1.05, applyField: false)
        guard let impact = trajectory.atDistance(rangeM) else { throw SolverError.requestedRangeUnreachable(rangeM) }
        return impact
    }

    private struct ZeroSearchResult {
        var initialState: BulletState
        var result: ZeroResult
    }

    private func findZero(wind: Vector3D) throws -> ZeroSearchResult {
        var pitch: Float = 0.01
        var yaw: Float = 0
        var bestPitch = pitch
        var bestYaw = yaw
        var bestVertical: Float = 0
        var bestLateral: Float = 0
        var bestError = Float.greatestFiniteMagnitude
        var trialsWithoutImprovement = 0
        var converged = false
        let target = Vector3D(0, request.sightHeightM, -request.ranges.zeroRangeM)

        for _ in 0..<request.maxZeroIterations {
            let candidate = makeInitialState(pitch: pitch, yaw: yaw)
            let trajectory = try simulate(initial: candidate, meanWind: wind,
                                          maxDistanceM: request.ranges.zeroRangeM * 1.1,
                                          applyField: false)
            guard let point = trajectory.atDistance(request.ranges.zeroRangeM) else {
                throw SolverError.zeroRangeUnreachable(request.ranges.zeroRangeM)
            }
            let actual = point.state.position
            let lateral = actual.x - target.x
            let vertical = actual.y - target.y
            let error = sqrt(lateral * lateral + vertical * vertical)
            guard error.isFinite else { throw SolverError.nonFiniteResult }

            if error < bestError {
                if error >= bestError * 0.999 { trialsWithoutImprovement += 1 }
                else { trialsWithoutImprovement = 0 }
                bestError = error
                bestPitch = pitch
                bestYaw = yaw
                bestVertical = vertical
                bestLateral = lateral
            } else {
                trialsWithoutImprovement += 1
            }

            if error < request.zeroToleranceM {
                converged = true
                bestPitch = pitch
                bestYaw = yaw
                bestVertical = vertical
                bestLateral = lateral
                bestError = error
                break
            }
            if trialsWithoutImprovement >= 6 { break }

            let pitchCorrection = -atan2(vertical, request.ranges.zeroRangeM)
            let yawCorrection = -atan2(lateral, request.ranges.zeroRangeM)
            pitch += 0.5 * pitchCorrection
            yaw += 0.5 * yawCorrection
        }

        let initialState = makeInitialState(pitch: bestPitch, yaw: bestYaw)
        let result = ZeroResult(converged: converged,
                                verticalDeviationM: bestVertical,
                                lateralDeviationM: bestLateral,
                                missDistanceM: bestError)
        return ZeroSearchResult(initialState: initialState, result: result)
    }

    private func makeInitialState(pitch: Float, yaw: Float) -> BulletState {
        let cosinePitch = cos(pitch)
        let sinePitch = sin(pitch)
        let cosineYaw = cos(yaw)
        let sineYaw = sin(yaw)
        let velocity = Vector3D(request.load.muzzleVelocityMps * cosinePitch * sineYaw,
                               request.load.muzzleVelocityMps * sinePitch,
                               -request.load.muzzleVelocityMps * cosinePitch * cosineYaw)
        return BulletState(load: request.load, position: Vector3D(), velocity: velocity,
                           spinRate: request.load.spinRateRadPerSecond)
    }

    private func simulate(initial: BulletState, meanWind: Vector3D, maxDistanceM: Float,
                          applyField: Bool = true) throws -> Trajectory {
        var state = initial
        // Match the legacy core: recover twist from this launch state's speed
        // and signed spin rate before applying the corrected Miller formula.
        let twistPitchM = 2 * Float.pi * state.speedMps / abs(state.spinRate)
        let twistInches = twistPitchM * 39.3701
        let stability = state.correctedMillerStability(twistInchesPerTurn: twistInches,
                                                       temperatureK: atmosphere.temperatureK,
                                                       pressurePa: atmosphere.pressurePa)
        var time: Float = 0
        var previousCrosswind: Float = 0
        var trajectory = Trajectory()
        var wind = sampledWind(mean: meanWind, position: state.position, time: time, applyField: applyField)
        trajectory.append(TrajectoryPoint(timeS: time, state: state, wind: wind))

        while time < request.maxTimeS {
            // The legacy field solver samples once at the start of each RK2
            // step and holds that local value through its midpoint evaluation.
            wind = sampledWind(mean: meanWind, position: state.position, time: time, applyField: applyField)
            // The first step includes the 0 -> muzzle wind jump.
            let right = horizontalRight(state.velocity)
            let crosswind = wind.dot(right)
            let deltaCrosswind = crosswind - previousCrosswind
            previousCrosswind = crosswind
            if deltaCrosswind != 0 {
                state.velocity.y += crosswindJumpVelocity(state: state, deltaCrosswind: deltaCrosswind,
                                                          stability: stability)
            }

            let dt = request.timeStepS
            let a0 = acceleration(state: state, wind: wind, stability: stability, atTime: max(time, dt))
            let halfVelocity = state.velocity + a0 * (0.5 * dt)
            let halfPosition = state.position + halfVelocity * (0.5 * dt)
            let midpoint = BulletState(load: state.load, position: halfPosition,
                                       velocity: halfVelocity, spinRate: state.spinRate)
            let midpointAcceleration = acceleration(state: midpoint, wind: wind, stability: stability,
                                                    atTime: max(time + 0.5 * dt, dt))
            let nextVelocity = state.velocity + midpointAcceleration * dt
            let nextPosition = state.position + halfVelocity * dt
            state = BulletState(load: state.load, position: nextPosition,
                                velocity: nextVelocity, spinRate: state.spinRate)
            time += dt
            guard state.position.x.isFinite, state.position.y.isFinite, state.position.z.isFinite,
                  state.velocity.x.isFinite, state.velocity.y.isFinite, state.velocity.z.isFinite else {
                throw SolverError.nonFiniteResult
            }
            trajectory.append(TrajectoryPoint(timeS: time, state: state, wind: wind))
            if -state.position.z > maxDistanceM { break }
        }
        return trajectory
    }

    private func sampledWind(mean: Vector3D, position: Vector3D, time: Float, applyField: Bool) -> Vector3D {
        mean + (applyField ? (windSampler?(position, time) ?? Vector3D()) : Vector3D())
    }

    private func acceleration(state: BulletState, wind: Vector3D, stability: Float, atTime time: Float) -> Vector3D {
        let relativeVelocity = state.velocity - wind
        let relativeSpeed = relativeVelocity.magnitude
        var acceleration = Vector3D(0, -Atmosphere.gravity, 0)
        guard relativeSpeed > 0 else { return acceleration }

        let mach = relativeSpeed / atmosphere.speedOfSoundMps
        let cd = DragTables.coefficient(mach: mach, model: state.load.dragModel)
        let speedFps = relativeSpeed * 3.28084
        let densityRatio = atmosphere.densityKgPerM3 / Atmosphere.standardDensity
        let retardationFps2 = cd * speedFps * speedFps * densityRatio / (Self.retardationK * state.load.bc)
        let dragRetardation = retardationFps2 * 0.3048
        acceleration = acceleration + relativeVelocity / relativeSpeed * -dragRetardation

        if stability > 0, time > 0 {
            let coefficientM = (1.25 * (stability + 1.2)) * 0.0254
            let driftAcceleration = 1.83 * 0.83 * coefficientM * pow(time, -0.17)
            let hand: Float = state.spinRate >= 0 ? 1 : -1
            acceleration = acceleration + horizontalRight(state.velocity) * (driftAcceleration * hand)
        }
        return acceleration
    }

    private func crosswindJumpVelocity(state: BulletState, deltaCrosswind: Float, stability: Float) -> Float {
        guard stability > 0 else { return 0 }
        let speed = state.speedMps
        guard speed >= 1e-3 else { return 0 }
        let lengthCalibers = state.load.lengthM / state.load.diameterM
        let sensitivityMoaPerMph = 0.01 * stability - 0.0024 * lengthCalibers + 0.032
        let jumpMoa = sensitivityMoaPerMph * deltaCrosswind * 2.23694
        let jumpRadians = jumpMoa * Float.pi / 10800
        let hand: Float = state.spinRate >= 0 ? 1 : -1
        return -speed * jumpRadians * hand
    }

    private func horizontalRight(_ velocity: Vector3D) -> Vector3D {
        let horizontal = Vector3D(velocity.x, 0, velocity.z)
        let magnitude = horizontal.magnitude
        let forward = magnitude > 1e-9 ? horizontal / magnitude : Vector3D(0, 0, -1)
        return forward.cross(Vector3D(0, 1, 0))
    }

    private static func validate(_ request: BallisticRequest) throws {
        let load = request.load
        for (name, value) in [("mass", load.massKg), ("diameter", load.diameterM),
                              ("length", load.lengthM), ("BC", load.bc),
                              ("muzzle velocity", load.muzzleVelocityMps), ("twist", load.twistM),
                              ("zero range", request.ranges.zeroRangeM), ("maximum range", request.ranges.maxRangeM),
                              ("step", request.ranges.stepM), ("time step", request.timeStepS),
                              ("zero tolerance", request.zeroToleranceM), ("maximum time", request.maxTimeS)] {
            guard value.isFinite, value > 0 else { throw SolverError.invalidInput(name) }
        }
        guard request.ranges.maxRangeM >= request.ranges.zeroRangeM else { throw SolverError.invalidInput("maximum range") }
        for range in request.ranges.requestedRangesM {
            guard range.isFinite, range > 0, range <= request.ranges.maxRangeM else {
                throw SolverError.invalidInput("specific requested range")
            }
        }
        guard request.maxZeroIterations > 0 else { throw SolverError.invalidInput("zero iterations") }
        let atmosphere = request.atmosphere
        guard atmosphere.temperatureK.isFinite, atmosphere.temperatureK > 0 else { throw SolverError.invalidInput("temperature") }
        guard atmosphere.altitudeM.isFinite else { throw SolverError.invalidInput("altitude") }
        guard atmosphere.humidity.isFinite, (0...1).contains(atmosphere.humidity) else { throw SolverError.invalidInput("humidity") }
        guard atmosphere.pressurePa.isFinite, atmosphere.pressurePa >= 0 else { throw SolverError.invalidInput("pressure") }
        guard request.wind.xMps.isFinite, request.wind.yMps.isFinite, request.wind.zMps.isFinite else {
            throw SolverError.invalidInput("wind")
        }
        guard request.sightHeightM.isFinite, request.sightHeightM >= 0 else { throw SolverError.invalidInput("sight height") }
    }
}
