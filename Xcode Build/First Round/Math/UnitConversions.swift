import Foundation

/// Exact presentation-layer conversions from box units to SI.
enum UnitConversions {
    private static let kilogramsPerGrain = 0.00006479891
    private static let metersPerInch = 0.0254
    private static let metersPerSecondPerFootPerSecond = 0.3048

    static func positiveNumber(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite, value > 0 else { return nil }
        return value
    }

    static func grainsToKilograms(_ grains: Double) -> Double? {
        guard grains.isFinite, grains > 0 else { return nil }
        return grains * kilogramsPerGrain
    }

    static func inchesToMeters(_ inches: Double) -> Double? {
        guard inches.isFinite, inches > 0 else { return nil }
        return inches * metersPerInch
    }

    static func feetPerSecondToMetersPerSecond(_ speed: Double) -> Double? {
        guard speed.isFinite, speed > 0 else { return nil }
        return speed * metersPerSecondPerFootPerSecond
    }

    static func inchesPerTurnToMetersPerTurn(_ twist: Double) -> Double? {
        inchesToMeters(twist)
    }
}
