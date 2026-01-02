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
        RealityView { content in
            // No floor - full passthrough
            content.add(handTrackingManager.rootEntity)
        }
        .task {
            await handTrackingManager.startHandTracking()
        }
    }
}
