import Foundation

struct CartridgeDefault: Codable, Identifiable {
    struct BoxValues: Codable {
        var bulletWeightGr: Double
        var diameterIn: Double
        var lengthIn: Double
        var bc: Double
        var dragModel: DragModel
        var muzzleVelocityFps: Double
        var twistInPerTurn: Double
    }

    struct DispersionValues: Codable {
        var muzzleVelocitySDMps: Double
        var bcSDPercent: Double
        var rifleConeMOADiameter: Double
        var cantLimitDegrees: Double
        var crosswindSDMps: Double
        var headwindSDMps: Double
        var updraftSDMps: Double
        var sourceLabel: String
    }

    var id: String
    var cartridgeId: String
    var name: String
    var box: BoxValues
    var dispersion: DispersionValues
    var provenance: String
    var recommendedMaxRangeM: Double
    var recommendedStepM: Double
}

struct CartridgeDefaults: Decodable {
    var defaults: [CartridgeDefault]

    static func load(from bundle: Bundle = .main) throws -> [CartridgeDefault] {
        guard let url = bundle.url(forResource: "CartridgeDefaults", withExtension: "json") else {
            throw DefaultsError.resourceMissing
        }
        let result = try JSONDecoder().decode(CartridgeDefaults.self, from: Data(contentsOf: url)).defaults
        guard result.count == 10, Set(result.map(\.cartridgeId)).count == 10 else {
            throw DefaultsError.invalidCatalog
        }
        return result
    }

    enum DefaultsError: LocalizedError {
        case resourceMissing
        case invalidCatalog

        var errorDescription: String? {
            switch self {
            case .resourceMissing: return "The cartridge defaults file is missing from the app bundle."
            case .invalidCatalog: return "The cartridge defaults file must contain ten unique cartridges."
            }
        }
    }
}
