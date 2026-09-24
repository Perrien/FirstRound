import Foundation

enum DragModel: String, Codable, Hashable {
    case g1 = "G1"
    case g7 = "G7"
}

struct BallisticLoad {
    var massKg: Float
    var diameterM: Float
    var lengthM: Float
    var bc: Float
    var dragModel: DragModel
    var muzzleVelocityMps: Float
    var twistM: Float
    /// Optional pre-rounded value for callers that derive spin from Double inputs.
    var spinRateOverrideRadPerSecond: Float? = nil

    var spinRateRadPerSecond: Float {
        if let spinRateOverrideRadPerSecond { return spinRateOverrideRadPerSecond }
        // The matrix harness computes this in JavaScript Double, then passes
        // the rounded value into the Float solver.
        return Float((2 * Double.pi * Double(muzzleVelocityMps)) / Double(twistM))
    }
}

struct AtmosphereInput {
    var temperatureK: Float
    var altitudeM: Float
    var humidity: Float
    /// Zero asks the solver to derive pressure from altitude.
    var pressurePa: Float
}

struct ConstantWind {
    var xMps: Float
    var yMps: Float
    var zMps: Float

    var vector: Vector3D { Vector3D(xMps, yMps, zMps) }
    static let calm = ConstantWind(xMps: 0, yMps: 0, zMps: 0)
}

enum ZeroMode: Equatable {
    /// Reproduces the historical reference matrix: wind is present while zeroing.
    case legacyWindAware
    /// Finds the launch state in calm air, then applies live wind to the shot.
    case calmAir
}

struct RangeRequest {
    var zeroRangeM: Float
    var maxRangeM: Float
    var stepM: Float
    var requestedRangesM: [Float] = []
}

struct BallisticRequest {
    var load: BallisticLoad
    var atmosphere: AtmosphereInput
    var wind: ConstantWind
    var ranges: RangeRequest
    var zeroMode: ZeroMode
    var sightHeightM: Float = 0
    var timeStepS: Float = 0.001
    var maxZeroIterations: Int = 50
    var zeroToleranceM: Float = 1e-5
    var maxTimeS: Float = 15
}

enum SolverError: LocalizedError {
    case invalidInput(String)
    case zeroRangeUnreachable(Float)
    case requestedRangeUnreachable(Float)
    case nonFiniteResult

    var errorDescription: String? {
        switch self {
        case .invalidInput(let field): return "\(field) must be finite and in its allowed range."
        case .zeroRangeUnreachable(let range): return "The bullet did not reach the zero distance of \(range) m within the time limit."
        case .requestedRangeUnreachable(let range): return "The bullet did not reach the requested distance of \(range) m within the time limit."
        case .nonFiniteResult: return "The trajectory calculation produced a non-finite value."
        }
    }
}
