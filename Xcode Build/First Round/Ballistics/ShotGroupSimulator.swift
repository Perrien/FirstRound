import Foundation

struct ShotGroupSimulator {
    static let maximumShotCount = 500
    static let timestepS: Float = 0.001
    static let defaultPlateDiameterM: Float = 0.1524

    let request: BallisticRequest
    let parameters: DispersionParameters
    let targetRangeM: Float
    let shotCount: Int
    let seed: UInt32
    let plateDiameterM: Float
    let applyComputedCorrection: Bool
    let deterministicCenterM: Vector2D

    init(request: BallisticRequest, parameters: DispersionParameters, targetRangeM: Float,
         shotCount: Int, seed: UInt32, plateDiameterM: Float = defaultPlateDiameterM,
         applyComputedCorrection: Bool = false, deterministicCenterM: Vector2D = Vector2D()) throws {
        guard (1...Self.maximumShotCount).contains(shotCount) else { throw SolverError.invalidInput("shot count (1–500)") }
        guard targetRangeM.isFinite, targetRangeM > 0 else { throw SolverError.invalidInput("target range") }
        guard plateDiameterM.isFinite, plateDiameterM > 0 else { throw SolverError.invalidInput("plate diameter") }
        guard deterministicCenterM.x.isFinite, deterministicCenterM.y.isFinite else { throw SolverError.invalidInput("group center") }
        try parameters.validate()
        self.request = request
        self.parameters = parameters
        self.targetRangeM = targetRangeM
        self.shotCount = shotCount
        self.seed = seed
        self.plateDiameterM = plateDiameterM
        self.applyComputedCorrection = applyComputedCorrection
        self.deterministicCenterM = applyComputedCorrection ? Vector2D() : deterministicCenterM
    }

    enum RunError: LocalizedError {
        case cancelled
        var errorDescription: String? { "Shot group cancelled." }
    }

    func run(progress: (Int, Int) -> Void = { _, _ in }, isCancelled: () -> Bool = { false }) throws -> ShotGroupResult {
        // This is the legacy match simulator's calm zero at the actual plate range.
        var zeroRequest = request
        zeroRequest.wind = .calm
        zeroRequest.ranges.zeroRangeM = targetRangeM
        zeroRequest.ranges.maxRangeM = max(zeroRequest.ranges.maxRangeM, targetRangeM)
        zeroRequest.ranges.requestedRangesM = []
        zeroRequest.timeStepS = Self.timestepS
        zeroRequest.maxZeroIterations = 1000
        zeroRequest.zeroToleranceM = 1e-6
        zeroRequest.maxTimeS = 30
        let zeroSolver = try TrajectorySolver(request: zeroRequest)
        let zeroState = try zeroSolver.calmAirZeroedLaunchState()
        var random = SeededRandom(seed: seed)
        var samples: [ShotSample] = []
        samples.reserveCapacity(shotCount)

        for index in 0..<shotCount {
            if isCancelled() { throw RunError.cancelled }
            let nominalMV = request.load.muzzleVelocityMps
            let sampledMV = clippedNormal(mean: nominalMV, sd: parameters.muzzleVelocitySDMps, using: &random)
            let bcSD = request.load.bc * parameters.ballisticCoefficientSDFraction
            let sampledBC = clippedNormal(mean: request.load.bc, sd: bcSD, using: &random)

            let azimuth = random.uniform(0, 2 * Float.pi)
            let coneRadius = (parameters.rifleConeDiameterRadians * 0.5) * sqrt(random.uniform(0, 1))
            let horizontalAngle = coneRadius * cos(azimuth)
            let verticalAngle = coneRadius * sin(azimuth)
            let cant = random.uniform(-parameters.cantLimitRadians, parameters.cantLimitRadians)
            let crosswind = clippedNormal(mean: 0, sd: parameters.crosswindSDMps, using: &random)
            let headwind = clippedNormal(mean: 0, sd: parameters.headwindSDMps, using: &random)
            let updraft = clippedNormal(mean: 0, sd: parameters.updraftSDMps, using: &random)

            var velocity = zeroState.velocity * (nominalMV > 1e-6 ? sampledMV / nominalMV : 1)
            velocity.x += (-velocity.z) * horizontalAngle
            velocity.y += (-velocity.z) * verticalAngle
            let cosCant = cos(cant), sinCant = sin(cant)
            let canted = Vector3D(velocity.x * cosCant - velocity.y * sinCant,
                                  velocity.x * sinCant + velocity.y * cosCant, velocity.z)
            var variedLoad = zeroState.load
            variedLoad.bc = sampledBC
            var shotRequest = zeroRequest
            shotRequest.wind = ConstantWind(xMps: crosswind, yMps: updraft, zMps: -headwind)
            let solver = try TrajectorySolver(request: shotRequest)
            let launch = BulletState(load: variedLoad, position: zeroState.position, velocity: canted,
                                     spinRate: zeroState.spinRate)
            let impact = try solver.impact(initial: launch, at: targetRangeM)
            // The solver's internal zero target is at sight height; scatter is
            // reported around the aim point on the target plane.
            let offset = Vector2D(impact.state.position.x, impact.state.position.y - zeroRequest.sightHeightM)
            let sample = ShotSample(id: index + 1, offsetM: offset + deterministicCenterM,
                                    muzzleVelocityMps: sampledMV, ballisticCoefficient: sampledBC,
                                    rifleAngle: Vector2D(horizontalAngle, verticalAngle), cantRadians: cant,
                                    crosswindMps: crosswind, headwindMps: headwind, updraftMps: updraft,
                                    impactVelocityMps: impact.speedMps,
                                    incomingVelocityMps: impact.state.velocity)
            samples.append(sample)
            if (index + 1).isMultiple(of: 10) || index + 1 == shotCount { progress(index + 1, shotCount) }
        }
        return ShotGroupResult.summarize(shots: samples, seed: seed, plateDiameterM: plateDiameterM,
                                         bulletDiameterM: request.load.diameterM,
                                         bulletMassKg: request.load.massKg)
    }

    private func clippedNormal(mean: Float, sd: Float, using random: inout SeededRandom) -> Float {
        let sampled = random.normal(mean: mean, standardDeviation: sd)
        return min(mean + 3 * sd, max(mean - 3 * sd, sampled))
    }
}
