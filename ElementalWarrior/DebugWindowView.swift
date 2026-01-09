//
//  DebugWindowView.swift
//  ElementalWarrior
//

import SwiftUI

struct DebugWindowView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView {
            NavigationStack {
                HandDebugView()
            }
            .tabItem {
                Label("Hands", systemImage: "hand.raised")
            }

            NavigationStack {
                RoomDebugView()
            }
            .tabItem {
                Label("Room Scanning", systemImage: "camera.metering.spot")
            }

            TutorialsDebugView()
                .tabItem {
                    Label("Tutorials", systemImage: "play.rectangle")
                }

            OptionsDebugView(settings: appModel.gestureSettings)
                .tabItem {
                    Label("Options", systemImage: "slider.horizontal.3")
                }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

private struct HandDebugView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hand Tracking Debug")
                .font(.title2)
                .bold()

            HStack(alignment: .top, spacing: 24) {
                debugCard(title: "LEFT HAND",
                          state: appModel.handTrackingManager.leftHandGestureState,
                          rows: appModel.handTrackingManager.leftHandDebugRows)

                debugCard(title: "RIGHT HAND",
                          state: appModel.handTrackingManager.rightHandGestureState,
                          rows: appModel.handTrackingManager.rightHandDebugRows)
            }

            Spacer()
        }
        .padding(24)
        .navigationTitle("Hands")
    }

    private func debugCard(title: String, state: HandGestureState, rows: [GestureDebugRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(state.rawValue)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(colorForState(state))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows) { row in
                    DebugRowView(row: row)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }

    private func colorForState(_ state: HandGestureState) -> Color {
        switch state {
        case .none:
            return .gray
        case .fist:
            return .red
        case .summon:
            return .yellow
        case .holdingFireball:
            return .orange
        case .collision:
            return .green
        case .flamethrower:
            return .cyan
        case .wallControl:
            return .blue
        }
    }
}

private struct DebugRowView: View {
    let row: GestureDebugRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: row.status.systemImage)
                    .foregroundStyle(row.status.color)

                Text(row.title)
                    .font(.caption)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                ForEach(row.attributes) { attribute in
                    GridRow {
                        Text(attribute.name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        Text(attribute.value)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(attribute.status.color)
                    }
                }
            }
        }
    }
}

private extension GestureDebugStatus {
    var systemImage: String {
        switch self {
        case .active:
            return "checkmark.circle.fill"
        case .inactive:
            return "xmark.circle"
        case .unavailable:
            return "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .active:
            return .green
        case .inactive:
            return .red
        case .unavailable:
            return .gray
        }
    }
}

private extension GestureDebugAttributeStatus {
    var color: Color {
        switch self {
        case .pass:
            return .green
        case .fail:
            return .red
        case .neutral:
            return .secondary
        }
    }
}

private struct RoomDebugView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Room Scanning")
                .font(.title2)
                .bold()

            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "camera.metering.spot")
                        .foregroundColor(.cyan)
                    Text(appModel.handTrackingManager.scannedAreaDescription)
                        .font(.system(size: 14, design: .monospaced))
                }
                .padding(.horizontal)

                Text("Walk around to scan your room. Fireballs will collide with all scanned surfaces!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button {
                        appModel.handTrackingManager.toggleScanVisualization()
                    } label: {
                        HStack {
                            Image(systemName: appModel.handTrackingManager.isScanVisualizationEnabled ? "eye.fill" : "eye.slash")
                            Text(appModel.handTrackingManager.isScanVisualizationEnabled ? "Hide Scan" : "Show Scan")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.cyan)

                    Button {
                        appModel.handTrackingManager.clearScannedData()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(8)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Room")
    }
}

private struct OptionsDebugView: View {
    @Bindable var settings: GestureSettings
    @State private var selection: OptionsSection? = .fireball

    private enum OptionsSection: String, CaseIterable, Hashable {
        case fireball
        case flamethrower
        case wallOfFire

        var title: String {
            switch self {
            case .fireball:
                return "Fireball"
            case .flamethrower:
                return "Flamethrower"
            case .wallOfFire:
                return "Wall of Fire"
            }
        }

        var systemImage: String {
            switch self {
            case .fireball:
                return "flame"
            case .flamethrower:
                return "flame.fill"
            case .wallOfFire:
                return "rectangle.split.3x1"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(OptionsSection.allCases, id: \.self) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Options")
            .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 240)
        } detail: {
            if let selection {
                optionsDetailView(for: selection)
            } else {
                FireballOptionsView(settings: settings)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func optionsDetailView(for section: OptionsSection) -> some View {
        switch section {
        case .fireball:
            FireballOptionsView(settings: settings)
        case .flamethrower:
            FlamethrowerOptionsView(settings: settings)
        case .wallOfFire:
            WallOfFireOptionsView(settings: settings)
        }
    }
}

private struct FireballOptionsView: View {
    @Bindable var settings: GestureSettings

    var body: some View {
        Form {
            OptionSliderRow(title: "Despawn delay", value: $settings.despawnDelayDuration, range: 0.1...5.0, step: 0.1, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Punch velocity", value: $settings.punchVelocityThreshold, range: 0.05...1.0, step: 0.05, format: "%.2f", unit: "m/s")
            OptionSliderRow(title: "Punch proximity", value: $settings.punchProximityThreshold, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Fist extension", value: $settings.fistExtensionThreshold, range: 0.01...0.1, step: 0.005, format: "%.3f", unit: "m")
            OptionSliderRow(title: "Velocity history", value: $settings.velocityHistoryDuration, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Projectile speed", value: $settings.projectileSpeed, range: 2.0...30.0, step: 0.5, format: "%.1f", unit: "m/s")
            OptionSliderRow(title: "Max projectile range", value: $settings.maxProjectileRange, range: 5.0...50.0, step: 1.0, format: "%.1f", unit: "m")
            OptionSliderRow(title: "Tracking grace", value: $settings.trackingLostGraceDuration, range: 0.0...5.0, step: 0.1, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Cross punch delay", value: $settings.crossPunchResummonDelay, range: 0.0...2.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Combine distance", value: $settings.fireballCombineDistance, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Mega fireball scale", value: $settings.megaFireballScale, range: 1.0...4.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Mega explosion scale", value: $settings.megaExplosionScale, range: 1.0...4.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Mega scorch scale", value: $settings.megaScorchScale, range: 1.0...4.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Mega audio boost", value: $settings.megaAudioGainBoost, range: 0.0...12.0, step: 0.5, format: "%.1f", unit: "dB")
        }
        .navigationTitle("Fireball")
        .padding(12)
    }
}

private struct FlamethrowerOptionsView: View {
    @Bindable var settings: GestureSettings

    var body: some View {
        Form {
            OptionSliderRow(title: "Range", value: $settings.flamethrowerRange, range: 2.0...15.0, step: 0.5, format: "%.1f", unit: "m")
            OptionSliderRow(title: "Forward dot threshold", value: $settings.flamethrowerForwardDotThreshold, range: 0.0...1.0, step: 0.02, format: "%.2f", unit: "")
            OptionSliderRow(title: "Up reject threshold", value: $settings.flamethrowerUpRejectThreshold, range: 0.2...1.0, step: 0.02, format: "%.2f", unit: "")
            OptionSliderRow(title: "Scorch cooldown", value: $settings.flamethrowerScorchCooldown, range: 0.05...1.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Scorch scale", value: $settings.flamethrowerScorchScale, range: 0.1...2.0, step: 0.05, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Scorch lifetime", value: $settings.flamethrowerScorchLifetime, range: 1.0...15.0, step: 0.5, format: "%.1f", unit: "s")
            OptionSliderRow(title: "Raycast interval", value: $settings.flamethrowerRaycastInterval, range: 0.01...0.1, step: 0.005, format: "%.3f", unit: "s")
            OptionSliderRow(title: "Tracking grace", value: $settings.flamethrowerTrackingGraceDuration, range: 0.1...2.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Combine distance", value: $settings.flamethrowerCombineDistance, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Split distance", value: $settings.flamethrowerSplitDistance, range: 0.1...0.8, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Combined jet intensity", value: $settings.combinedFlamethrowerJetIntensity, range: 1.0...3.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Combined muzzle scale", value: $settings.combinedFlamethrowerMuzzleScale, range: 0.5...2.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Combined audio boost", value: $settings.combinedFlamethrowerAudioBoost, range: 0.0...6.0, step: 0.5, format: "%.1f", unit: "dB")
        }
        .navigationTitle("Flamethrower")
        .padding(12)
    }
}

private struct WallOfFireOptionsView: View {
    @Bindable var settings: GestureSettings

    var body: some View {
        Form {
            OptionSliderRow(title: "Palm down dot", value: $settings.zombiePosePalmDownDotThreshold, range: -1.0...0.0, step: 0.05, format: "%.2f", unit: "")
            OptionSliderRow(title: "Min forward distance", value: $settings.zombiePoseMinForwardDistance, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Min down angle", value: $settings.zombiePoseMinDownAngleDegrees, range: 20.0...80.0, step: 1.0, format: "%.0f", unit: "deg")
            OptionSliderRow(title: "Pose update window", value: $settings.zombiePoseUpdateWindow, range: 0.05...1.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Control grace", value: $settings.wallControlGraceDuration, range: 0.0...1.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Confirm hold", value: $settings.wallConfirmHoldDuration, range: 0.05...1.0, step: 0.05, format: "%.2f", unit: "s")
            OptionSliderRow(title: "Min width", value: $settings.wallPlacementMinWidth, range: 0.2...1.5, step: 0.05, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Max width", value: $settings.wallPlacementMaxWidth, range: 1.0...6.0, step: 0.1, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Placement smoothing", value: $settings.wallPlacementSmoothing, range: 0.0...1.0, step: 0.05, format: "%.2f", unit: "")
            OptionSliderRow(title: "Move scale", value: $settings.wallPlacementMoveScale, range: 1.0...6.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Width scale", value: $settings.wallPlacementWidthScale, range: 1.0...6.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Rotation scale", value: $settings.wallPlacementRotationScale, range: 0.5...4.0, step: 0.1, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Rotation max", value: $settings.wallPlacementRotationMaxRadians, range: 0.4...2.5, step: 0.05, format: "%.2f", unit: "rad")
            OptionSliderRow(title: "Ember offset", value: $settings.wallEmberOffset, range: 0.0...0.05, step: 0.005, format: "%.3f", unit: "m")
            OptionSliderRow(title: "Placement max distance", value: $settings.wallPlacementMaxDistance, range: 2.0...10.0, step: 0.25, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Raise start threshold", value: $settings.wallRaiseStartThreshold, range: 0.02...0.3, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Height scale", value: $settings.wallHeightScale, range: 1.0...10.0, step: 0.25, format: "%.2f", unit: "x")
            OptionSliderRow(title: "Min height", value: $settings.wallMinHeight, range: 0.1...1.0, step: 0.05, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Ember height", value: $settings.wallEmberHeight, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Max height", value: $settings.wallMaxHeight, range: 1.0...6.0, step: 0.1, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Height ref low", value: $settings.wallHeightReferenceLowOffset, range: -0.5...0.0, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Height ref high", value: $settings.wallHeightReferenceHighOffset, range: 0.0...0.5, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Min snap threshold", value: $settings.wallHeightMinSnapThreshold, range: 0.05...0.5, step: 0.01, format: "%.2f", unit: "")
            OptionSliderRow(title: "Finalize drop threshold", value: $settings.wallFinalizeDropThreshold, range: 0.02...0.3, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Removal drop threshold", value: $settings.wallRemovalDropThreshold, range: 0.02...0.3, step: 0.01, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Selection max distance", value: $settings.wallSelectionMaxDistance, range: 2.0...10.0, step: 0.25, format: "%.2f", unit: "m")
            OptionSliderRow(title: "Selection hold", value: $settings.wallSelectionHoldDuration, range: 0.1...2.0, step: 0.05, format: "%.2f", unit: "s")
        }
        .navigationTitle("Wall of Fire")
        .padding(12)
    }
}

private struct OptionSliderRow: View {
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
