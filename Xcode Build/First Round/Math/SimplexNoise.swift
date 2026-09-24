import Foundation

/// Three-dimensional slice of the engine's SimplexNoise. Each instance owns
/// the shuffled permutation and phase offsets, just as each WindComponent does.
struct SimplexNoise {
    private var permutation = [Int](repeating: 0, count: 512)
    private let offsetX: Float
    private let offsetY: Float
    private let offsetZ: Float

    init(random: inout SeededRandom) {
        var base = Array(0..<256)
        random.shuffle(&base)
        for i in 0..<256 {
            permutation[i] = base[i]
            permutation[i + 256] = base[i]
        }
        offsetX = random.uniform(0, 1000)
        offsetY = random.uniform(0, 1000)
        offsetZ = random.uniform(0, 1000)
        // The C++ constructor also draws offset_w for noise4D. Preserve that
        // draw even though this field calls noise3D only.
        _ = random.uniform(0, 1000)
    }

    func noise3D(_ inputX: Float, _ inputY: Float, _ inputZ: Float) -> Float {
        var x = inputX + offsetX
        var y = inputY + offsetY
        var z = inputZ + offsetZ
        let f3: Float = 1 / 3
        let g3: Float = 1 / 6
        let s = (x + y + z) * f3
        let i = Self.fastFloor(x + s)
        let j = Self.fastFloor(y + s)
        let k = Self.fastFloor(z + s)
        let t = Float(i + j + k) * g3
        x -= Float(i) - t
        y -= Float(j) - t
        z -= Float(k) - t

        let i1: Int, j1: Int, k1: Int, i2: Int, j2: Int, k2: Int
        if x >= y {
            if y >= z { (i1,j1,k1,i2,j2,k2) = (1,0,0,1,1,0) }
            else if x >= z { (i1,j1,k1,i2,j2,k2) = (1,0,0,1,0,1) }
            else { (i1,j1,k1,i2,j2,k2) = (0,0,1,1,0,1) }
        } else {
            if y < z { (i1,j1,k1,i2,j2,k2) = (0,0,1,0,1,1) }
            else if x < z { (i1,j1,k1,i2,j2,k2) = (0,1,0,0,1,1) }
            else { (i1,j1,k1,i2,j2,k2) = (0,1,0,1,1,0) }
        }

        let x1 = x - Float(i1) + g3, y1 = y - Float(j1) + g3, z1 = z - Float(k1) + g3
        let x2 = x - Float(i2) + 2*g3, y2 = y - Float(j2) + 2*g3, z2 = z - Float(k2) + 2*g3
        let x3 = x - 1 + 3*g3, y3 = y - 1 + 3*g3, z3 = z - 1 + 3*g3
        let ii = i & 255, jj = j & 255, kk = k & 255
        let gi0 = permutation[ii + permutation[jj + permutation[kk]]] % 12
        let gi1 = permutation[ii+i1 + permutation[jj+j1 + permutation[kk+k1]]] % 12
        let gi2 = permutation[ii+i2 + permutation[jj+j2 + permutation[kk+k2]]] % 12
        let gi3 = permutation[ii+1 + permutation[jj+1 + permutation[kk+1]]] % 12
        let n0 = Self.corner(x, y, z, gradient: gi0)
        let n1 = Self.corner(x1, y1, z1, gradient: gi1)
        let n2 = Self.corner(x2, y2, z2, gradient: gi2)
        let n3 = Self.corner(x3, y3, z3, gradient: gi3)
        return 32 * (n0 + n1 + n2 + n3)
    }

    private static let gradients: [(Float, Float, Float)] = [
        (1,1,0),(-1,1,0),(1,-1,0),(-1,-1,0),
        (1,0,1),(-1,0,1),(1,0,-1),(-1,0,-1),
        (0,1,1),(0,-1,1),(0,1,-1),(0,-1,-1)
    ]

    private static func corner(_ x: Float, _ y: Float, _ z: Float, gradient: Int) -> Float {
        var attenuation: Float = 0.6 - x*x - y*y - z*z
        guard attenuation >= 0 else { return 0 }
        let g = gradients[gradient]
        attenuation *= attenuation
        return attenuation * attenuation * (g.0*x + g.1*y + g.2*z)
    }

    private static func fastFloor(_ value: Float) -> Int {
        value > 0 ? Int(value) : Int(value) - 1
    }
}
