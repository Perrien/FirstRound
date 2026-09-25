import Foundation

struct DispersionParameters: Equatable {
    var muzzleVelocitySDMps: Float
    var ballisticCoefficientSDFraction: Float
    var rifleConeDiameterRadians: Float
    var cantLimitRadians: Float
    var crosswindSDMps: Float
    var headwindSDMps: Float
    var updraftSDMps: Float

    func validate() throws {
        let values: [(String, Float)] = [
            ("muzzle velocity SD", muzzleVelocitySDMps), ("BC SD", ballisticCoefficientSDFraction),
            ("rifle accuracy", rifleConeDiameterRadians), ("cant limit", cantLimitRadians),
            ("crosswind SD", crosswindSDMps), ("headwind SD", headwindSDMps), ("updraft SD", updraftSDMps)
        ]
        for (name, value) in values where !value.isFinite || value < 0 {
            throw SolverError.invalidInput(name)
        }
    }
}

struct ShotSample: Identifiable {
    let id: Int
    let offsetM: Vector2D
    let muzzleVelocityMps: Float
    let ballisticCoefficient: Float
    let rifleAngle: Vector2D
    let cantRadians: Float
    let crosswindMps: Float
    let headwindMps: Float
    let updraftMps: Float
    let impactVelocityMps: Float

    func translated(by center: Vector2D) -> ShotSample {
        ShotSample(id: id, offsetM: offsetM + center, muzzleVelocityMps: muzzleVelocityMps,
                   ballisticCoefficient: ballisticCoefficient, rifleAngle: rifleAngle,
                   cantRadians: cantRadians, crosswindMps: crosswindMps, headwindMps: headwindMps,
                   updraftMps: updraftMps, impactVelocityMps: impactVelocityMps)
    }
}

struct ShotGroupStatistics {
    let centerM: Vector2D
    let meanRadiusAboutGroupCenterM: Float
    let extremeSpreadM: Float
    let rmsRadiusFromAimM: Float
    let hitCount: Int
}

struct ShotGroupResult {
    let seed: UInt32
    let plateDiameterM: Float
    let bulletDiameterM: Float
    let shots: [ShotSample]
    let statistics: ShotGroupStatistics

    static func summarize(shots: [ShotSample], seed: UInt32, plateDiameterM: Float,
                          bulletDiameterM: Float) -> ShotGroupResult {
        guard !shots.isEmpty else {
            return ShotGroupResult(seed: seed, plateDiameterM: plateDiameterM, bulletDiameterM: bulletDiameterM,
                                   shots: [], statistics: ShotGroupStatistics(centerM: Vector2D(),
                                   meanRadiusAboutGroupCenterM: 0, extremeSpreadM: 0, rmsRadiusFromAimM: 0, hitCount: 0))
        }
        let center = shots.reduce(Vector2D()) { $0 + $1.offsetM } / Float(shots.count)
        let radii = shots.map { ($0.offsetM - center).magnitude }
        var maximumPairDistanceM: Float = 0
        if shots.count > 1 {
            for i in 0..<(shots.count - 1) {
                for j in (i + 1)..<shots.count {
                    maximumPairDistanceM = max(maximumPairDistanceM, (shots[i].offsetM - shots[j].offsetM).magnitude)
                }
            }
        }
        let rms = sqrt(shots.reduce(Float.zero) { $0 + $1.offsetM.dot($1.offsetM) } / Float(shots.count))
        let hitRadius = plateDiameterM * 0.5 + bulletDiameterM * 0.5
        let hits = shots.reduce(0) { $0 + ($1.offsetM.magnitude <= hitRadius ? 1 : 0) }
        return ShotGroupResult(seed: seed, plateDiameterM: plateDiameterM, bulletDiameterM: bulletDiameterM,
                               shots: shots, statistics: ShotGroupStatistics(centerM: center,
                               meanRadiusAboutGroupCenterM: radii.reduce(0, +) / Float(shots.count),
                               extremeSpreadM: maximumPairDistanceM, rmsRadiusFromAimM: rms, hitCount: hits))
    }
}
