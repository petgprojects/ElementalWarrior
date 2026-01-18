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
    @State private var promptAnchor = AnchorEntity(.head)

    var body: some View {
        RealityView { content, attachments in
            content.add(appModel.thunderdomeManager.rootEntity)
            content.add(appModel.handTrackingManager.rootEntity)
            content.add(loadingAnchor)
            content.add(promptAnchor)

            if appModel.thunderdomeManager.isEnvironmentLoading,
               let loadingEntity = attachments.entity(for: "loading") {
                placeLoadingEntity(loadingEntity)
            }
            if appModel.thunderdomeManager.isAwaitingFloorLook,
               let promptEntity = attachments.entity(for: "floorPrompt") {
                placeFloorPromptEntity(promptEntity)
            }
        } update: { _, attachments in
            print("[ThunderdomeView] Update called - isEnvironmentLoading: \(appModel.thunderdomeManager.isEnvironmentLoading), isEnvironmentReady: \(appModel.thunderdomeManager.isEnvironmentReady)")
            if let loadingEntity = attachments.entity(for: "loading") {
                if appModel.thunderdomeManager.isEnvironmentLoading {
                    if loadingEntity.parent == nil {
                        placeLoadingEntity(loadingEntity)
                    }
                } else if loadingEntity.parent != nil {
                    print("[ThunderdomeView] Removing loading entity")
                    loadingEntity.removeFromParent()
                }
            }
            if let promptEntity = attachments.entity(for: "floorPrompt") {
                if appModel.thunderdomeManager.isAwaitingFloorLook {
                    if promptEntity.parent == nil {
                        placeFloorPromptEntity(promptEntity)
                    }
                } else if promptEntity.parent != nil {
                    promptEntity.removeFromParent()
                }
            }
        } attachments: {
            Attachment(id: "loading") {
                LoadingOverlay()
            }
            Attachment(id: "floorPrompt") {
                FloorPromptOverlay()
            }
        }
        .task {
            print("[ThunderdomeView] Task started")
            appModel.thunderdomeImmersionStyle = .mixed
            appModel.handTrackingManager.collisionMode = .none
            print("[ThunderdomeView] Calling applyInitialUserHeight...")
            await appModel.thunderdomeManager.applyInitialUserHeight(using: appModel.handTrackingManager)
            print("[ThunderdomeView] applyInitialUserHeight returned")
            await appModel.thunderdomeManager.loadEnvironment()
            print("[ThunderdomeView] loadEnvironment returned, isEnvironmentReady: \(appModel.thunderdomeManager.isEnvironmentReady)")
            if appModel.thunderdomeManager.isEnvironmentReady {
                print("[ThunderdomeView] Setting collision mode and immersion style")
                appModel.handTrackingManager.collisionMode = .thunderdome
                appModel.thunderdomeImmersionStyle = .full
                print("[ThunderdomeView] Task complete!")
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

    private func placeFloorPromptEntity(_ entity: Entity) {
        entity.position = SIMD3<Float>(0, -0.25, -0.8)
        promptAnchor.addChild(entity)
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

private struct FloorPromptOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Look down at the floor to calibrate height.")
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .glassBackgroundEffect()
    }
}
