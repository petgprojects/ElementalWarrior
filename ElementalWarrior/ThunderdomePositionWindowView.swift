//
//  ThunderdomePositionWindowView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI

struct ThunderdomePositionWindowView: View {
    @Environment(AppModel.self) private var appModel

    private enum Axis: Int, CaseIterable {
        case x = 0
        case y = 1
        case z = 2

        var title: String {
            switch self {
            case .x: return "X"
            case .y: return "Y"
            case .z: return "Z"
            }
        }

        var range: ClosedRange<Double> {
            switch self {
            case .x, .z:
                return -10.0...10.0
            case .y:
                return -2.0...4.0
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Thunderdome Position")
                .font(.title2)
                .bold()

            Text("Offsets move the arena relative to the user.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Axis.allCases, id: \.self) { axis in
                PositionSliderRow(
                    title: axis.title,
                    value: axisBinding(axis),
                    range: axis.range,
                    step: 0.05,
                    format: "%.2f",
                    unit: "m"
                )
            }

            HStack {
                Button("Reset") {
                    appModel.thunderdomeManager.resetPosition()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func axisBinding(_ axis: Axis) -> Binding<Double> {
        Binding(
            get: { Double(appModel.thunderdomeManager.position[axis.rawValue]) },
            set: { newValue in
                var position = appModel.thunderdomeManager.position
                position[axis.rawValue] = Float(newValue)
                appModel.thunderdomeManager.position = position
            }
        )
    }
}

private struct PositionSliderRow: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(formattedValue)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
        .padding(.vertical, 4)
    }

    private var formattedValue: String {
        let formatted = String(format: format, value.wrappedValue)
        if unit.isEmpty {
            return formatted
        }
        return "\(formatted) \(unit)"
    }
}
