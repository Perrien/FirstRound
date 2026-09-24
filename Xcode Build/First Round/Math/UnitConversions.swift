import Foundation

/// Exact presentation-layer conversions from box units to SI.
enum UnitConversions {
    nonisolated private static let kilogramsPerGrain = 0.00006479891
    nonisolated private static let metersPerInch = 0.0254
    nonisolated private static let metersPerSecondPerFootPerSecond = 0.3048

    nonisolated static func positiveNumber(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite, value > 0 else { return nil }
        return value
    }

    nonisolated static func grainsToKilograms(_ grains: Double) -> Double? {
        guard grains.isFinite, grains > 0 else { return nil }
        return grains * kilogramsPerGrain
    }

    nonisolated static func inchesToMeters(_ inches: Double) -> Double? {
        guard inches.isFinite, inches > 0 else { return nil }
        return inches * metersPerInch
    }

    nonisolated static func feetPerSecondToMetersPerSecond(_ speed: Double) -> Double? {
        guard speed.isFinite, speed > 0 else { return nil }
        return speed * metersPerSecondPerFootPerSecond
    }

    nonisolated static func inchesPerTurnToMetersPerTurn(_ twist: Double) -> Double? {
        inchesToMeters(twist)
    }
}
