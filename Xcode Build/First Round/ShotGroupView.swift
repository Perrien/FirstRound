import SwiftUI

struct ShotGroupContext {
    var request: BallisticRequest
    var deterministicCenterM: Vector2D
}

private final class GroupCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    func isCancelled() -> Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

struct ShotGroupView: View {
    let contextProvider: (Float) throws -> ShotGroupContext
    let startingValues: CartridgeDefault.DispersionValues?
    let distanceSystem: DistanceUnitSystem
    let inputSignature: String

    @State private var shotCount = "50"
    @State private var seed = "12345"
    @State private var targetRange = "300"
    @State private var plateDiameter = "6"
    @State private var mvSD = "2.7"
    @State private var bcSD = "0.5"
    @State private var rifleCone = "0.5"
    @State private var cantLimit = "0"
    @State private var crosswindSD = "0"
    @State private var headwindSD = "0"
    @State private var updraftSD = "0"
    @State private var applyCorrection = false
    @State private var result: ShotGroupResult?
    @State private var selectedShot: Int?
    @State private var error: String?
    @State private var completed = 0
    @State private var running = false
    @State private var cancellation: GroupCancellation?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private let chartHalfSpan: Float = 0.3

    var body: some View {
        NavigationStack {
            Form {
                Section("Group setup") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        numberField("Shots", text: $shotCount, unit: "1–500")
                        numberField("Seed", text: $seed, unit: "UInt32")
                        numberField("Target range", text: $targetRange, unit: distanceSystem.rangeLabel)
                        numberField("Round plate diameter", text: $plateDiameter, unit: distanceSystem == .metric ? "mm" : "in")
                    }
                    Toggle("Apply computed correction", isOn: $applyCorrection)
                    Text("Uses the current editable load, atmosphere, and mean wind. The seeded field contributes to the deterministic center; per-shot wind SD adds separate scatter.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Editable dispersion") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        numberField("Muzzle velocity SD", text: $mvSD, unit: "m/s")
                        numberField("BC SD", text: $bcSD, unit: "% of nominal")
                        numberField("Rifle cone diameter", text: $rifleCone, unit: "MOA")
                        numberField("Cant limit", text: $cantLimit, unit: "degrees")
                        numberField("Crosswind SD", text: $crosswindSD, unit: "m/s")
                        numberField("Headwind SD", text: $headwindSD, unit: "m/s")
                        numberField("Updraft SD", text: $updraftSD, unit: "m/s")
                    }
                    if let startingValues {
                        Text(startingValues.sourceLabel).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        Button(running ? "Running…" : "Run group", action: runGroup).disabled(running)
                        if running {
                            ProgressView(value: Double(completed), total: Double(max(1, Int(shotCount) ?? 1)))
                                .frame(width: 150)
                            Button("Cancel") { cancellation?.cancel() }
                        }
                        if let error { Text(error).foregroundStyle(.red) }
                    }
                }
                if let result {
                    Section("Target plot · 0.6 m fixed span") {
                        GeometryReader { geometry in
                            Canvas { context, size in draw(result, in: &context, size: size) }
                                .contentShape(Rectangle())
                                .onTapGesture { point in selectedShot = nearestShot(in: result, point: point, size: geometry.size) }
                        }
                        .frame(height: 420)
                        Text("Blue: hit · Orange: miss. Plate outline includes the bullet-radius line break.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Statistics") {
                        LabeledContent("Seed and shots", value: "\(result.seed) · \(result.shots.count)")
                        LabeledContent("Hits", value: "\(result.statistics.hitCount) / \(result.shots.count) (\(percent(result.statistics.hitCount, result.shots.count))%)")
                        LabeledContent("Group center from plate", value: "x \(m(result.statistics.centerM.x)), y \(m(result.statistics.centerM.y))")
                        LabeledContent("Mean radius about group center", value: m(result.statistics.meanRadiusAboutGroupCenterM))
                        LabeledContent("Extreme spread (maximum pair distance)", value: m(result.statistics.extremeSpreadM))
                        LabeledContent("RMS radius from intended center", value: m(result.statistics.rmsRadiusFromAimM))
                    }
                    Section("Shot table") {
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                HStack { Text("Shot").frame(width: 50, alignment: .leading); Text("x (m)").frame(width: 90, alignment: .leading); Text("y (m)").frame(width: 90, alignment: .leading); Text("MV (m/s)").frame(width: 100, alignment: .leading); Text("BC").frame(width: 80, alignment: .leading) }
                                    .font(.caption.bold()).padding(.vertical, 5)
                                ForEach(result.shots) { shot in
                                    Button { selectedShot = shot.id } label: {
                                        HStack {
                                            Text("\(shot.id)").frame(width: 50, alignment: .leading)
                                            Text(String(format: "%.5f", shot.offsetM.x)).frame(width: 90, alignment: .leading)
                                            Text(String(format: "%.5f", shot.offsetM.y)).frame(width: 90, alignment: .leading)
                                            Text(String(format: "%.3f", shot.muzzleVelocityMps)).frame(width: 100, alignment: .leading)
                                            Text(String(format: "%.6f", shot.ballisticCoefficient)).frame(width: 80, alignment: .leading)
                                            Text(shot.offsetM.magnitude <= result.plateDiameterM / 2 + result.bulletDiameterM / 2 ? "Hit" : "Miss")
                                        }
                                        .font(.caption.monospacedDigit())
                                        .padding(.vertical, 3)
                                        .background(selectedShot == shot.id ? Color.accentColor.opacity(0.14) : .clear)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    if let selected = result.shots.first(where: { $0.id == selectedShot }) {
                        Section("Shot \(selected.id)") {
                            LabeledContent("Impact x / y", value: "\(m(selected.offsetM.x)) / \(m(selected.offsetM.y))")
                            LabeledContent("Sampled MV / BC", value: "\(String(format: "%.3f", selected.muzzleVelocityMps)) m/s · \(String(format: "%.6f", selected.ballisticCoefficient))")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Shot Group Inspection")
            .frame(minWidth: 900, minHeight: 820)
            .onChange(of: shotCount) { invalidate() }
            .onChange(of: seed) { invalidate() }
            .onChange(of: targetRange) { invalidate() }
            .onChange(of: plateDiameter) { invalidate() }
            .onChange(of: mvSD) { invalidate() }
            .onChange(of: bcSD) { invalidate() }
            .onChange(of: rifleCone) { invalidate() }
            .onChange(of: cantLimit) { invalidate() }
            .onChange(of: crosswindSD) { invalidate() }
            .onChange(of: headwindSD) { invalidate() }
            .onChange(of: updraftSD) { invalidate() }
            .onChange(of: applyCorrection) { invalidate() }
            .onChange(of: startingValuesToken) { _, _ in applyDefaults() }
            .onChange(of: inputSignature) { invalidate() }
            .onAppear(perform: applyDefaults)
        }
    }

    private func numberField(_ title: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption)
            HStack { TextField("", text: text).textFieldStyle(.roundedBorder); Text(unit).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private var startingValuesToken: String {
        guard let startingValues else { return "none" }
        return "\(startingValues.muzzleVelocitySDMps)|\(startingValues.bcSDPercent)|\(startingValues.rifleConeMOADiameter)|\(startingValues.sourceLabel)"
    }

    private func applyDefaults() {
        guard let startingValues else { return }
        if result == nil {
            targetRange = distanceSystem == .metric ? "274.32" : "300"
            plateDiameter = distanceSystem == .metric ? "152.4" : "6"
        }
        mvSD = String(startingValues.muzzleVelocitySDMps)
        bcSD = String(startingValues.bcSDPercent)
        rifleCone = String(startingValues.rifleConeMOADiameter)
        cantLimit = String(startingValues.cantLimitDegrees)
        crosswindSD = String(startingValues.crosswindSDMps)
        headwindSD = String(startingValues.headwindSDMps)
        updraftSD = String(startingValues.updraftSDMps)
    }

    private func invalidate() { result = nil; selectedShot = nil; error = nil }

    private func runGroup() {
        invalidate(); error = nil
        guard let count = Int(shotCount), (1...500).contains(count),
              let seedValue = UInt32(seed), let rangeDisplay = Double(targetRange), rangeDisplay > 0,
              let plateDisplay = Double(plateDiameter), plateDisplay > 0,
              let mv = Double(mvSD), let bc = Double(bcSD), let cone = Double(rifleCone),
              let cant = Double(cantLimit), let cross = Double(crosswindSD),
              let head = Double(headwindSD), let up = Double(updraftSD),
              [mv, bc, cone, cant, cross, head, up].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            error = "Enter a valid count, UInt32 seed, positive range and plate size, and nonnegative dispersion values."; return
        }
        do {
            let rangeM = Float(distanceSystem.meters(fromRange: rangeDisplay))
            let plateM = Float(distanceSystem == .metric ? plateDisplay / 1000 : plateDisplay * 0.0254)
            let groupContext = try contextProvider(rangeM)
            let params = DispersionParameters(muzzleVelocitySDMps: Float(mv),
                ballisticCoefficientSDFraction: Float(bc / 100),
                rifleConeDiameterRadians: Float(cone * Double.pi / (180 * 60)),
                cantLimitRadians: Float(cant * Double.pi / 180), crosswindSDMps: Float(cross),
                headwindSDMps: Float(head), updraftSDMps: Float(up))
            let simulator = try ShotGroupSimulator(request: groupContext.request, parameters: params,
                targetRangeM: rangeM, shotCount: count, seed: seedValue, plateDiameterM: plateM,
                applyComputedCorrection: applyCorrection, deterministicCenterM: groupContext.deterministicCenterM)
            let token = GroupCancellation(); cancellation = token; running = true; completed = 0
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let group = try simulator.run(progress: { done, _ in
                        DispatchQueue.main.async { completed = done }
                    }, isCancelled: { token.isCancelled() })
                    DispatchQueue.main.async { result = group; running = false; cancellation = nil }
                } catch {
                    DispatchQueue.main.async {
                        self.error = error.localizedDescription; running = false; cancellation = nil
                    }
                }
            }
        } catch let failure { error = failure.localizedDescription }
    }

    private func draw(_ result: ShotGroupResult, in context: inout GraphicsContext, size: CGSize) {
        let scale = CGFloat(size.width) / CGFloat(2 * chartHalfSpan)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let plateRadius = CGFloat(result.plateDiameterM / 2) * scale
        let target = CGRect(x: center.x - plateRadius, y: center.y - plateRadius, width: 2 * plateRadius, height: 2 * plateRadius)
        context.stroke(Path(ellipseIn: target), with: .color(.primary), lineWidth: 2)
        let bulletRadius = CGFloat(result.bulletDiameterM / 2) * scale
        let lineBreak = target.insetBy(dx: -bulletRadius, dy: -bulletRadius)
        context.stroke(Path(ellipseIn: lineBreak), with: .color(.secondary.opacity(0.55)), lineWidth: 1)
        for shot in result.shots {
            let p = CGPoint(x: center.x + CGFloat(shot.offsetM.x) * scale,
                            y: center.y - CGFloat(shot.offsetM.y) * scale)
            let radius: CGFloat = shot.id == selectedShot ? 5 : 3.2
            let dot = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(shot.offsetM.magnitude <= result.plateDiameterM / 2 + result.bulletDiameterM / 2 ? .blue : .orange))
        }
        var xAxis = Path(); xAxis.move(to: CGPoint(x: 0, y: center.y)); xAxis.addLine(to: CGPoint(x: size.width, y: center.y))
        var yAxis = Path(); yAxis.move(to: CGPoint(x: center.x, y: 0)); yAxis.addLine(to: CGPoint(x: center.x, y: size.height))
        context.stroke(xAxis, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
        context.stroke(yAxis, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
        context.draw(Text("x / y (m) · plate Ø \(String(format: "%.0f", result.plateDiameterM * 1000)) mm"),
                     at: CGPoint(x: 10, y: 14), anchor: .topLeading)
        context.draw(Text("x / y (m) · plate Ø \(String(format: "%.0f", result.plateDiameterM * 1000)) mm"),
                     at: CGPoint(x: 10, y: 14), anchor: .topLeading)
    }

    private func nearestShot(in result: ShotGroupResult, point: CGPoint, size: CGSize) -> Int? {
        let scale = size.width / CGFloat(2 * chartHalfSpan)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return result.shots.min(by: { a, b in
            distance(point, CGPoint(x: center.x + CGFloat(a.offsetM.x) * scale, y: center.y - CGFloat(a.offsetM.y) * scale))
                < distance(point, CGPoint(x: center.x + CGFloat(b.offsetM.x) * scale, y: center.y - CGFloat(b.offsetM.y) * scale))
        })?.id
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
    private func m(_ value: Float) -> String { String(format: "%.4f m", value) }
    private func percent(_ hits: Int, _ count: Int) -> String { String(format: "%.1f", 100 * Double(hits) / Double(count)) }
}
