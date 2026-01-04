//
//  HomeView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct HomeView: View {

    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStackLayout().depthAlignment(.front) {
            RealityView { content in
                let fireball = await createFireball()
                content.add(fireball)
            }
            .frame(height: 500)
            .frame(depth: 0.001, alignment: .front)
            .padding(.top, 24)
            .allowsHitTesting(false)

            Color.clear.frame(height: 12)

            VStack(spacing: 16) {
                Text("Welcome to Elemental Warrior")
                    .font(.largeTitle)
                    .bold()

                Text("Master the elements. Enter the arena.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Start") {
                        Task {
                            _ = await openImmersiveSpace(id: "arena")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Quit Immersion") {
                        Task {
                            await dismissImmersiveSpace()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                // Debug panel for hand tracking
                Divider()
                    .padding(.vertical, 8)
                
                Text("Hand Tracking Debug")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 24) {
                    // Left hand debug
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LEFT HAND")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(appModel.handTrackingManager.leftHandGestureState.rawValue)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForState(appModel.handTrackingManager.leftHandGestureState))
                        
                        Text(appModel.handTrackingManager.leftDebugInfo)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    
                    // Right hand debug
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RIGHT HAND")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(appModel.handTrackingManager.rightHandGestureState.rawValue)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForState(appModel.handTrackingManager.rightHandGestureState))
                        
                        Text(appModel.handTrackingManager.rightDebugInfo)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 280, alignment: .leading)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                // Room Scanning Panel
                Divider()
                    .padding(.vertical, 8)
                
                Text("Room Scanning")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    // Scan status
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
                        // Toggle visualization
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
                        
                        // Clear scan data
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
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(32)
        }
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
        }
    }

    private func createFireball() async -> Entity {
        let fireball = await MainActor.run {
            let entity = createRealisticFireball(scale: 1.5)
            entity.position.y = -0.2
            return entity
        }
        return fireball
    }
}
