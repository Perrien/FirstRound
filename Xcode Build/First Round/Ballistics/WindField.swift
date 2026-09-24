import Foundation

enum WindInputMode: String, CaseIterable, Identifiable {
    case constant = "Constant wind"
    case moderate = "Moderate gust field"
    var id: String { rawValue }
}

/// A seeded, zero-mean gust field based on the legacy `Moderate` preset.
/// The directional mean wind remains a separate input added by the solver.
final class WindField {
    struct Bounds {
        var minimum: Vector3D
        var maximum: Vector3D
    }

    private struct Component {
        var strength: Float
        var downrangeScale: Float
        var crossrangeScale: Float
        var temporalScale: Float
        var exponent: Float
        var sigmoidThreshold: Float
        var rms: Float = 0
        var noise: SimplexNoise
    }

    let seed: UInt32
    private let bounds: Bounds
    private var random: SeededRandom
    private var components: [Component] = []
    private var currentTime: Float = 0
    private var rmsInitialized = false
    private var advectionOffset = Vector3D()
    private var advectionVelocity = Vector3D()

    init(seed: UInt32, bounds: Bounds) {
        self.seed = seed
        self.bounds = bounds
        var rng = SeededRandom(seed: seed)
        self.components = (0..<3).map { index in
            let noise = SimplexNoise(random: &rng)
            let parameters: (Float, Float, Float, Float, Float, Float)
            switch index {
            case 0: parameters = (3 * 0.44704, 10_000 * 0.9144, 10_000 * 0.9144, 10 * 60, 0.5, 0)
            case 1: parameters = (3 * 0.44704, 1_000 * 0.9144, 1_000 * 0.9144, 60, 0.75, 1)
            default: parameters = (1 * 0.44704, 100 * 0.9144, 100 * 0.9144, 0.5 * 60, 1, 0)
            }
            return Component(strength: parameters.0, downrangeScale: parameters.1,
                             crossrangeScale: parameters.2, temporalScale: parameters.3,
                             exponent: parameters.4, sigmoidThreshold: parameters.5, noise: noise)
        }
        self.random = rng
    }

    /// Matches `WindGenerator.advanceTime`: initializes RMS once, updates the
    /// global EMA advection from ten seeded samples, and clamps this update's dt.
    func advance(to time: Float) {
        let dt = min(max(time - currentTime, 0), 1)
        currentTime = time
        if !rmsInitialized {
            rmsInitialized = true
            initializeRMS()
        }
        var average = Vector3D()
        for _ in 0..<10 {
            let position = Vector3D(random.uniform(bounds.minimum.x, bounds.maximum.x),
                                    random.uniform(bounds.minimum.y, bounds.maximum.y),
                                    random.uniform(bounds.minimum.z, bounds.maximum.z))
            average = average + sample(position)
        }
        average = average / 10
        advectionVelocity = advectionVelocity * 0.99 + average * (5 * 0.01)
        advectionOffset = advectionOffset + advectionVelocity * dt
    }

    func sample(_ position: Vector3D, at time: Float? = nil) -> Vector3D {
        let sampleTime = time ?? currentTime
        var velocity = Vector3D()
        for (index, component) in components.enumerated() {
            let curl = computeCurl(index, position, time: sampleTime)
            let magnitude = hypot(curl.x, curl.y)
            let angle = atan2(curl.y, curl.x)
            let normalized = magnitude / (component.rms + 1e-6)
            var finalMagnitude = pow(normalized, component.exponent) * component.strength
            if component.sigmoidThreshold > 0 {
                let threshold = component.sigmoidThreshold * component.strength
                finalMagnitude /= 1 + exp(-4 * (finalMagnitude - threshold))
            }
            finalMagnitude = min(finalMagnitude, 2 * component.strength)
            velocity = velocity + Vector3D(finalMagnitude * sin(angle), 0, -finalMagnitude * cos(angle))
        }
        return velocity
    }

    private func initializeRMS() {
        for index in components.indices {
            var sum: Float = 0
            for _ in 0..<1000 {
                let c = components[index]
                let cross = random.uniform(-1000, 1000) * c.crossrangeScale
                let downrange = random.uniform(-1000, 1000) * c.downrangeScale
                let time = currentTime + random.uniform(-1000, 1000) * c.temporalScale
                let curl = computeCurl(index, Vector3D(cross, 0, -downrange), time: time)
                sum += curl.x*curl.x + curl.y*curl.y
            }
            components[index].rms = sqrt(sum / 1000)
        }
    }

    private func computeCurl(_ index: Int, _ position: Vector3D, time: Float) -> Vector3D {
        let component = components[index]
        guard component.downrangeScale >= 1e-6, component.crossrangeScale >= 1e-6,
              component.temporalScale >= 1e-6 else { return Vector3D() }
        let downrange = -position.z + advectionOffset.z
        let crossrange = position.x - advectionOffset.x
        let x = downrange / component.downrangeScale
        let y = crossrange / component.crossrangeScale
        let t = time / component.temporalScale
        let epsilon: Float = 0.01
        let dX = (component.noise.noise3D(x + epsilon, y, t) - component.noise.noise3D(x - epsilon, y, t)) / (2 * epsilon)
        let dY = (component.noise.noise3D(x, y + epsilon, t) - component.noise.noise3D(x, y - epsilon, t)) / (2 * epsilon)
        return Vector3D(dY / component.crossrangeScale, -dX / component.downrangeScale, 0)
    }
}
