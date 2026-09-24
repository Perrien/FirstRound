import Foundation

struct BulletState {
    let load: BallisticLoad
    var position: Vector3D
    var velocity: Vector3D
    var spinRate: Float

    var speedMps: Float { velocity.magnitude }

    func correctedMillerStability(twistInchesPerTurn: Float, temperatureK: Float, pressurePa: Float) -> Float {
        let massGrains = load.massKg * 15432.4
        let diameterInches = load.diameterM * 39.3701
        let lengthInches = load.lengthM * 39.3701
        let lengthCalibers = lengthInches / diameterInches
        let twistCalibers = twistInchesPerTurn / diameterInches
        let denominator = twistCalibers * twistCalibers * diameterInches * diameterInches * diameterInches
            * lengthCalibers * (1 + lengthCalibers * lengthCalibers)
        guard denominator != 0 else { return 0 }
        var stability = 30 * massGrains / denominator
        let velocityFps = speedMps * 3.28084
        let pressureInHg = pressurePa * 0.0002953
        guard velocityFps > 0, pressureInHg > 0 else { return stability }
        let temperatureRankine = temperatureK * 9 / 5
        stability *= cbrtf(velocityFps / 2800)
        stability *= (temperatureRankine / 519) * (29.92 / pressureInHg)
        return stability
    }
}
