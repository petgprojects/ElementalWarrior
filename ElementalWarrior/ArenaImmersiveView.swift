//
//  ArenaImmersiveView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct ArenaImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            // No floor - full passthrough
            content.add(appModel.handTrackingManager.rootEntity)
        }
        .task {
            await appModel.handTrackingManager.startHandTracking()
        }
    }
}
