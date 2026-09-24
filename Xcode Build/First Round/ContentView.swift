import SwiftUI

struct ContentView: View {
    @State private var defaults: [CartridgeDefault] = []
    @State private var selectedDefaultID = "50bmg-661-m33"

    @State private var bulletWeight = "661"
    @State private var bulletDiameter = "0.51"
    @State private var bulletLength = "2.31"
    @State private var ballisticCoefficient = "0.34"
    @State private var muzzleVelocity = "2910"
    @State private var twist = "15"
    @State private var dragModel = DragModel.g7

    @State private var temperature = "15"
    @State private var altitude = "0"
    @State private var humidity = "50"
    @State private var zeroRange = "100"
    @State private var scopeHeight = "50.8"
    @State private var windSpeed = "0"
    @State private var windDirection = "0"
    @State private var rangeStep = "100"
    @State private var maxRange = "1000"
    @State private var specificRanges = ""

    @State private var distanceSystem = DistanceUnitSystem.metric
    @State private var angleUnit = AngleUnit.mil
    @State private var solution: TrajectorySolution?
    @State private var validationErrors: [String: String] = [:]
    @State private var calculationError: String?
    @State private var defaultsError: String?

    private let twoColumns = [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]

    private var calculationSignature: String {
        [selectedDefaultID, bulletWeight, bulletDiameter, bulletLength, ballisticCoefficient,
         muzzleVelocity, twist, dragModel.rawValue, temperature, altitude, humidity,
         zeroRange, scopeHeight, windSpeed, windDirection, rangeStep, maxRange, specificRanges,
         distanceSystem.rawValue].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Units")
                        Picker("Distance and speed", selection: $distanceSystem) {
                            ForEach(DistanceUnitSystem.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("distanceUnitPicker")
                        Spacer(minLength: 20)
                        Picker("Correction", selection: $angleUnit) {
                            ForEach(AngleUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 220)
                        .accessibilityIdentifier("angleUnitPicker")
                    }
                    Text("Distance units and MIL/MOA switch independently. Calculations stay in SI; box values stay in their printed units.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cartridge starting values") {
                    Picker("Cartridge", selection: $selectedDefaultID) {
                        ForEach(defaults) { item in
                            Text(item.name).tag(item.id)
                        }
                    }
                    .accessibilityIdentifier("cartridgePicker")
                    if let defaultsError {
                        Text(defaultsError).foregroundStyle(.red)
                    } else {
                        Text("This preset fills editable inputs. It is not a lookup for the trajectory result.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        boxField("Bullet weight", text: $bulletWeight, unit: "gr", key: "weight", siUnit: "kg", convert: UnitConversions.grainsToKilograms)
                        boxField("Bullet diameter", text: $bulletDiameter, unit: "in", key: "diameter", siUnit: "m", convert: UnitConversions.inchesToMeters)
                        boxField("Bullet length", text: $bulletLength, unit: "in", key: "length", siUnit: "m", convert: UnitConversions.inchesToMeters)
                        boxField("Ballistic coefficient", text: $ballisticCoefficient, unit: "G1/G7", key: "BC", siUnit: "", convert: { $0 })
                        boxField("Muzzle velocity", text: $muzzleVelocity, unit: "ft/s", key: "muzzleVelocity", siUnit: "m/s", convert: UnitConversions.feetPerSecondToMetersPerSecond)
                        boxField("Twist", text: $twist, unit: "in/turn", key: "twist", siUnit: "m/turn", convert: UnitConversions.inchesPerTurnToMetersPerTurn)
                    }
                    Picker("Drag model", selection: $dragModel) {
                        Text("G1").tag(DragModel.g1)
                        Text("G7").tag(DragModel.g7)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Atmosphere") {
                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        inputField("Temperature", text: $temperature, unit: distanceSystem.temperatureLabel, key: "temperature", prompt: distanceSystem == .metric ? "15" : "59")
                        inputField("Altitude", text: $altitude, unit: distanceSystem.altitudeLabel, key: "altitude", prompt: "0")
                        inputField("Relative humidity", text: $humidity, unit: "%", key: "humidity", prompt: "50")
                    }
                    Text("Pressure is calculated from altitude; humidity is entered as a percentage.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Zero and scope") {
                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        inputField("Zero distance", text: $zeroRange, unit: distanceSystem.rangeLabel, key: "zeroRange", prompt: "100")
                        inputField("Scope height", text: $scopeHeight, unit: distanceSystem.scopeHeightLabel, key: "scopeHeight", prompt: distanceSystem == .metric ? "50.8" : "2")
                    }
                    Text("Shot mode zeros in calm air, then applies the selected wind during flight. This allows wind to move impact at the zero distance.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Constant wind") {
                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        inputField("Wind speed", text: $windSpeed, unit: distanceSystem.windSpeedLabel, key: "windSpeed", prompt: "0")
                        inputField("Wind toward", text: $windDirection, unit: "degrees", key: "windDirection", prompt: "0")
                    }
                    Text("Direction: 0° pushes right, 90° downrange, 180° left, and 270° up-range.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Sample ranges") {
                    LazyVGrid(columns: twoColumns, spacing: 12) {
                        inputField("Interval", text: $rangeStep, unit: distanceSystem.rangeLabel, key: "rangeStep", prompt: "100")
                        inputField("Maximum range", text: $maxRange, unit: distanceSystem.rangeLabel, key: "maxRange", prompt: "1000")
                    }
                    inputField("Additional ranges (comma separated)", text: $specificRanges, unit: distanceSystem.rangeLabel, key: "specificRanges", prompt: "e.g. 625")
                    Text("The zero distance is always included. Additional distances are interpolated from this calculation, even between interval rows.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        Button("Calculate trajectory", action: calculate)
                            .keyboardShortcut(.defaultAction)
                            .accessibilityIdentifier("calculateTrajectory")
                        if let calculationError {
                            Text(calculationError).foregroundStyle(.red)
                                .accessibilityIdentifier("calculationError")
                        }
                    }
                    Text("Every result is calculated from the current fields. The reference JSON files are test data only.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if let solution {
                    Section("Calculated trajectory") {
                        if !solution.zero.converged {
                            approximateZeroWarning(solution.zero)
                        }
                        Text("Physical displacement and sight corrections are shown separately. Corrections are direction plus \(angleUnit.label).")
                            .font(.caption).foregroundStyle(.secondary)
                        trajectoryTable(solution.rows)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Trajectory Inspection")
            .frame(minWidth: 900, minHeight: 820)
            .onAppear(perform: loadDefaults)
            .onChange(of: selectedDefaultID) { _, newValue in applyDefault(id: newValue) }
            .onChange(of: distanceSystem) { oldValue, newValue in convertDisplayInputs(from: oldValue, to: newValue) }
            .onChange(of: calculationSignature) { _, _ in invalidateResult() }
        }
    }

    private func boxField(_ title: String, text: Binding<String>, unit: String, key: String,
                          siUnit: String, convert: (Double) -> Double?) -> some View {
        inputField(title, text: text, unit: unit, key: key, prompt: "") {
            if let value = Double(text.wrappedValue), let converted = convert(value) {
                let suffix = siUnit.isEmpty ? "" : " \(siUnit)"
                Text("SI: \(String(format: "%.7g", converted))\(suffix)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            } else {
                Text("SI: —").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func inputField<Preview: View>(_ title: String, text: Binding<String>, unit: String,
                                           key: String, prompt: String,
                                           @ViewBuilder preview: () -> Preview = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.subheadline)
                Spacer(minLength: 6)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            TextField("", text: text, prompt: prompt.isEmpty ? nil : Text(prompt))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
                .accessibilityIdentifier("\(key)Input")
            preview()
            if let error = validationErrors[key] {
                Text(error).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("\(key)Error")
            }
        }
        .padding(.vertical, 3)
    }

    private func approximateZeroWarning(_ zero: ZeroResult) -> some View {
        let vertical = distanceSystem.displacement(fromMeters: Double(zero.verticalDeviationM))
        let lateral = distanceSystem.displacement(fromMeters: Double(zero.lateralDeviationM))
        let miss = distanceSystem.displacement(fromMeters: Double(zero.missDistanceM))
        return VStack(alignment: .leading, spacing: 5) {
            Label("Approximate zero", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            Text("Calm-air zeroing stopped before reaching the solver tolerance. The closest trajectory is shown. Its zero point misses the target by \(formatted(miss, digits: 3)) \(distanceSystem.displacementLabel): vertical \(formatted(vertical, digits: 3)) (y/up), lateral \(formatted(lateral, digits: 3)) (x/right). Live wind can add further displacement in the table.")
                .font(.callout)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("approximateZeroWarning")
    }

    private func trajectoryTable(_ rows: [TrajectoryRow]) -> some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 0) {
                tableHeader
                ForEach(Array(rows.enumerated()), id: \.offset) { entry in
                    let row = entry.element
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        cell(formatted(distanceSystem.range(fromMeters: Double(row.rangeM)), digits: 1), width: 64)
                        cell(formatted(distanceSystem.displacement(fromMeters: Double(row.dropM)), digits: distanceSystem == .metric ? 3 : 2), width: 74)
                        cell(formatted(distanceSystem.displacement(fromMeters: Double(row.windageM)), digits: distanceSystem == .metric ? 3 : 2), width: 74)
                        cell(formatted(distanceSystem.speed(fromMetersPerSecond: Double(row.velocityMps)), digits: 1), width: 68)
                        cell(formatted(distanceSystem.displayEnergy(fromJoules: Double(row.kineticEnergyJ)), digits: 0), width: 72)
                        cell(SolverDisplay.correctionText(displacementM: Double(row.dropM), rangeM: Double(row.rangeM), axis: .elevation, unit: angleUnit), width: 100)
                        cell(SolverDisplay.correctionText(displacementM: Double(row.windageM), rangeM: Double(row.rangeM), axis: .windage, unit: angleUnit), width: 100)
                        cell(formatted(Double(row.timeOfFlightS), digits: 3), width: 60)
                    }
                    .background(entry.offset.isMultiple(of: 2) ? Color.primary.opacity(0.035) : .clear)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityIdentifier("trajectoryResultsTable")
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            header("Range (\(distanceSystem.rangeLabel))", width: 64)
            header("Drop (\(distanceSystem.displacementLabel))", width: 74)
            header("Windage (\(distanceSystem.displacementLabel))", width: 74)
            header("Velocity (\(distanceSystem.speedLabel))", width: 68)
            header("Energy (\(distanceSystem.energyLabel))", width: 72)
            header("Elevation correction", width: 100)
            header("Wind correction", width: 100)
            header("Time (s)", width: 60)
        }
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.08))
    }

    private func header(_ title: String, width: CGFloat) -> some View {
        Text(title).font(.caption.bold()).frame(width: width, alignment: .leading).padding(.horizontal, 5)
    }

    private func cell(_ value: String, width: CGFloat) -> some View {
        Text(value).font(.caption.monospacedDigit()).lineLimit(1)
            .frame(width: width, alignment: .leading).padding(.horizontal, 3).padding(.vertical, 7)
    }

    private func formatted(_ value: Double, digits: Int) -> String {
        String(format: "%.*f", digits, value)
    }

    private func loadDefaults() {
        do {
            defaults = try CartridgeDefaults.load()
            if !defaults.contains(where: { $0.id == selectedDefaultID }), let first = defaults.first {
                selectedDefaultID = first.id
                applyDefault(id: first.id)
            } else {
                applyDefault(id: selectedDefaultID)
            }
            defaultsError = nil
        } catch {
            defaultsError = error.localizedDescription
        }
    }

    private func applyDefault(id: String) {
        guard let item = defaults.first(where: { $0.id == id }) else { return }
        bulletWeight = String(item.box.bulletWeightGr)
        bulletDiameter = String(item.box.diameterIn)
        bulletLength = String(item.box.lengthIn)
        ballisticCoefficient = String(item.box.bc)
        muzzleVelocity = String(item.box.muzzleVelocityFps)
        twist = String(item.box.twistInPerTurn)
        dragModel = item.box.dragModel
        maxRange = String(distanceSystem.range(fromMeters: item.recommendedMaxRangeM))
        rangeStep = String(distanceSystem.range(fromMeters: item.recommendedStepM))
    }

    private func convertDisplayInputs(from old: DistanceUnitSystem, to new: DistanceUnitSystem) {
        guard old != new else { return }
        temperature = convertedText(temperature) { new.displayTemperature(fromKelvin: old.temperatureKelvin(fromDisplay: $0)) }
        altitude = convertedText(altitude) { new.displayAltitude(fromMeters: old.altitudeMeters(fromDisplay: $0)) }
        zeroRange = convertedText(zeroRange) { new.range(fromMeters: old.meters(fromRange: $0)) }
        rangeStep = convertedText(rangeStep) { new.range(fromMeters: old.meters(fromRange: $0)) }
        maxRange = convertedText(maxRange) { new.range(fromMeters: old.meters(fromRange: $0)) }
        scopeHeight = convertedText(scopeHeight) { new.displayScopeHeight(fromMeters: old.scopeHeightMeters(fromDisplay: $0)) }
        windSpeed = convertedText(windSpeed) {
            let metersPerSecond = old.windMetersPerSecond(fromDisplay: $0)
            return new == .metric ? metersPerSecond : metersPerSecond / 0.44704
        }
        specificRanges = specificRanges.split(separator: ",", omittingEmptySubsequences: false)
            .map { convertedText(String($0)) { new.range(fromMeters: old.meters(fromRange: $0)) } }
            .joined(separator: ", ")
    }

    private func convertedText(_ text: String, convert: (Double) -> Double) -> String {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)), value.isFinite else { return text }
        return String(format: "%.8g", convert(value))
    }

    private func invalidateResult() {
        solution = nil
        calculationError = nil
        validationErrors.removeAll()
    }

    private func parse(_ text: String, key: String, label: String,
                       allowsZero: Bool = false, allowsNegative: Bool = false,
                       range: ClosedRange<Double>? = nil) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite,
              (allowsNegative || (allowsZero ? value >= 0 : value > 0)), range?.contains(value) ?? true else {
            validationErrors[key] = range.map { "Enter a value from \($0.lowerBound) to \($0.upperBound)." }
                ?? (allowsNegative ? "Enter a finite \(label)." : (allowsZero ? "Enter a finite, nonnegative \(label)." : "Enter a finite \(label) greater than zero."))
            return nil
        }
        return value
    }

    private func calculate() {
        solution = nil
        calculationError = nil
        validationErrors.removeAll()

        let weight = parse(bulletWeight, key: "weight", label: "weight")
        let diameter = parse(bulletDiameter, key: "diameter", label: "diameter")
        let length = parse(bulletLength, key: "length", label: "length")
        let bc = parse(ballisticCoefficient, key: "BC", label: "ballistic coefficient")
        let mv = parse(muzzleVelocity, key: "muzzleVelocity", label: "muzzle velocity")
        let twistValue = parse(twist, key: "twist", label: "twist")

        let tempDisplay = parse(temperature, key: "temperature", label: "temperature", allowsNegative: true)
        let altitudeDisplay = parse(altitude, key: "altitude", label: "altitude", allowsNegative: true)
        let humidityPercent = parse(humidity, key: "humidity", label: "humidity", allowsZero: true, range: 0...100)
        let zeroDisplay = parse(zeroRange, key: "zeroRange", label: "zero distance")
        let scopeDisplay = parse(scopeHeight, key: "scopeHeight", label: "scope height", allowsZero: true)
        let windDisplay = parse(windSpeed, key: "windSpeed", label: "wind speed", allowsZero: true)
        let direction = parse(windDirection, key: "windDirection", label: "wind direction", allowsZero: true, range: 0...360)
        let stepDisplay = parse(rangeStep, key: "rangeStep", label: "range interval")
        let maxDisplay = parse(maxRange, key: "maxRange", label: "maximum range")

        guard validationErrors.isEmpty,
              let weight, let diameter, let length, let bc, let mv, let twistValue,
              let tempDisplay, let altitudeDisplay, let humidityPercent,
              let zeroDisplay, let scopeDisplay, let windDisplay, let direction,
              let stepDisplay, let maxDisplay else { return }

        let zeroM = distanceSystem.meters(fromRange: zeroDisplay)
        let stepM = distanceSystem.meters(fromRange: stepDisplay)
        let maxM = distanceSystem.meters(fromRange: maxDisplay)
        guard maxM >= zeroM else {
            validationErrors["maxRange"] = "Maximum range must reach the zero distance."
            return
        }
        let customRanges = parseSpecificRanges(maximumDisplay: maxDisplay, maximumMeters: maxM)
        guard validationErrors.isEmpty, let customRanges else { return }

        let temperatureK = distanceSystem.temperatureKelvin(fromDisplay: tempDisplay)
        guard temperatureK.isFinite, temperatureK > 0 else {
            validationErrors["temperature"] = "Temperature must be above absolute zero."
            return
        }

        let windMps = distanceSystem.windMetersPerSecond(fromDisplay: windDisplay)
        let directionRadians = direction * Double.pi / 180
        let load = BallisticLoad(massKg: Float(weight * 0.00006479891),
                                 diameterM: Float(diameter * 0.0254),
                                 lengthM: Float(length * 0.0254),
                                 bc: Float(bc), dragModel: dragModel,
                                 muzzleVelocityMps: Float(mv * 0.3048), twistM: Float(twistValue * 0.0254))
        let request = BallisticRequest(
            load: load,
            atmosphere: AtmosphereInput(temperatureK: Float(temperatureK),
                                        altitudeM: Float(distanceSystem.altitudeMeters(fromDisplay: altitudeDisplay)),
                                        humidity: Float(humidityPercent / 100), pressurePa: 0),
            wind: ConstantWind(xMps: Float(windMps * cos(directionRadians)), yMps: 0,
                               zMps: Float(-windMps * sin(directionRadians))),
            ranges: RangeRequest(zeroRangeM: Float(zeroM), maxRangeM: Float(maxM), stepM: Float(stepM),
                                 requestedRangesM: customRanges.map { Float(distanceSystem.meters(fromRange: $0)) }),
            zeroMode: .calmAir,
            sightHeightM: Float(distanceSystem.scopeHeightMeters(fromDisplay: scopeDisplay)))

        do {
            solution = try TrajectorySolver(request: request).solve()
        } catch {
            calculationError = error.localizedDescription
        }
    }

    private func parseSpecificRanges(maximumDisplay: Double, maximumMeters: Double) -> [Double]? {
        let trimmed = specificRanges.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false)
        var values: [Double] = []
        for part in parts {
            guard let value = Double(part.trimmingCharacters(in: .whitespacesAndNewlines)),
                  value.isFinite, value > 0 else {
                validationErrors["specificRanges"] = "Enter positive distances separated by commas."
                return nil
            }
            let meters = distanceSystem.meters(fromRange: value)
            guard meters <= maximumMeters else {
                validationErrors["specificRanges"] = "Each requested distance must be at or below the maximum range (\(formatted(maximumDisplay, digits: 2)) \(distanceSystem.rangeLabel))."
                return nil
            }
            values.append(value)
        }
        return values
    }
}

#Preview {
    ContentView()
}
