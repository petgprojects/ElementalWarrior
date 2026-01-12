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
    @State private var loadingAnchor = AnchorEntity(.head)

    var body: some View {
        RealityView { content, attachments in
            content.add(appModel.thunderdomeManager.rootEntity)
            content.add(appModel.handTrackingManager.rootEntity)
            content.add(loadingAnchor)

            if !appModel.thunderdomeManager.isEnvironmentReady,
               let loadingEntity = attachments.entity(for: "loading") {
                placeLoadingEntity(loadingEntity)
            }
        } update: { _, attachments in
            guard let loadingEntity = attachments.entity(for: "loading") else { return }
            if appModel.thunderdomeManager.isEnvironmentReady {
                loadingEntity.removeFromParent()
            } else if loadingEntity.parent == nil {
                placeLoadingEntity(loadingEntity)
            }
        } attachments: {
            Attachment(id: "loading") {
                LoadingOverlay()
            }
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

    private func placeLoadingEntity(_ entity: Entity) {
        entity.position = SIMD3<Float>(0, -0.1, -0.8)
        loadingAnchor.addChild(entity)
    }
}

private struct LoadingOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading Thunderdome...")
                .font(.title3)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassBackgroundEffect()
    }
}
