import SwiftUI

struct ContentView: View {
    @State private var bulletWeight = ""
    @State private var bulletDiameter = ""
    @State private var bulletLength = ""
    @State private var muzzleVelocity = ""
    @State private var twist = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("First Round")
                        .font(.title.bold())
                    Text("Enter the measurements printed on a box or rifle specification. SI values update as you type.")
                        .foregroundStyle(.secondary)
                }

                Section("Bullet") {
                    MeasurementRow(
                        title: "Weight", inputUnit: "grains", outputUnit: "kg",
                        example: "300", decimalPlaces: 8, identifier: "bulletWeight",
                        input: $bulletWeight, convert: UnitConversions.grainsToKilograms
                    )
                    MeasurementRow(
                        title: "Diameter", inputUnit: "inches", outputUnit: "m",
                        example: "0.338", decimalPlaces: 8, identifier: "bulletDiameter",
                        input: $bulletDiameter, convert: UnitConversions.inchesToMeters
                    )
                    MeasurementRow(
                        title: "Length", inputUnit: "inches", outputUnit: "m",
                        example: "1.68", decimalPlaces: 8, identifier: "bulletLength",
                        input: $bulletLength, convert: UnitConversions.inchesToMeters
                    )
                }

                Section("Rifle and load") {
                    MeasurementRow(
                        title: "Muzzle velocity", inputUnit: "feet/second", outputUnit: "m/s",
                        example: "2725", decimalPlaces: 2, identifier: "muzzleVelocity",
                        input: $muzzleVelocity, convert: UnitConversions.feetPerSecondToMetersPerSecond
                    )
                    MeasurementRow(
                        title: "Twist", inputUnit: "inches/turn", outputUnit: "m/turn",
                        example: "10", decimalPlaces: 8, identifier: "twist",
                        input: $twist, convert: UnitConversions.inchesPerTurnToMetersPerTurn
                    )
                }

                Section {
                    Text("Trajectory calculations arrive in the next milestone.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Measurement Preview")
            .frame(maxWidth: 720)
        }
    }
}

private struct MeasurementRow: View {
    let title: String
    let inputUnit: String
    let outputUnit: String
    let example: String
    let decimalPlaces: Int
    let identifier: String
    @Binding var input: String
    let convert: (Double) -> Double?

    private var value: Double? {
        guard let number = UnitConversions.positiveNumber(from: input) else { return nil }
        return convert(number)
    }

    private var hasInvalidInput: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(inputUnit))")
                .font(.headline)
            #if os(iOS)
            TextField("", text: $input, prompt: Text("e.g. \(example)"))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(title) in \(inputUnit)")
                .accessibilityIdentifier("\(identifier)Input")
            #else
            TextField("", text: $input, prompt: Text("e.g. \(example)"))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("\(title) in \(inputUnit)")
                .accessibilityIdentifier("\(identifier)Input")
            #endif
            HStack {
                Text("SI")
                    .foregroundStyle(.secondary)
                Spacer()
                if let value {
                    Text("\(String(format: "%.*f", decimalPlaces, value)) \(outputUnit)")
                        .monospacedDigit()
                        .accessibilityIdentifier("\(identifier)SI")
                } else {
                    Text("—")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("\(identifier)SI")
                }
            }
            if hasInvalidInput {
                Text("Enter a positive number.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
