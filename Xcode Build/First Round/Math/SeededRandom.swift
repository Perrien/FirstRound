import Foundation

/// MT19937, matching the engine's std::mt19937 state transition. The conversion
/// and shuffle operations are explicit so field creation is repeatable and does
/// not use Swift's process-randomized `Hasher` or `RandomNumberGenerator`.
struct SeededRandom {
    private var state = [UInt32](repeating: 0, count: 624)
    private var index = 624

    init(seed: UInt32) {
        state[0] = seed
        for i in 1..<624 {
            let previous = state[i - 1]
            state[i] = 1_812_433_253 &* (previous ^ (previous >> 30)) &+ UInt32(i)
        }
    }

    mutating func next() -> UInt32 {
        if index >= 624 { twist() }
        var value = state[index]
        index += 1
        value ^= value >> 11
        value ^= (value << 7) & 0x9D2C_5680
        value ^= (value << 15) & 0xEFC6_0000
        value ^= value >> 18
        return value
    }

    mutating func uniform(_ lower: Float, _ upper: Float) -> Float {
        // libc++ generate_canonical<float> consumes one mt19937 word, then
        // uniform_real_distribution applies (upper-lower)*u + lower.
        let unit = Float(Double(next()) / 4_294_967_296.0)
        return (upper - lower) * unit + lower
    }

    /// One libc++ `std::normal_distribution<float>` draw. The old engine creates
    /// a fresh distribution for each call, so its normally cached second variate
    /// is discarded after each sample. Keep the rejection loop and Float
    /// intermediates to match the pinned Emscripten libc++ implementation.
    mutating func normal(mean: Float, standardDeviation: Float) -> Float {
        var u: Float
        var v: Float
        var radiusSquared: Float
        repeat {
            u = uniform(-1, 1)
            v = uniform(-1, 1)
            radiusSquared = u * u + v * v
        } while radiusSquared > 1 || radiusSquared == 0
        let scale = sqrt(-2 * log(radiusSquared) / radiusSquared)
        return (u * scale) * standardDeviation + mean
    }

    mutating func shuffle(_ values: inout [Int]) {
        guard values.count > 1 else { return }
        // libc++ std::shuffle walks forward, selecting each swap offset with
        // uniform_int_distribution. Its 32-bit independent-bits engine uses
        // low-bit masking plus rejection for this 32-bit MT engine.
        for i in 0..<(values.count - 1) {
            let bound = values.count - i
            let j = uniformIndex(upperInclusive: bound - 1)
            values.swapAt(i, i + j)
        }
    }

    private mutating func uniformIndex(upperInclusive: Int) -> Int {
        guard upperInclusive > 0 else { return 0 }
        let range = UInt32(upperInclusive + 1)
        let width = 32 - (range - 1).leadingZeroBitCount
        let mask = UInt32.max >> (32 - width)
        while true {
            let candidate = next() & mask
            if candidate < range { return Int(candidate) }
        }
    }

    private mutating func twist() {
        for i in 0..<624 {
            let joined = (state[i] & 0x8000_0000) | (state[(i + 1) % 624] & 0x7fff_ffff)
            state[i] = state[(i + 397) % 624] ^ (joined >> 1) ^ ((joined & 1) == 0 ? 0 : 0x9908_B0DF)
        }
        index = 0
    }
}
