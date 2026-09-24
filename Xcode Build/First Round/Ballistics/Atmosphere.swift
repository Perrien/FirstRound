import Foundation

struct Atmosphere {
    static let standardDensity: Float = 1.225
    static let gravity: Float = 9.80665
    private static let universalGasConstant: Float = 8.31446
    private static let molarMassDryAir: Float = 0.028965
    private static let standardPressure: Float = 101325
    private static let standardTemperature: Float = 288.15
    private static let lapseRate: Float = -0.0065
    private static let heatCapacityRatio: Float = 1.4

    let temperatureK: Float
    let altitudeM: Float
    let humidity: Float
    let pressurePa: Float

    init(_ input: AtmosphereInput) {
        temperatureK = input.temperatureK
        altitudeM = input.altitudeM
        humidity = input.humidity
        pressurePa = input.pressurePa > 0 ? input.pressurePa : Self.pressure(at: input.altitudeM)
    }

    var densityKgPerM3: Float {
        let specificGasConstant = Self.universalGasConstant / Self.molarMassDryAir
        let celsius = temperatureK - 273.15
        let saturationVaporPressure = 611.2 * exp(17.67 * celsius / (temperatureK + 243.5 - 273.15))
        let vaporPressure = humidity * saturationVaporPressure
        return (pressurePa - 0.378 * vaporPressure) / (specificGasConstant * temperatureK)
    }

    var speedOfSoundMps: Float {
        sqrt(Self.heatCapacityRatio * pressurePa / densityKgPerM3)
    }

    private static func pressure(at altitudeM: Float) -> Float {
        let specificGasConstant = universalGasConstant / molarMassDryAir
        let exponent = -gravity / (specificGasConstant * lapseRate)
        let base = 1 + lapseRate * altitudeM / standardTemperature
        guard base > 0 else { return 0 }
        return standardPressure * pow(base, exponent)
    }
}
