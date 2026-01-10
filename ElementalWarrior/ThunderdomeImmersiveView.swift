//
//  ThunderdomeImmersiveView.swift
//  ElementalWarrior
//
//  Created by Peter Gelgor on 2025-12-30.
//

import SwiftUI
import RealityKit

struct ThunderdomeImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            content.add(appModel.thunderdomeManager.rootEntity)
            content.add(appModel.handTrackingManager.rootEntity)
        }
        .task {
            appModel.handTrackingManager.collisionMode = .none
            await appModel.thunderdomeManager.loadEnvironment()
            if appModel.thunderdomeManager.isEnvironmentReady {
                appModel.handTrackingManager.collisionMode = .thunderdome
            }
        }
        .task {
            await appModel.handTrackingManager.startHandTracking()
        }
    }
}
