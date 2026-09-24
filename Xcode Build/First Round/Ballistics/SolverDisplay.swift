import Foundation

enum DistanceUnitSystem: String, CaseIterable, Identifiable, Hashable {
    case metric = "Metric"
    case imperial = "Imperial"

    var id: String { rawValue }
    var rangeLabel: String { self == .metric ? "m" : "yd" }
    var displacementLabel: String { self == .metric ? "m" : "in" }
    var speedLabel: String { self == .metric ? "m/s" : "ft/s" }
    var windSpeedLabel: String { self == .metric ? "m/s" : "mph" }
    var altitudeLabel: String { self == .metric ? "m" : "ft" }
    var temperatureLabel: String { self == .metric ? "°C" : "°F" }
    var scopeHeightLabel: String { self == .metric ? "mm" : "in" }

    func meters(fromRange value: Double) -> Double { self == .metric ? value : value * 0.9144 }
    func range(fromMeters value: Double) -> Double { self == .metric ? value : value / 0.9144 }
    func displacement(fromMeters value: Double) -> Double { self == .metric ? value : value / 0.0254 }
    func speed(fromMetersPerSecond value: Double) -> Double { self == .metric ? value : value / 0.3048 }
    func windMetersPerSecond(fromDisplay value: Double) -> Double { self == .metric ? value : value * 0.44704 }
    func altitudeMeters(fromDisplay value: Double) -> Double { self == .metric ? value : value * 0.3048 }
    func displayAltitude(fromMeters value: Double) -> Double { self == .metric ? value : value / 0.3048 }
    func temperatureKelvin(fromDisplay value: Double) -> Double {
        self == .metric ? value + 273.15 : (value - 32) * 5 / 9 + 273.15
    }
    func displayTemperature(fromKelvin value: Double) -> Double {
        self == .metric ? value - 273.15 : (value - 273.15) * 9 / 5 + 32
    }
    func scopeHeightMeters(fromDisplay value: Double) -> Double {
        self == .metric ? value / 1000 : value * 0.0254
    }
    func displayScopeHeight(fromMeters value: Double) -> Double {
        self == .metric ? value * 1000 : value / 0.0254
    }
    func displayEnergy(fromJoules value: Double) -> Double { self == .metric ? value : value * 0.737562149 }
    var energyLabel: String { self == .metric ? "J" : "ft·lbf" }
}

enum AngleUnit: String, CaseIterable, Identifiable, Hashable {
    case mil = "MIL"
    case moa = "MOA"

    var id: String { rawValue }
    var label: String { rawValue }

    func value(fromRadians radians: Double) -> Double {
        self == .mil ? radians * 1000 : radians * 180 * 60 / Double.pi
    }
}

enum SolverDisplay {
    static func correctionText(displacementM: Double, rangeM: Double, axis: CorrectionAxis, unit: AngleUnit) -> String {
        let signedRadians: Double
        switch axis {
        case .elevation: signedRadians = atan2(-displacementM, rangeM)
        case .windage: signedRadians = atan2(displacementM, rangeM)
        }
        let value = unit.value(fromRadians: abs(signedRadians))
        guard value >= 0.005 else { return "0.00 \(unit.label)" }
        let direction: String
        switch axis {
        case .elevation: direction = signedRadians >= 0 ? "Up" : "Down"
        case .windage: direction = signedRadians >= 0 ? "Left" : "Right"
        }
        return "\(direction) \(value.formatted(.number.precision(.fractionLength(2)))) \(unit.label)"
    }
}

enum CorrectionAxis {
    case elevation
    case windage
}
