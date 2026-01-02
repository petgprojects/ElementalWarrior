//
//  ArenaImmersiveView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct ArenaImmersiveView: View {
    @State private var handTrackingManager = HandTrackingManager()

    var body: some View {
        ZStack {
            RealityView { content in
                // No floor - full passthrough
                content.add(handTrackingManager.rootEntity)
            }
            .task {
                await handTrackingManager.startHandTracking()
            }
            
            // Debug overlay showing hand states
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    // Left hand debug
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LEFT HAND")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(handTrackingManager.leftHandGestureState.rawValue)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForState(handTrackingManager.leftHandGestureState))
                        
                        Text(handTrackingManager.leftDebugInfo)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .frame(maxWidth: 300)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    
                    // Right hand debug
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RIGHT HAND")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(handTrackingManager.rightHandGestureState.rawValue)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .foregroundColor(colorForState(handTrackingManager.rightHandGestureState))
                        
                        Text(handTrackingManager.rightDebugInfo)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                            .frame(maxWidth: 300)
                    }
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
                .padding(.bottom, 50)
            }
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
        }
    }
}
